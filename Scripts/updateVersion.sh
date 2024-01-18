#!/bin/sh
# This script expects two inputs
# $1 - The github token for opentelemetry-swift
# $2 - the git tag

#Update version number
sed -E -i '' 's/public static let OTEL_SWIFT_SDK_VERSION = ".+"/public static let OTEL_SWIFT_SDK_VERSION = "'$2\"/ ./Sources/OpenTelemetrySdk/Version.swift
git commit -m "Updated version number to $2"
git tag -f $2
git push -f --tags origin HEAD:main
