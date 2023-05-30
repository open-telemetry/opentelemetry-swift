////
//// Copyright The OpenTelemetry Authors
//// SPDX-License-Identifier: Apache-2.0
//// 
//
//import Foundation
//
//public class DefaultStableMeterProvider: StableMeterProvider {
//    static var proxyMeter = StableProxyMeter()
//    static var proxyMeterBuilder = ProxyMeterBuilder()
//    static var initialized = false
//    
//    class StableProxyMeter : StableMeter {
//        func counterBuilder(name: String) -> LongCounterBuilder {
//        }
//        
//        func upDownCounterBuilder(name: String) -> LongUpDownCounterBuilder {
//        }
//        
//        func histogramBuilder(name: String) -> DoubleHistogramBuilder {
//        }
//        
//        func gaugeBuilder(name: String) -> DoubleGaugeBuilder {
//        }
//    }
//    
//    class ProxyMeterBuilder :  MeterBuilder {
//        func setSchemaUrl(schemaUrl: String) -> Self {
//            return self
//        }
//        
//        func setInstrumentationVersion(instrumentationVersion: String) -> Self {
//            return self
//        }
//        
//        func build() -> StableMeter {
//            return DefaultStableMeterProvider.proxyMeter
//        }
//        
//    
//    init() {}
//    
//    public static func setDefault(meterFactory: StableMeterProvider) {
//        guard !initialized else {
//            return
//        }
//        instance = meterFactory
//        proxyMeter.updateMeter(realMeter: meterFactory.get(name: ""))
//        initialized = true
//    }
//    
//    public func get(name: String) -> StableMeter {
//        return Self.initialized ? Self.instance.get(name: name) : Self.proxyMeter
//    }
//    
//    public func meterBuilder(name: String) -> MeterBuilder {
//        return Self.initialized ? self.instance.meterBuilder(name: name) : return Self.proxyMeterBuilder
//        
//    }
//    
//    public static var instance : StableMeterProvider = DefaultStableMeterProvider()
//}
