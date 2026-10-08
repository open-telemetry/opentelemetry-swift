//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class RegisteredView {
  public private(set) var selector: InstrumentSelector
  public private(set) var view: View
  public private(set) var attributeProcessor: AttributeProcessor

  init(
    selector: InstrumentSelector,
    view: View,
    attributeProcessor: AttributeProcessor
  ) {
    self.selector = selector
    self.view = view
    self.attributeProcessor = attributeProcessor
  }
}
