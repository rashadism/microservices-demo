// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"time"

	"github.com/redis/go-redis/extra/redisotel/v9"
	"github.com/redis/go-redis/v9"
	"github.com/sirupsen/logrus"
	"go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/status"

	pb "github.com/GoogleCloudPlatform/microservices-demo/src/cartservice/genproto"
)

var log *logrus.Logger

func init() {
	log = logrus.New()
	log.Level = logrus.DebugLevel
	log.Formatter = &logrus.JSONFormatter{
		FieldMap: logrus.FieldMap{
			logrus.FieldKeyTime:  "timestamp",
			logrus.FieldKeyLevel: "severity",
			logrus.FieldKeyMsg:   "message",
		},
		TimestampFormat: time.RFC3339Nano,
	}
	log.Out = os.Stdout
}

type cartStore interface {
	AddItem(ctx context.Context, userID, productID string, quantity int32) error
	GetCart(ctx context.Context, userID string) (*pb.Cart, error)
	EmptyCart(ctx context.Context, userID string) error
}

type redisCartStore struct {
	client *redis.Client
}

// Cart item stored in Redis
type cartItem struct {
	ProductID string `json:"product_id"`
	Quantity  int32  `json:"quantity"`
}

func newRedisCartStore(addr string) (*redisCartStore, error) {
	client := redis.NewClient(&redis.Options{
		Addr: addr,
	})

	// Add OpenTelemetry instrumentation to Redis client
	if err := redisotel.InstrumentTracing(client); err != nil {
		log.Warnf("Failed to instrument Redis with tracing: %v", err)
	}

	// Test connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("failed to connect to Redis at %s: %v", addr, err)
	}

	log.Infof("Connected to Redis at %s", addr)
	return &redisCartStore{client: client}, nil
}

func (s *redisCartStore) AddItem(ctx context.Context, userID, productID string, quantity int32) error {
	log.Infof("AddItem called: userID=%s, productID=%s, quantity=%d", userID, productID, quantity)

	cart, err := s.getCartItems(ctx, userID)
	if err != nil {
		return err
	}

	// Check if item already exists
	found := false
	for i, item := range cart {
		if item.ProductID == productID {
			cart[i].Quantity += quantity
			found = true
			break
		}
	}

	if !found {
		cart = append(cart, cartItem{ProductID: productID, Quantity: quantity})
	}

	return s.saveCart(ctx, userID, cart)
}

func (s *redisCartStore) GetCart(ctx context.Context, userID string) (*pb.Cart, error) {
	log.Infof("GetCart called: userID=%s", userID)

	items, err := s.getCartItems(ctx, userID)
	if err != nil {
		return nil, err
	}

	cart := &pb.Cart{UserId: userID}
	for _, item := range items {
		cart.Items = append(cart.Items, &pb.CartItem{
			ProductId: item.ProductID,
			Quantity:  item.Quantity,
		})
	}

	return cart, nil
}

func (s *redisCartStore) EmptyCart(ctx context.Context, userID string) error {
	log.Infof("EmptyCart called: userID=%s", userID)
	return s.saveCart(ctx, userID, []cartItem{})
}

func (s *redisCartStore) getCartItems(ctx context.Context, userID string) ([]cartItem, error) {
	val, err := s.client.Get(ctx, userID).Result()
	if err == redis.Nil {
		return []cartItem{}, nil
	}
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get cart: %v", err)
	}

	var items []cartItem
	if err := json.Unmarshal([]byte(val), &items); err != nil {
		return nil, status.Errorf(codes.Internal, "failed to unmarshal cart: %v", err)
	}

	return items, nil
}

func (s *redisCartStore) saveCart(ctx context.Context, userID string, items []cartItem) error {
	data, err := json.Marshal(items)
	if err != nil {
		return status.Errorf(codes.Internal, "failed to marshal cart: %v", err)
	}

	if err := s.client.Set(ctx, userID, data, 0).Err(); err != nil {
		return status.Errorf(codes.Internal, "failed to save cart: %v", err)
	}

	return nil
}

// In-memory cart store (fallback when Redis is not available)
type memoryCartStore struct {
	carts map[string][]cartItem
}

func newMemoryCartStore() *memoryCartStore {
	log.Info("Using in-memory cart store")
	return &memoryCartStore{carts: make(map[string][]cartItem)}
}

