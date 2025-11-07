# OpenTelemetry Semantic Convention Proposal: MetricKit Stack Traces

## Overview

This document proposes a JSON format for representing Apple MetricKit stack traces in the OpenTelemetry [`exception.stacktrace`](https://opentelemetry.io/docs/specs/semconv/exceptions/exceptions-spans/) attribute. The format is based on Apple's MetricKit `MXCallStackTree` but simplified to reduce unnecessary complexity and make the data easier to process for post-mortem crash analysis.

## Format Specification

### Root Object

The root object contains two keys:

**`callStackPerThread`** (boolean, required)  
Whether the stack trace is for a single process thread (true) or for all process threads (false).

**`callStacks`** (array, required)  
An array of call stacks for a process or thread.

---

### Call Stack Object

A call stack is a dictionary containing two keys:

**`threadAttributed`** (boolean, optional)  
Indicates that the crash or exception occurred in this call stack.

**`callStackFrames`** (array, required)  
A flat array of stack frames, ordered from innermost (most recent call) to outermost (root call).

---

### Stack Frame Object

A stack frame is a dictionary containing three keys:

**`binaryName`** (string, required)  
The name of the binary associated with the stack frame.

**`binaryUUID`** (string, required)
A unique ID used to symbolicate a stack frame (format: 8-4-4-4-12 hex digits).

**`offsetAddress`** (integer, required)
The offset of the stack frame into the text segment of the binary. This is used for symbolication.

---

### Example
```json
{
  "callStackPerThread": true,
  "callStacks": [
    {
      "threadAttributed": false,
      "callStackFrames": [
        {
          "binaryUUID": "70B89F27-1634-3580-A695-57CDB41D7743",
          "offsetAddress": 165304,
          "binaryName": "MetricKitTestApp"
        },
        {
          "binaryUUID": "77A62F2E-8212-30F3-84C1-E8497440ACF8",
          "offsetAddress": 6948,
          "binaryName": "libdyld.dylib"
        }
      ]
    },
    {
      "threadAttributed": true,
      "callStackFrames": [
        {
          "binaryUUID": "A1B2C3D4-5678-90AB-CDEF-1234567890AB",
          "offsetAddress": 42000,
          "binaryName": "Foundation"
        }
      ]
    }
  ]
}
```

## Differences from Apple's MetricKit Format

This format is based on Apple's `MXCallStackTree.jsonRepresentation()` format but includes several simplifications to make the JSON easier to process.

### 1. Removed `callStackTree` Wrapper

The `callStackTree` wrapper adds an unnecessary level of nesting. Since the entire JSON document represents call stack data, the wrapper provides no additional information and only complicates parsing.

### 2. Flattened Stack Frames

Renamed `callStackRootFrames` to `callStackFrames` and removed the nested `subFrames` structure. Stack frames naturally form a sequence, not a tree, so representing them as a flat array is more intuitive. The order within the array (innermost to outermost) preserves all the information from the nested structure while being significantly easier to iterate over and process.

### 3. Removed `sampleCount` Field

The `sampleCount` field is specific to CPU profiling scenarios and is not relevant for general crash analysis. Since this format is designed primarily for post-mortem crash analysis, removing this field simplifies the format without losing essential information.

### 4. Renamed `offsetIntoBinaryTextSegment` to `offsetAddress`

Renamed for brevity while preserving the same semantic meaning - this field contains the offset into the binary's text segment used for symbolication.

### 5. Removed `address` Field

The runtime memory `address` changes with each execution due to Address Space Layout Randomization (ASLR) and cannot be used for symbolication. The `offsetAddress` (formerly `offsetIntoBinaryTextSegment`) contains all the information needed to symbolicate crashes post-mortem. Including `address` adds redundant data that serves no purpose for the primary use case.

