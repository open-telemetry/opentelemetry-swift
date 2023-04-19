/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public class StableViewRegistry {
    private var instrumentDefaultRegisteredView = [InstrumentType: RegisteredView]()
    private var registeredViews = [RegisteredView]()

    init(aggregationSelector: DefaultAggregationSelector, registeredViews: [RegisteredView]) {
        for type in InstrumentType.allCases {
            instrumentDefaultRegisteredView[type] = RegisteredView(selector: InstrumentSelector.builder().setInstrument(name: ".*").build(), view: StableView.builder().withAggregation(aggregation: aggregationSelector.getDefaultAggregation(for: type)).build(), attributeProcessor: NoopAttributeProcessor.noop)
        }
        self.registeredViews = registeredViews
    }

    public func findViews(descriptor: InstrumentDescriptor, meterScope: InstrumentationScopeInfo) -> [RegisteredView] {
        return registeredViews.filter { view in
            if let instrumentType = view.selector.instrumentType, descriptor.type != instrumentType {
                return false
            }

            if let instrumentName = view.selector.instrumentName, descriptor.name.range(of: instrumentName, options: .regularExpression) == nil {
                return false
            }
            if let meterName = view.selector.meterName, meterName != meterScope.name {
                return false
            }

            if let meterVersion = view.selector.meterVersion, meterVersion != meterScope.version {
                return false
            }

            if let meterSchema = view.selector.meterSchemaUrl, meterSchema != meterScope.schemaUrl {
                return false
            }

            return true
        }
    }
}
