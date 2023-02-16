//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation


public struct RegisteredView {
    public private(set) var selector : InstrumentSelector
    public private(set) var view : StableView
//    public private(set) var viewAttributesProcessor : AttributesProcessor
    
    internal init(selector: InstrumentSelector, view: StableView){ //, viewAttributesProcessor: AttributesProcessor) {
        self.selector = selector
        self.view = view
//        self.viewAttributesProcessor = viewAttributesProcessor
    }
}
