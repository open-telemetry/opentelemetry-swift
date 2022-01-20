/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol ObservableMeter {
    associatedtype T
    associatedtype U : ObservableResult where U.T == T
    var callback : (U) -> () {get}
}
