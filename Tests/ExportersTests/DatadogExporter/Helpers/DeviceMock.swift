// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

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
