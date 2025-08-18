# Contributing

We welcome your contributions to this project!

Please read the [OpenTelemetry Contributor Guide][otel-contributor-guide]
for general information on how to contribute including signing the Contributor License Agreement, the Code of Conduct, and Community Expectations.

## Before you begin

### Specifications / Guidelines

As with other OpenTelemetry clients, opentelemetry-swift follows the
[opentelemetry-specification][otel-specification] and the
[library guidelines][otel-lib-guidelines].

### Focus on Capabilities, Not Structure Compliance

OpenTelemetry is an evolving specification, one where the desires and
use cases are clear, but the method to satisfy those uses cases are not.

As such, Contributions should provide functionality and behavior that
conforms to the specification, but the interface and structure are flexible.

It is preferable to have contributions follow the idioms of the language
rather than conform to specific API names or argument patterns in the spec.

For a deeper discussion, see: https://github.com/open-telemetry/opentelemetry-specification/issues/165

## Getting started

Everyone is welcome to contribute code via GitHub Pull Requests (PRs).

### Fork the repo

Fork the project on GitHub by clicking the `Fork` button at the top of the
repository and clone your fork locally:

```sh
git clone git@github.com:YOUR_GITHUB_NAME/opentelemetry-swift.git
```

or
```sh
git clone https://github.com/YOUR_GITHUB_NAME/opentelemetry-swift.git
```

It can be helpful to add the `open-telemetry/opentelemetry-swift` repo as a
remote so you can track changes (we're adding as `upstream` here):

```sh
git remote add upstream git@github.com:open-telemetry/opentelemetry-swift.git
```

or

```sh
git remote add upstream https://github.com/open-telemetry/opentelemetry-swift.git
```

For more detailed information on this workflow read the
[GitHub Workflow][otel-github-workflow].

### Build

Open `Package.swift` in Xcode and follow normal development process.

To build from the command line you need `swift` version `5.0+`.

```sh
swift build
```

### Test

Open `Package.swift` in Xcode and follow normal testing process.

To test from the command line you need `swift` version `5.0+`.

```sh
swift test
```
### Linting
#### SwiftLint
The SwiftLint Xcode plugin can be optionally enabled during development by using an environmental variable when opening the project from the commandline. 
```
OTEL_ENABLE_SWIFTLINT=1 open Package.swift
```
Note: Xcode must be completely closed before running the above command, close Xcode using `⌘Q` or running `killall xcode` in the commandline.  

#### SwiftFormat
SwiftFormat is also used to enforce formatting rules where Swiftlint isn't able.
It will also run in the optionally enabled pre-commit hook if installed via `brew install swiftformat`. 

### Make your modifications

Always work in a branch from your fork:

```sh
git checkout -b my-feature-branch
```

### Create a Pull Request

You'll need to create a Pull Request once you've finished your work.
The [Kubernetes GitHub Workflow][kube-github-workflow-pr] document has
a significant section on PRs.

Open the PR against the `open-telemetry/opentelemetry-swift repository.

Please put `[WIP]` in the title, or create it as a [`Draft`][github-draft] PR
if the PR is not ready for review.

#### Sign the Contributor License Agreement (CLA)

All PRs are automatically checked for a signed CLA. Your first PR fails this
check if you haven't signed the [CNCF CLA][cncf-cla].

The failed check displays a link to `details` which walks you through the
process. Don't worry it's painless!

### Review and feedback

PRs require a review from one or more of the [code owners](CODEOWNERS) before
merge. You'll probably get some feedback from these fine folks which helps to
make the project that much better. Respond to the feedback and work with your
reviewer(s) to resolve any issues.

### Generating OTLP protobuf files
Occasionally, the opentelemetry protocol's protobuf definitions are updated and need to be regenerated for the OTLP exporters. This is documentation on how to accomplish that for this project. Other projects can regenerate their otlp protobuf files using the [Open Telemetry build tools][build-tools].

#### Requirements
- [protoc]
- [grpc-swift]
- [opentelemetry-proto]

##### Install protoc
```asciidoc
$ brew install protobuf
$ protoc --version  # Ensure compiler version is 3+
```
##### Installing grpc-swift
```
 brew install swift-protobuf grpc-swift
 ```

##### Generating otlp protobuf files

Clone [opentelemetry-proto]

From within opentelemetry-proto:

```shell
# collect the proto definitions:
PROTO_FILES=($(ls opentelemetry/proto/*/*/*/*.proto opentelemetry/proto/*/*/*.proto))
# generate swift proto files
for file in "${PROTO_FILES[@]}"
do
  protoc --swift_opt=Visibility=Public --swift_out=./out ${file}
done

# genearate GRPC swift proto files
protoc --swift_opt=Visibility=Public --grpc-swift_opt=Visibility=Public  --swift_out=./out --grpc-swift_out=./out opentelemetry/proto/collector/trace/v1/trace_service.proto
protoc --swift_opt=Visibility=Public --grpc-swift_opt=Visibility=Public --swift_out=./out --grpc-swift_out=./out opentelemetry/proto/collector/metrics/v1/metrics_service.proto
protoc --swift_opt=Visibility=Public --grpc-swift_opt=Visibility=Public --swift_out=./out --grpc-swift_out=./out opentelemetry/proto/collector/logs/v1/logs_service.proto
```

Replace the generated files in `Sources/Exporters/OpenTelemetryProtocolCommon/proto` & `Sources/Exporters/OpenTelemetryGrpc/proto`:
###### `OpenTelemetryProtocolGrpc/proto` file list
`logs_service.grpc.swift`
`metrics_serivce.grpc.swift`
`trace_service.grpc.swift`

###### `OpenTelemetryProtocolCommon/proto`
`common.pb.swift`
`logs.pb.swift`
`logs_service.pb.swift`
`metrics.pb.swift`
`metrics_services.pb.swift`
`resource.pb.swift`
`trace.pb.swift`
`trace_service.pb.swift`

[cncf-cla]: https://identity.linuxfoundation.org/projects/cncf
[github-draft]: https://github.blog/2019-02-14-introducing-draft-pull-requests/
[kube-github-workflow-pr]: https://github.com/kubernetes/community/blob/master/contributors/guide/github-workflow.md#7-create-a-pull-request
[otel-contributor-guide]: https://github.com/open-telemetry/community/blob/master/CONTRIBUTING.md
[otel-github-workflow]: https://github.com/open-telemetry/community/blob/master/CONTRIBUTING.md#github-workflow
[otel-lib-guidelines]: https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/library-guidelines.md
[otel-specification]: https://github.com/open-telemetry/opentelemetry-specification
[grpc-swift]: https://github.com/grpc/grpc-swift
[opentelemetry-proto]: https://github.com/open-telemetry/opentelemetry-proto
[protoc]: https://grpc.io/docs/protoc-installation/
[build-tools]: https://github.com/open-telemetry/build-tools
