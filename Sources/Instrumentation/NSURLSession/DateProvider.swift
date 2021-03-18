/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

/// Provides current device time information.
internal protocol DateProvider {
    /// Current device time.
    func currentDate() -> Date
}

internal struct SystemDateProvider: DateProvider {
    @inlinable
    func currentDate() -> Date { return Date() }
}
