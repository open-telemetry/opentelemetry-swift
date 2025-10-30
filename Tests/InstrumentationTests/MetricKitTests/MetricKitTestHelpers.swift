#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
import Foundation
import MetricKit

// Most MetricKit classes are readonly, and don't have public constructors, so to make fake data,
// we have to subclass them. Unfortunately, Swift doesn't really have any metaprogramming
// capability, so there is a ton of boilerplate code.
//
// We have to create a separate fake histogram class for each type of histogram and average,
// because "Inheritance from a generic Objective-C class 'MXHistogramBucket' must bind type
// parameters of 'MXHistogramBucket' to specific concrete types."

class FakeDurationHistogramBucket: MXHistogramBucket<UnitDuration> {
    private let start: Measurement<UnitDuration>
    private let end: Measurement<UnitDuration>
    private let count: Int

    init(
        start: Measurement<UnitDuration>,
        end: Measurement<UnitDuration>,
        count: Int
    ) {
        self.start = start
        self.end = end
        self.count = count
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var bucketStart: Measurement<UnitDuration> { start }
    override var bucketEnd: Measurement<UnitDuration> { end }
    override var bucketCount: Int { count }
}

class FakeDurationHistogram: MXHistogram<UnitDuration> {
    private let average: Measurement<UnitDuration>

    /// Creates a Histogram with a single bucket that will have the correct average value.
    init(average: Measurement<UnitDuration>) {
        self.average = average
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var totalBucketCount: Int { 1 }

    override var bucketEnumerator: NSEnumerator {
        // Just make a bucket whose average will be correct.
        let delta = average * 0.5
        let bucket = FakeDurationHistogramBucket(
            start: average - delta,
            end: average + delta,
            count: 1
        )
        return NSArray(object: bucket).objectEnumerator()
    }
}

class FakeSignalBarsHistogramBucket: MXHistogramBucket<MXUnitSignalBars> {
    private let start: Measurement<MXUnitSignalBars>
    private let end: Measurement<MXUnitSignalBars>
    private let count: Int

    init(
        start: Measurement<MXUnitSignalBars>,
        end: Measurement<MXUnitSignalBars>,
        count: Int
    ) {
        self.start = start
        self.end = end
        self.count = count
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var bucketStart: Measurement<MXUnitSignalBars> { start }
    override var bucketEnd: Measurement<MXUnitSignalBars> { end }
    override var bucketCount: Int { count }
}

class FakeSignalBarsHistogram: MXHistogram<MXUnitSignalBars> {
    private let average: Measurement<MXUnitSignalBars>

    /// Creates a Histogram with a single bucket that will have the correct average value.
    init(average: Measurement<MXUnitSignalBars>) {
        self.average = average
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var totalBucketCount: Int { 1 }

    override var bucketEnumerator: NSEnumerator {
        // Just make a bucket whose average will be correct.
        let delta = average * 0.5
        let bucket = FakeSignalBarsHistogramBucket(
            start: average - delta,
            end: average + delta,
            count: 1
        )
        return NSArray(object: bucket).objectEnumerator()
    }
}

class FakeInformationStorageAverage: MXAverage<UnitInformationStorage> {
    private let average: Measurement<UnitInformationStorage>

    init(average: Measurement<UnitInformationStorage>) {
        self.average = average
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var averageMeasurement: Measurement<UnitInformationStorage> { average }
    override var sampleCount: Int { 1 }
    override var standardDeviation: Double { 1.0 }
}

class FakeMetricPayload: MXMetricPayload {
    private let now = Date()

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var latestApplicationVersion: String { "3.14.159" }

    override var includesMultipleApplicationVersions: Bool { false }

    override var timeStampBegin: Date {
        // MetricKit generally reports data from the previous day.
        now.advanced(by: TimeInterval(-1 * 60 * 60 * 24))
    }

    override var timeStampEnd: Date { now }

