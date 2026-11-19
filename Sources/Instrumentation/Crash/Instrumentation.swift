/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import InstrumentationCommon

// `Instrumentation` moved to InstrumentationCommon so instrumentations can share it without
// depending on KSCrash. It was previously a public symbol of this module, so this alias keeps
// consumers that reach it through `import Crash` source-compatible.
public typealias Instrumentation = InstrumentationCommon.Instrumentation
