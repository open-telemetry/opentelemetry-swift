//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation


public class RegisteredView {
    public private(set) var selector : InstrumentSelector
    public private(set) var view : StableView
    public private(set) var attributeProcessor : AttributeProcessor
    
    internal init(selector: InstrumentSelector, view: StableView, attributeProcessor: AttributeProcessor) {
        self.selector = selector
        self.view = view
        self.attributeProcessor = attributeProcessor
    }
}
