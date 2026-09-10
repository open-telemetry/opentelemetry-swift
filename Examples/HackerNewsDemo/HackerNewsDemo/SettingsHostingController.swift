/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import UIKit
import SwiftUI

class SettingsHostingController: UIHostingController<SettingsView> {
  init() {
    super.init(rootView: SettingsView())
  }

  @available(*, unavailable)
  @MainActor dynamic required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