    override var cpuMetrics: MXCPUMetric? {
        class FakeCPUMetric: MXCPUMetric {
            override var cumulativeCPUTime: Measurement<UnitDuration> {
                Measurement(value: 1.0, unit: UnitDuration.seconds)
            }

            @available(iOS 14.0, *)
            override var cumulativeCPUInstructions: Measurement<Unit> {
                Measurement(value: 2.0, unit: Unit(symbol: "instructions"))
            }
        }
        return FakeCPUMetric()
    }

    override var gpuMetrics: MXGPUMetric? {
        class FakeGPUMetric: MXGPUMetric {
            override var cumulativeGPUTime: Measurement<UnitDuration> {
                return Measurement(value: 3.0, unit: UnitDuration.hours)
            }
        }
        return FakeGPUMetric()
    }

    override var cellularConditionMetrics: MXCellularConditionMetric? {
        class FakeCellularConditionMetric: MXCellularConditionMetric {
            override var histogrammedCellularConditionTime: MXHistogram<MXUnitSignalBars> {
                FakeSignalBarsHistogram(
                    average: Measurement(value: 4.0, unit: MXUnitSignalBars.bars)
                )
            }
        }
        return FakeCellularConditionMetric()
    }

    override var applicationTimeMetrics: MXAppRunTimeMetric? {
        class FakeAppRunTimeMetric: MXAppRunTimeMetric {
            override var cumulativeForegroundTime: Measurement<UnitDuration> {
                Measurement(value: 5.0, unit: UnitDuration.minutes)
            }
            override var cumulativeBackgroundTime: Measurement<UnitDuration> {
                Measurement(value: 6.0, unit: UnitDuration.microseconds)
            }
            override var cumulativeBackgroundAudioTime: Measurement<UnitDuration> {
                Measurement(value: 7.0, unit: UnitDuration.milliseconds)
            }
            override var cumulativeBackgroundLocationTime: Measurement<UnitDuration> {
                Measurement(value: 8.0, unit: UnitDuration.minutes)
            }
        }
        return FakeAppRunTimeMetric()
    }

    override var locationActivityMetrics: MXLocationActivityMetric? {
        class FakeLocationActivityMetric: MXLocationActivityMetric {
            override var cumulativeBestAccuracyTime: Measurement<UnitDuration> {
                Measurement(value: 9.0, unit: UnitDuration.seconds)
            }
            override var cumulativeBestAccuracyForNavigationTime: Measurement<UnitDuration> {
                Measurement(value: 10.0, unit: UnitDuration.seconds)
            }
            override var cumulativeNearestTenMetersAccuracyTime: Measurement<UnitDuration> {
                Measurement(value: 11.0, unit: UnitDuration.seconds)
            }
            override var cumulativeHundredMetersAccuracyTime: Measurement<UnitDuration> {
                Measurement(value: 12.0, unit: UnitDuration.seconds)
            }
            override var cumulativeKilometerAccuracyTime: Measurement<UnitDuration> {
                Measurement(value: 13.0, unit: UnitDuration.seconds)
            }
            override var cumulativeThreeKilometersAccuracyTime: Measurement<UnitDuration> {
                Measurement(value: 14.0, unit: UnitDuration.seconds)
            }
        }
        return FakeLocationActivityMetric()
    }

    override var networkTransferMetrics: MXNetworkTransferMetric? {
        class FakeNetworkTransferMetric: MXNetworkTransferMetric {
            override var cumulativeWifiUpload: Measurement<UnitInformationStorage> {
                Measurement(value: 15.0, unit: UnitInformationStorage.bytes)
            }
            override var cumulativeWifiDownload: Measurement<UnitInformationStorage> {
                Measurement(value: 16.0, unit: UnitInformationStorage.kilobytes)
            }
            override var cumulativeCellularUpload: Measurement<UnitInformationStorage> {
                Measurement(value: 17.0, unit: UnitInformationStorage.megabytes)
            }
            override var cumulativeCellularDownload: Measurement<UnitInformationStorage> {
                Measurement(value: 18.0, unit: UnitInformationStorage.gigabytes)
            }
        }
        return FakeNetworkTransferMetric()
    }

