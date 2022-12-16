/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol Logger {

    func eventBuilder(name: String) -> EventBuilder
    func logRecordBuilder() -> LogRecordBuilder
}

