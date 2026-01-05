# OpenTelemetry Tracing Implementation Guide

This document describes the tracing patterns and configurations used across all microservices for OpenChoreo integration.

## OTEL Collector Configuration

**Endpoint:** `opentelemetry-collector:4317` (gRPC)
**HTTP Endpoint:** `opentelemetry-collector:4318` (HTTP/protobuf)
**Environment Variable:** `OTEL_EXPORTER_OTLP_ENDPOINT`

## Resource Attributes

All services MUST set these resource attributes:

| Attribute | Description | Example |
|-----------|-------------|---------|
| `service.name` | Name of the service | `frontend`, `checkoutservice` |
| `service.version` | Version of the service | `1.0.0` |
| `deployment.environment` | Deployment environment | `production`, `staging` |

## Propagation

All services use **W3C Trace Context** and **W3C Baggage** propagation:

- `TraceContext` - Standard W3C trace context (traceparent, tracestate headers)
- `Baggage` - W3C baggage for custom context propagation

## Span Naming Conventions

### HTTP Spans
- Format: `HTTP {METHOD} {route}`
- Examples: `HTTP GET /`, `HTTP POST /cart`

### gRPC Spans
- Format: `{package}.{Service}/{Method}`
- Examples: `hipstershop.ProductCatalogService/GetProduct`

### Internal Spans
- Format: `{operation}` (verb + noun)
- Examples: `prepareOrder`, `convertCurrency`, `chargeCard`

## Language-Specific Implementations

### Go Services (frontend, checkoutservice, productcatalogservice, shippingservice)

**Initialization:**
```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/propagation"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
)

func initTracing(ctx context.Context, serviceName string) (*sdktrace.TracerProvider, error) {
    collectorAddr := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
    if collectorAddr == "" {
        collectorAddr = "opentelemetry-collector:4317"
    }

    exporter, err := otlptracegrpc.New(ctx,
        otlptracegrpc.WithEndpoint(collectorAddr),
        otlptracegrpc.WithInsecure(),
    )
    if err != nil {
        return nil, err
    }

    res, _ := resource.Merge(
        resource.Default(),
        resource.NewWithAttributes(
            semconv.SchemaURL,
            semconv.ServiceName(serviceName),
            semconv.ServiceVersion("1.0.0"),
            attribute.String("deployment.environment", os.Getenv("DEPLOYMENT_ENV")),
        ),
    )

    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter),
        sdktrace.WithResource(res),
        sdktrace.WithSampler(sdktrace.AlwaysSample()),
    )
    otel.SetTracerProvider(tp)

    // Set propagators
    otel.SetTextMapPropagator(
        propagation.NewCompositeTextMapPropagator(
            propagation.TraceContext{},
            propagation.Baggage{},
        ),
    )

    return tp, nil
}
```

**gRPC Client Instrumentation:**
```go
conn, err := grpc.NewClient(addr,
    grpc.WithTransportCredentials(insecure.NewCredentials()),
    grpc.WithStatsHandler(otelgrpc.NewClientHandler()),
)
```

**gRPC Server Instrumentation:**
```go
srv := grpc.NewServer(
    grpc.StatsHandler(otelgrpc.NewServerHandler()),
)
```

**HTTP Instrumentation:**
```go
handler = otelhttp.NewHandler(handler, "frontend")
```

### Node.js Services (currencyservice, paymentservice)

**File: tracing.js (loaded via `-r ./tracing.js`)**
```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { Resource } = require('@opentelemetry/resources');
const { SEMRESATTRS_SERVICE_NAME, SEMRESATTRS_SERVICE_VERSION } = require('@opentelemetry/semantic-conventions');

const serviceName = process.env.OTEL_SERVICE_NAME || 'unknown-service';
const collectorEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'opentelemetry-collector:4317';

const sdk = new NodeSDK({
    resource: new Resource({
        [SEMRESATTRS_SERVICE_NAME]: serviceName,
        [SEMRESATTRS_SERVICE_VERSION]: '1.0.0',
    }),
    traceExporter: new OTLPTraceExporter({
        url: `grpc://${collectorEndpoint}`,
    }),
    instrumentations: [
        getNodeAutoInstrumentations({
            '@opentelemetry/instrumentation-fs': { enabled: false },
        }),
    ],
});

sdk.start();

process.on('SIGTERM', () => {
    sdk.shutdown().finally(() => process.exit(0));
});
```

### Python Services (emailservice, recommendationservice)

**Initialization:**
```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource, SERVICE_NAME, SERVICE_VERSION
from opentelemetry.instrumentation.grpc import GrpcInstrumentorServer, GrpcInstrumentorClient

