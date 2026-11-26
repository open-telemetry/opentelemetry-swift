#!/bin/bash
set -e -x

# Generates the Swift constants in Attributes/ from the federated registry in model/. The registry
# depends on the upstream semantic conventions version declared in model/manifest.yaml.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# repository: https://github.com/open-telemetry/weaver
WEAVER_VERSION=0.28.0

rm -rf "${SCRIPT_DIR}/Attributes"

docker run --rm \
  -v "${SCRIPT_DIR}/model:/source" \
  -v "${SCRIPT_DIR}/templates:/templates" \
  -v "${SCRIPT_DIR}:/output" \
  otel/weaver:v$WEAVER_VERSION \
  registry \
  generate \
  --registry=/source \
  --templates=/templates \
  swift \
  /output \
  -Doutput=/output/
