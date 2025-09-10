#!/bin/bash

# Script to update OpenTelemetry-swift-core dependency versions
# Usage: ./update_core_dependencies.sh <new_version>
# Example: ./update_core_dependencies.sh 1.2.0

set -e

if [ $# -eq 0 ]; then
    echo "Error: Must provide new opentelemetry-swift-core version"
    echo "Usage: $0 <new_version>"
    echo "Example: $0 1.2.0"
    exit 1
fi

NEW_VERSION=$1

# Validate semantic version format (accepts prereleases)
if [[ ! $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$ ]]; then
    echo "Error: Version must follow semantic versioning (e.g., 1.2.3, 1.0.0-beta.1)"
    exit 1
fi

echo "Updating opentelemetry-swift-core dependencies to version $NEW_VERSION"

# Update Package.swift
echo "Updating Package.swift..."
sed -i '' "s|.package(url: \"https://github.com/open-telemetry/opentelemetry-swift-core.git\", from: \".*\")|.package(url: \"https://github.com/open-telemetry/opentelemetry-swift-core.git\", from: \"$NEW_VERSION\")|" Package.swift

# Update all .podspec files
PODSPEC_FILES=$(find . -maxdepth 1 -name "*.podspec")
PODSPEC_COUNT=$(echo "$PODSPEC_FILES" | wc -l | tr -d ' ')

echo "Updating $PODSPEC_COUNT .podspec files..."

for podspec in $PODSPEC_FILES; do
    sed -i '' "s|spec.dependency 'OpenTelemetry-Swift-Api', '[^']*'|spec.dependency 'OpenTelemetry-Swift-Api', '~> $NEW_VERSION'|g" "$podspec"
    sed -i '' "s|spec.dependency 'OpenTelemetry-Swift-Sdk', '[^']*'|spec.dependency 'OpenTelemetry-Swift-Sdk', '~> $NEW_VERSION'|g" "$podspec"
done

echo "Update completed successfully"