func (s *memoryCartStore) AddItem(ctx context.Context, userID, productID string, quantity int32) error {
	log.Infof("AddItem called: userID=%s, productID=%s, quantity=%d", userID, productID, quantity)

	cart := s.carts[userID]
	found := false
	for i, item := range cart {
		if item.ProductID == productID {
			cart[i].Quantity += quantity
			found = true
			break
		}
	}

	if !found {
		cart = append(cart, cartItem{ProductID: productID, Quantity: quantity})
	}

	s.carts[userID] = cart
	return nil
}

func (s *memoryCartStore) GetCart(ctx context.Context, userID string) (*pb.Cart, error) {
	log.Infof("GetCart called: userID=%s", userID)

	cart := &pb.Cart{UserId: userID}
	for _, item := range s.carts[userID] {
		cart.Items = append(cart.Items, &pb.CartItem{
			ProductId: item.ProductID,
			Quantity:  item.Quantity,
		})
	}

	return cart, nil
}

func (s *memoryCartStore) EmptyCart(ctx context.Context, userID string) error {
	log.Infof("EmptyCart called: userID=%s", userID)
	s.carts[userID] = []cartItem{}
	return nil
}

type cartServer struct {
	pb.UnimplementedCartServiceServer
	store cartStore
}

func (s *cartServer) AddItem(ctx context.Context, req *pb.AddItemRequest) (*pb.Empty, error) {
	if err := s.store.AddItem(ctx, req.UserId, req.Item.ProductId, req.Item.Quantity); err != nil {
		return nil, err
	}
	return &pb.Empty{}, nil
}

func (s *cartServer) GetCart(ctx context.Context, req *pb.GetCartRequest) (*pb.Cart, error) {
	return s.store.GetCart(ctx, req.UserId)
}

func (s *cartServer) EmptyCart(ctx context.Context, req *pb.EmptyCartRequest) (*pb.Empty, error) {
	if err := s.store.EmptyCart(ctx, req.UserId); err != nil {
		return nil, err
	}
	return &pb.Empty{}, nil
}

type healthServer struct {
	grpc_health_v1.UnimplementedHealthServer
}

func (h *healthServer) Check(ctx context.Context, req *grpc_health_v1.HealthCheckRequest) (*grpc_health_v1.HealthCheckResponse, error) {
	return &grpc_health_v1.HealthCheckResponse{
		Status: grpc_health_v1.HealthCheckResponse_SERVING,
	}, nil
}

func (h *healthServer) Watch(req *grpc_health_v1.HealthCheckRequest, srv grpc_health_v1.Health_WatchServer) error {
	return status.Errorf(codes.Unimplemented, "health watch is not implemented")
}

func initTracing(ctx context.Context) (*sdktrace.TracerProvider, error) {
	collectorAddr := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if collectorAddr == "" {
		collectorAddr = "opentelemetry-collector:4317"
	}

	log.Infof("Initializing tracing for cartservice, exporting to %s", collectorAddr)

	exporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(collectorAddr),
		otlptracegrpc.WithInsecure(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create trace exporter: %w", err)
	}

	res, err := resource.Merge(
		resource.Default(),
		resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceName("cartservice"),
			semconv.ServiceVersion("1.0.0"),
			attribute.String("deployment.environment", os.Getenv("DEPLOYMENT_ENV")),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create resource: %w", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
	)

	otel.SetTracerProvider(tp)
	log.Info("Tracing initialized successfully")
	return tp, nil
}

func main() {
	ctx := context.Background()

	// Initialize tracing
	tp, err := initTracing(ctx)
	if err != nil {
		log.Warnf("Failed to initialize tracing: %v", err)
	} else {
		defer tp.Shutdown(ctx)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "7070"
	}

	// Initialize cart store
	var store cartStore
	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr != "" {
		store, err = newRedisCartStore(redisAddr)
		if err != nil {
			log.Warnf("Failed to connect to Redis: %v, falling back to in-memory store", err)
			store = newMemoryCartStore()
		}
	} else {
		log.Info("REDIS_ADDR not set, using in-memory cart store")
		store = newMemoryCartStore()
	}

	// Create gRPC server with OTEL instrumentation
	srv := grpc.NewServer(
		grpc.StatsHandler(otelgrpc.NewServerHandler()),
	)

	pb.RegisterCartServiceServer(srv, &cartServer{store: store})
	grpc_health_v1.RegisterHealthServer(srv, &healthServer{})

	lis, err := net.Listen("tcp", fmt.Sprintf(":%s", port))
	if err != nil {
		log.Fatalf("Failed to listen on port %s: %v", port, err)
	}

	log.Infof("Cart service listening on port %s", port)
	if err := srv.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}
