# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM --platform=$BUILDPLATFORM eclipse-temurin:21.0.9_10-jdk-noble@sha256:e2ba4c84f2356d829837f561e171482f5121d75e537e8fe04e91fb4381694641 AS builder

WORKDIR /app

COPY ["build.gradle", "gradlew", "./"]
COPY gradle gradle
RUN chmod +x gradlew
RUN ./gradlew downloadRepos

COPY . .
RUN chmod +x gradlew
RUN ./gradlew installDist

FROM eclipse-temurin:25.0.1_8-jre-alpine@sha256:b51543f89580c1ba70e441cfbc0cfc1635c3c16d2e2d77fec9d890342a3a8687

# @TODO: https://github.com/GoogleCloudPlatform/microservices-demo/issues/2517
# Download Stackdriver Profiler Java agent
# RUN mkdir -p /opt/cprof && \
#     wget -q -O- https://storage.googleapis.com/cloud-profiler/java/latest/profiler_java_agent_alpine.tar.gz \
#     | tar xzv -C /opt/cprof && \
#     rm -rf profiler_java_agent.tar.gz

WORKDIR /app

# Download OpenTelemetry Java agent
RUN wget -q -O /app/opentelemetry-javaagent.jar \
    https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.12.0/opentelemetry-javaagent.jar
COPY --from=builder /app .

# Set OpenTelemetry configuration via environment variables
ENV OTEL_SERVICE_NAME=adservice
ENV OTEL_TRACES_EXPORTER=otlp
ENV OTEL_EXPORTER_OTLP_PROTOCOL=grpc
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://opentelemetry-collector.openchoreo-observability-plane.svc.cluster.local:4317
ENV JAVA_TOOL_OPTIONS=-javaagent:/app/opentelemetry-javaagent.jar

EXPOSE 9555
ENTRYPOINT ["/app/build/install/hipstershop/bin/AdService"]
