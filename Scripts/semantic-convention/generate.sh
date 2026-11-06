#!/bin/bash
set -e -x

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="${SCRIPT_DIR}/../.."

# --exclude-deprecated=true  deletes deprecated attributes (major release)
# --exclude-deprecated=false keeps them, marked @available(*, deprecated) (minor release)
EXCLUDE_DEPRECATED=true
for arg in "$@"; do
  case "$arg" in
    --exclude-deprecated=true|--exclude-deprecated=false) EXCLUDE_DEPRECATED="${arg#*=}" ;;
    *) echo "usage: $0 [--exclude-deprecated=true|false]" >&2; exit 1 ;;
  esac
done

# freeze the spec & generator tools versions to make SemanticAttributes generation reproducible

# repository: https://github.com/open-telemetry/semantic-conventions
SEMCONV_VERSION=1.38.0
SPEC_VERSION=v$SEMCONV_VERSION

# repository: https://github.com/open-telemetry/weaver
GENERATOR_VERSION=0.28.0

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
  -Dexclude_deprecated="$EXCLUDE_DEPRECATED" \

cd "$ROOT_DIR"


# update spec version reported by library
VERSION_FILE="${ROOT_DIR}/Sources/OpenTelemetryApi/OpenTelemetry.swift"
VERSION_PATTERN='public static (var|let) version = ".+"'
grep -Eq "$VERSION_PATTERN" "$VERSION_FILE" || { echo "error: no version declaration found in ${VERSION_FILE}" >&2; exit 1; }
sed -E -i.bak "s/${VERSION_PATTERN}/public static \1 version = \"${SPEC_VERSION}\"/" "$VERSION_FILE"
rm "${VERSION_FILE}.bak"