def init_tracing(service_name):
    collector_endpoint = os.environ.get('OTEL_EXPORTER_OTLP_ENDPOINT', 'opentelemetry-collector:4317')

    resource = Resource(attributes={
        SERVICE_NAME: service_name,
        SERVICE_VERSION: "1.0.0",
    })

    provider = TracerProvider(resource=resource)
    exporter = OTLPSpanExporter(endpoint=collector_endpoint, insecure=True)
    provider.add_span_processor(BatchSpanProcessor(exporter))
    trace.set_tracer_provider(provider)

    # Instrument gRPC
    GrpcInstrumentorServer().instrument()
    GrpcInstrumentorClient().instrument()

    return provider
```

### C# Service (cartservice)

**NuGet Packages:**
- `OpenTelemetry.Exporter.OpenTelemetryProtocol`
- `OpenTelemetry.Instrumentation.AspNetCore`
- `OpenTelemetry.Instrumentation.GrpcNetClient`
- `OpenTelemetry.Instrumentation.StackExchangeRedis`

**Configuration in Program.cs:**
```csharp
builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource
        .AddService(serviceName: "cartservice", serviceVersion: "1.0.0"))
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddGrpcClientInstrumentation()
        .AddRedisInstrumentation()
        .AddOtlpExporter(opts => {
            opts.Endpoint = new Uri(Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT")
                ?? "http://opentelemetry-collector:4317");
        }));
```

### Java Service (adservice)

**Dependencies (build.gradle):**
```gradle
implementation 'io.opentelemetry:opentelemetry-api:1.37.0'
implementation 'io.opentelemetry:opentelemetry-sdk:1.37.0'
implementation 'io.opentelemetry:opentelemetry-exporter-otlp:1.37.0'
implementation 'io.opentelemetry.instrumentation:opentelemetry-grpc-1.6:2.3.0-alpha'
implementation 'io.opentelemetry:opentelemetry-sdk-extension-autoconfigure:1.37.0'
```

**Or use Java Agent (recommended):**
```dockerfile
ENV JAVA_TOOL_OPTIONS="-javaagent:/app/opentelemetry-javaagent.jar"
ENV OTEL_SERVICE_NAME=adservice
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://opentelemetry-collector:4317
```

## Environment Variables

All services should support these environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP collector endpoint | `opentelemetry-collector:4317` |
| `OTEL_SERVICE_NAME` | Service name (used by some SDKs) | Service-specific |
| `DEPLOYMENT_ENV` | Deployment environment | (empty) |

## Kubernetes Manifest Configuration

Add these environment variables to each deployment:

```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "opentelemetry-collector:4317"
  - name: OTEL_SERVICE_NAME
    value: "service-name-here"
  - name: DEPLOYMENT_ENV
    value: "production"
```

## Baggage Usage

Baggage is used for cross-service context propagation beyond trace context.

**Common baggage keys:**
- `session.id` - User session ID (set by frontend)
- `user.id` - User identifier (set by frontend)
- `order.id` - Order ID (set by checkoutservice during checkout)

**Go - Setting baggage:**
```go
import "go.opentelemetry.io/otel/baggage"

member, _ := baggage.NewMember("session.id", sessionID)
bag, _ := baggage.New(member)
ctx = baggage.ContextWithBaggage(ctx, bag)
```

**Go - Reading baggage:**
```go
bag := baggage.FromContext(ctx)
sessionID := bag.Member("session.id").Value()
```

## Trace Context Flow

```
User Request
    │
    ▼
Frontend (HTTP) ─────────────────────────────────────┐
    │ Creates initial span, sets session.id baggage  │
    │                                                 │
    ├──► ProductCatalogService (gRPC)                │
    │        └─ Child span, inherits trace context   │
    │                                                 │
    ├──► CartService (gRPC)                          │
    │        └─ Child span                           │
    │        └──► Redis (instrumented)               │
    │                                                 │
    ├──► CurrencyService (gRPC)                      │
    │        └─ Child span                           │
    │                                                 │
    ├──► RecommendationService (gRPC)                │
    │        └─ Child span                           │
    │        └──► ProductCatalogService              │
    │                                                 │
    └──► CheckoutService (gRPC)                      │
             │ Sets order.id baggage                 │
             ├──► CartService                        │
             ├──► ProductCatalogService              │
             ├──► CurrencyService                    │
             ├──► ShippingService                    │
             ├──► PaymentService                     │
             └──► EmailService                       │
                                                     │
    All spans share same trace_id ◄──────────────────┘
```

## Testing Traces

1. Deploy the application
2. Generate some traffic (browse products, add to cart, checkout)
3. View traces in your observability backend (Jaeger, etc.)
4. Verify:
   - Single trace ID spans all services
   - Proper parent-child relationships
   - Service names are correct
   - Span names are descriptive
   - Baggage propagates correctly

## Common Issues

1. **Broken traces**: Ensure propagators are set BEFORE creating gRPC clients
2. **Missing spans**: Check that instrumentation middleware is applied
3. **Wrong service names**: Verify `service.name` resource attribute
4. **Connection refused**: Check collector endpoint and network policies
