import Foundation
import OpenTelemetryApi

/// A protocol to make it easier to write generic functions for AttributeValues.
protocol AttributeValueConvertable {
    func attributeValue() -> AttributeValue
}

extension Int: AttributeValueConvertable {
    func attributeValue() -> AttributeValue {
        AttributeValue.int(self)
    }
}
extension Bool: AttributeValueConvertable {
    func attributeValue() -> AttributeValue {
        AttributeValue.bool(self)
    }
}
extension String: AttributeValueConvertable {
    func attributeValue() -> AttributeValue {
        AttributeValue.string(self)
    }
}

extension [String]: AttributeValueConvertable {
    func attributeValue() -> AttributeValue {
        AttributeValue.array(AttributeArray(values: self.map { AttributeValue.string($0) }))
    }
}

extension TimeInterval: AttributeValueConvertable {
    func attributeValue() -> AttributeValue {
        // The OTel standard for time durations is seconds, which is also what TimeInterval is.
        // https://opentelemetry.io/docs/specs/semconv/general/metrics/
        AttributeValue.double(self)
    }
}

extension Measurement: AttributeValueConvertable {
    func attributeValue() -> AttributeValue {
        // Convert to the "base unit", such as seconds or bytes.
        let value =
            if let unit = self.unit as? Dimension {
                unit.converter.baseUnitValue(fromValue: self.value)
            } else {
                self.value
            }
        return AttributeValue.double(value)
    }
}
