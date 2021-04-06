#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="${SCRIPT_DIR}/../../"

# freeze the spec version to make SemanticAttributes generation reproducible
SPEC_VERSION=v1.1.0

cd ${SCRIPT_DIR}

rm -rf opentelemetry-specification || true
mkdir opentelemetry-specification
cd opentelemetry-specification

git init
git remote add origin https://github.com/open-telemetry/opentelemetry-specification.git
git fetch origin "$SPEC_VERSION"
git reset --hard FETCH_HEAD
cd ${SCRIPT_DIR}

docker run --rm \
  -v ${SCRIPT_DIR}/opentelemetry-specification/semantic_conventions/trace:/source \
  -v ${SCRIPT_DIR}/templates:/templates \
  -v ${ROOT_DIR}/Sources/OpenTelemetryApi/Trace/:/output \
  otel/semconvgen:0.2.1 \
  --yaml-root /source \
  code \
  --template /templates/SemanticAttributes.swift.j2 \
  --output /output/SemanticAttributes.swift \
  -Denum=SemanticAttributes \

docker run --rm \
  -v ${SCRIPT_DIR}/opentelemetry-specification/semantic_conventions/resource:/source \
  -v ${SCRIPT_DIR}/templates:/templates \
  -v ${ROOT_DIR}/Sources/OpenTelemetrySdk/Resources/:/output \
  otel/semconvgen:0.2.1 \
  --yaml-root /source \
  code \
  --template /templates/SemanticAttributes.swift.j2 \
  --output /output/ResourceAttributes.swift \
  -Denum=ResourceConstants \

cd "$ROOT_DIR"
