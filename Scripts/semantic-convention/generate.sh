#!/bin/bash
set -e -x

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="${SCRIPT_DIR}/../.."

# freeze the spec & generator tools versions to make SemanticAttributes generation reproducible

# repository: https://github.com/open-telemetry/semantic-conventions
SEMCONV_VERSION=1.38.0
SPEC_VERSION=v$SEMCONV_VERSION

# repository: https://github.com/open-telemetry/build-tools
GENERATOR_VERSION=0.17.1

cd ${SCRIPT_DIR}

rm -rf semantic-conventions || true
mkdir semantic-conventions
cd semantic-conventions

git init
git remote add origin https://github.com/open-telemetry/semantic-conventions.git
git fetch origin "$SPEC_VERSION"
git reset --hard FETCH_HEAD
cd ${SCRIPT_DIR}

docker run --rm \
  -v ${SCRIPT_DIR}/semantic-conventions/model:/source \
  -v ${SCRIPT_DIR}/templates:/templates \
  -v ${ROOT_DIR}/Sources/OpenTelemetryApi/Common/SemanticAttributes:/output \
  otel/weaver:v$GENERATOR_VERSION \
  registry \
  generate \
  --registry=/source \
  --templates=/templates \
  ./ \
  /output \
  -Doutput=/output/ \

cd "$ROOT_DIR"


# update spec version reported by library
sed -E -i '' 's/public static var version = ".+"/public static var version = "'$SPEC_VERSION\"/ ${ROOT_DIR}/Sources/OpenTelemetryApi/OpenTelemetry.swift
