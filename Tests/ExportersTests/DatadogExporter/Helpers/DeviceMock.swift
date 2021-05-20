/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !os(macOS)
import UIKit

class UIDeviceMock: UIDevice {
    private var _model: String
    private var _systemName: String
    private var _systemVersion: String
    private var _isBatteryMonitoringEnabled: Bool
    private var _batteryState: UIDevice.BatteryState
    private var _batteryLevel: Float

    init(
        model: String = .mockAny(),
        systemName: String = .mockAny(),
        systemVersion: String = .mockAny()
    ) {
        self._model = model
        self._systemName = systemName
        self._systemVersion = systemVersion
    }

    override var model: String { _model }
    override var systemName: String { _systemName }
    override var systemVersion: String { "mock system version" }
}

#endif