    override var applicationLaunchMetrics: MXAppLaunchMetric? {
        class FakeAppLaunchMetric: MXAppLaunchMetric {
            override var histogrammedTimeToFirstDraw: MXHistogram<UnitDuration> {
                FakeDurationHistogram(average: Measurement(value: 19.0, unit: UnitDuration.minutes))
            }
            override var histogrammedApplicationResumeTime: MXHistogram<UnitDuration> {
                FakeDurationHistogram(average: Measurement(value: 20.0, unit: UnitDuration.minutes))
            }

            @available(iOS 15.2, *)
            override var histogrammedOptimizedTimeToFirstDraw: MXHistogram<UnitDuration> {
                FakeDurationHistogram(average: Measurement(value: 21.0, unit: UnitDuration.minutes))
            }

            @available(iOS 16.0, *)
            override var histogrammedExtendedLaunch: MXHistogram<UnitDuration> {
                FakeDurationHistogram(average: Measurement(value: 22.0, unit: UnitDuration.minutes))
            }
        }
        return FakeAppLaunchMetric()
    }

    override var applicationResponsivenessMetrics: MXAppResponsivenessMetric? {
        class FakeAppResponsivenessMetric: MXAppResponsivenessMetric {
            override var histogrammedApplicationHangTime: MXHistogram<UnitDuration> {
                FakeDurationHistogram(average: Measurement(value: 23.0, unit: UnitDuration.hours))
            }
        }
        return FakeAppResponsivenessMetric()
    }

    override var diskIOMetrics: MXDiskIOMetric? {
        class FakeDiskIOMetric: MXDiskIOMetric {
            override var cumulativeLogicalWrites: Measurement<UnitInformationStorage> {
                Measurement(value: 24.0, unit: UnitInformationStorage.terabytes)
            }
        }
        return FakeDiskIOMetric()
    }

    override var memoryMetrics: MXMemoryMetric? {
        class FakeMemoryMetric: MXMemoryMetric {
            override var peakMemoryUsage: Measurement<UnitInformationStorage> {
                Measurement(value: 25.0, unit: UnitInformationStorage.bytes)
            }
            override var averageSuspendedMemory: MXAverage<UnitInformationStorage> {
                FakeInformationStorageAverage(
                    average: Measurement(value: 26.0, unit: UnitInformationStorage.bytes)
                )
            }
        }
        return FakeMemoryMetric()
    }

    override var displayMetrics: MXDisplayMetric? {
        class FakePixelLuminanceAverage: MXAverage<MXUnitAveragePixelLuminance> {
            override var averageMeasurement: Measurement<MXUnitAveragePixelLuminance> {
                Measurement(value: 27.0, unit: MXUnitAveragePixelLuminance.apl)
            }
            override var sampleCount: Int { 1 }
            override var standardDeviation: Double { 1.0 }
        }
        class FakeDisplayMetric: MXDisplayMetric {
            override var averagePixelLuminance: MXAverage<MXUnitAveragePixelLuminance>? {
                FakePixelLuminanceAverage()
            }
        }
        return FakeDisplayMetric()
    }

    @available(iOS 14.0, *)
    override var animationMetrics: MXAnimationMetric? {
        class FakeAnimationMetric: MXAnimationMetric {
            override var scrollHitchTimeRatio: Measurement<Unit> {
                Measurement(value: 28.0, unit: Unit(symbol: "ratio"))
            }
        }
        return FakeAnimationMetric()
    }

    override var metaData: MXMetaData? {
        class FakeMetaData: MXMetaData {
            override var regionFormat: String { "format" }
            override var osVersion: String { "os" }
            override var deviceType: String { "device" }
            override var applicationBuildVersion: String { "build" }

            @available(iOS 14.0, *)
            override var platformArchitecture: String { "arch" }

            @available(iOS 17.0, *)
            override var lowPowerModeEnabled: Bool { true }

            @available(iOS 17.0, *)
            override var isTestFlightApp: Bool { true }

            @available(iOS 17.0, *)
            override var pid: pid_t { 29 }
        }
        return FakeMetaData()
    }

    @available(iOS 14.0, *)
    override var applicationExitMetrics: MXAppExitMetric? {
        class FakeAppExitMetric: MXAppExitMetric {
            override var foregroundExitData: MXForegroundExitData {
                class FakeForegroundExitData: MXForegroundExitData {
                    override var cumulativeNormalAppExitCount: Int { 30 }
                    override var cumulativeMemoryResourceLimitExitCount: Int { 31 }
                    override var cumulativeBadAccessExitCount: Int { 32 }
                    override var cumulativeAbnormalExitCount: Int { 33 }
                    override var cumulativeIllegalInstructionExitCount: Int { 34 }
                    override var cumulativeAppWatchdogExitCount: Int { 35 }
                }
                return FakeForegroundExitData()
            }

            override var backgroundExitData: MXBackgroundExitData {
                class FakeBackgroundExitData: MXBackgroundExitData {
                    override var cumulativeNormalAppExitCount: Int { 36 }
                    override var cumulativeMemoryResourceLimitExitCount: Int { 37 }
                    override var cumulativeCPUResourceLimitExitCount: Int { 38 }
                    override var cumulativeMemoryPressureExitCount: Int { 39 }
                    override var cumulativeBadAccessExitCount: Int { 40 }
                    override var cumulativeAbnormalExitCount: Int { 41 }
                    override var cumulativeIllegalInstructionExitCount: Int { 42 }
                    override var cumulativeAppWatchdogExitCount: Int { 43 }
                    override var cumulativeSuspendedWithLockedFileExitCount: Int { 44 }
                    override var cumulativeBackgroundTaskAssertionTimeoutExitCount: Int { 45 }
                }
                return FakeBackgroundExitData()
            }
        }
        return FakeAppExitMetric()
    }

    override var signpostMetrics: [MXSignpostMetric]? {
        class FakeSignpostIntervalData: MXSignpostIntervalData {
            override var histogrammedSignpostDuration: MXHistogram<UnitDuration> {
                FakeDurationHistogram(average: Measurement(value: 46.0, unit: UnitDuration.seconds))
            }
            override var cumulativeCPUTime: Measurement<UnitDuration>? {
                Measurement(value: 47.0, unit: UnitDuration.seconds)
            }
            override var averageMemory: MXAverage<UnitInformationStorage>? {
                FakeInformationStorageAverage(
                    average: Measurement(value: 48.0, unit: UnitInformationStorage.bytes)
                )
            }
            override var cumulativeLogicalWrites: Measurement<UnitInformationStorage>? {
                Measurement(value: 49.0, unit: UnitInformationStorage.bytes)
            }

            @available(iOS 15.0, *)
            override var cumulativeHitchTimeRatio: Measurement<Unit>? {
                Measurement(value: 50.0, unit: Unit(symbol: "ratio"))
            }
        }

        class FakeSignpostMetric: MXSignpostMetric {
            private let name: String
            private let category: String
            private let count: Int

            init(name: String, category: String, count: Int) {
                self.name = name
                self.category = category
                self.count = count
                super.init()
            }

            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            override var signpostName: String { name }
            override var signpostCategory: String { category }
            override var signpostIntervalData: MXSignpostIntervalData? {
                FakeSignpostIntervalData()
            }
            override var totalCount: Int { count }
        }
        return [
            FakeSignpostMetric(name: "signpost1", category: "cat1", count: 51),
            FakeSignpostMetric(name: "signpost2", category: "cat2", count: 52),
        ]
    }
}

@available(iOS 14.0, *)
class FakeCallStackTree: MXCallStackTree {
    override func jsonRepresentation() -> Data {
        return Data("fake json stacktrace".utf8)
    }
}

@available(iOS 14.0, *)
class FakeDiagnosticPayload: MXDiagnosticPayload {
    private let now = Date()

    override var timeStampBegin: Date {
        // MetricKit generally reports data from the previous day.
        now.advanced(by: TimeInterval(-1 * 60 * 60 * 24))
    }

    override var timeStampEnd: Date { now }

    override var cpuExceptionDiagnostics: [MXCPUExceptionDiagnostic]? {
        class FakeCPUExceptionDiagnostic: MXCPUExceptionDiagnostic {
            override var callStackTree: MXCallStackTree { FakeCallStackTree() }
            override var totalCPUTime: Measurement<UnitDuration> {
                Measurement(value: 53.0, unit: UnitDuration.minutes)
            }
            override var totalSampledTime: Measurement<UnitDuration> {
                Measurement(value: 54.0, unit: UnitDuration.hours)
            }
        }
        return [FakeCPUExceptionDiagnostic()]
    }

    override var diskWriteExceptionDiagnostics: [MXDiskWriteExceptionDiagnostic]? {
        class FakeDiskWriteExceptionDiagnostic: MXDiskWriteExceptionDiagnostic {
            override var callStackTree: MXCallStackTree { FakeCallStackTree() }
            override var totalWritesCaused: Measurement<UnitInformationStorage> {
                Measurement(value: 55.0, unit: UnitInformationStorage.megabytes)
            }
        }
        return [FakeDiskWriteExceptionDiagnostic()]
    }

    override var hangDiagnostics: [MXHangDiagnostic]? {
        class FakeHangDiagnostic: MXHangDiagnostic {
            override var callStackTree: MXCallStackTree { FakeCallStackTree() }
            override var hangDuration: Measurement<UnitDuration> {
                Measurement(value: 56.0, unit: UnitDuration.seconds)
            }
        }
        return [FakeHangDiagnostic()]
    }

    override var crashDiagnostics: [MXCrashDiagnostic]? {
        class FakeCrashDiagnostic: MXCrashDiagnostic {
            override var callStackTree: MXCallStackTree { FakeCallStackTree() }
            override var terminationReason: String? { "reason" }
            override var virtualMemoryRegionInfo: String? { nil }
            override var exceptionType: NSNumber? { NSNumber(integerLiteral: 57) }
            override var exceptionCode: NSNumber? { NSNumber(integerLiteral: 58) }
            override var signal: NSNumber? { NSNumber(integerLiteral: 59) }

            @available(iOS 17.0, *)
            override var exceptionReason: MXCrashDiagnosticObjectiveCExceptionReason? {
                class FakeCrashDiagnosticObjectiveCExceptionReason:
                    MXCrashDiagnosticObjectiveCExceptionReason
                {
                    override var composedMessage: String { "message: 1 2" }
                    override var formatString: String { "message: %d %d" }
                    override var arguments: [String] { ["1", "2"] }
                    override var exceptionType: String { "ExceptionType" }
                    override var className: String { "MyClass" }
                    override var exceptionName: String { "MyCrash" }
                }
                return FakeCrashDiagnosticObjectiveCExceptionReason()
            }
        }
        return [FakeCrashDiagnostic()]
    }

    #if !os(macOS)
    @available(iOS 16.0, *)
    override var appLaunchDiagnostics: [MXAppLaunchDiagnostic]? {
        class FakeAppLaunchDiagnostic: MXAppLaunchDiagnostic {
            override var callStackTree: MXCallStackTree { FakeCallStackTree() }
            override var launchDuration: Measurement<UnitDuration> {
                Measurement(value: 60.0, unit: UnitDuration.seconds)
            }
        }
        return [FakeAppLaunchDiagnostic()]
    }
    #endif
}
#endif
