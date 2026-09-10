/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI
import Sessions
import OpenTelemetryApi

struct SettingsView: View {
  @State private var sessionData: [(String, String)] = []
  @State private var configData: [(String, String)] = []
  @State private var troubleshootingData: [(String, String)] = []
  @State private var showingToast = false
  @State private var showingHangPicker = false
  @State private var showingCrashPicker = false
  @State private var showingUserIdEditor = false
  @State private var showingTelemetryGenerator = false
  @State private var showingCpuTest = false
  @State private var showingMemoryTest = false
  @State private var timer: Timer?

  var body: some View {
    List {
      Section {
        HStack {
          Image(systemName: "info.circle")
            .foregroundColor(.blue)
            .font(.caption)
          Text("Blue fields")
            .foregroundColor(.blue)
            .font(.system(.caption, design: .monospaced, weight: .medium))
          Text("can be interacted with!")
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
      }

      Section("OTel Config") {
        ForEach(configData, id: \.0) { item in
          SettingsRow(title: item.0, value: item.1, isCopyable: true)
        }
      }

      Section("User Session") {
        ForEach(sessionData, id: \.0) { item in
          if item.0 == "User ID" {
            Button(action: {
              showingUserIdEditor = true
            }) {
              HStack {
                Text(item.0)
                  .font(.system(.caption, design: .monospaced, weight: .medium))
                  .foregroundColor(.primary)
                Spacer(minLength: 20)
                Text(item.1)
                  .font(.system(.caption, design: .monospaced))
                  .foregroundColor(.blue)
                  .multilineTextAlignment(.trailing)
                  .frame(maxWidth: 200, alignment: .trailing)
                  .lineLimit(nil)
                Image(systemName: "chevron.right")
                  .foregroundColor(.secondary)
                  .font(.caption)
              }
            }
            .help("Tap to edit user identifier")
          } else {
            SettingsRow(title: item.0, value: item.1, isCopyable: item.0 != "Session Expiry")
          }
        }
      }

      Section("Troubleshooting") {
        ForEach(troubleshootingData, id: \.0) { item in
          Button(action: {
            if item.0 == "Trigger App Hang" {
              showingHangPicker = true
            } else if item.0 == "Trigger App Crash" {
              showingCrashPicker = true
            } else if item.0 == "Load Test" {
              showingTelemetryGenerator = true
            } else if item.0 == "CPU Test" {
              showingCpuTest = true
            } else if item.0 == "Memory Test" {
              showingMemoryTest = true
            }
          }) {
            HStack {
              Text(item.0)
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundColor(.primary)
              Spacer(minLength: 20)
              Text(item.1)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.blue)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 200, alignment: .trailing)
                .lineLimit(nil)
              Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
            }
          }
          .help(item.0 == "Trigger App Hang" ? "Tap to configure app hang testing" : item.0 == "Trigger App Crash" ? "Tap to configure app crash testing" : item.0 == "Load Test" ? "Tap to run load test with custom logs and spans" : item.0 == "CPU Test" ? "Tap to run CPU intensive test with logging" : "Tap to run memory allocation test with logging")
        }
      }
    }
    .navigationTitle("Settings")
    .onAppear {
      loadSessionData()
      startTimer()
    }
    .onDisappear {
      timer?.invalidate()
      timer = nil
    }
    .sheet(isPresented: $showingHangPicker) {
      HangPickerView()
    }
    .sheet(isPresented: $showingCrashPicker) {
      CrashPickerView()
    }
    .sheet(isPresented: $showingUserIdEditor) {
      UserIdEditorView()
    }
    .sheet(isPresented: $showingTelemetryGenerator) {
      TelemetryGeneratorView()
    }
    .sheet(isPresented: $showingCpuTest) {
      CpuTestView()
    }
    .sheet(isPresented: $showingMemoryTest) {
      MemoryTestView()
    }
    .onChange(of: showingUserIdEditor) { isShowing in
      if !isShowing {
        loadSessionData()
      }
    }
    .overlay(
      ToastView(isShowing: $showingToast)
    )
  }

  private func loadSessionData() {
    configData = [
      ("Service Name", TelemetryConfig.serviceName),
      ("Logs Endpoint", TelemetryConfig.logsEndpoint.absoluteString),
      ("Traces Endpoint", TelemetryConfig.tracesEndpoint.absoluteString)
    ]

    troubleshootingData = [
      ("Trigger App Hang", "Tap to configure"),
      ("Trigger App Crash", "Tap to configure"),
      ("Load Test", "Tap to configure"),
      ("CPU Test", "Tap to configure"),
      ("Memory Test", "Tap to configure")
    ]

    guard let currentSession = SessionManagerProvider.getInstance().peekSession() else {
      sessionData = [
        ("User ID", "nil"),
        ("Previous Session", "nil"),
        ("Current Session", "nil"),
        ("Session Expiry", "nil")
      ]
      return
    }

    let expireTime = currentSession.expireTime
    let userId = UserIdStore.getUID()
    let timeToExpiry = expireTime.timeIntervalSinceNow
    let previousSessionId = SessionManagerProvider.getInstance().peekSession()?.previousId ?? "nil"

    sessionData = [
      ("User ID", userId),
      ("Previous Session", previousSessionId),
      ("Current Session", currentSession.id),
      ("Session Expiry", "\(Int(timeToExpiry)) seconds")
    ]
  }

  private func startTimer() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      updateExpiryTime()
    }
  }

  private func updateExpiryTime() {
    guard let currentSession = SessionManagerProvider.getInstance().peekSession() else {
      return
    }

    let expireTime = currentSession.expireTime
    let timeToExpiry = expireTime.timeIntervalSinceNow
    let expiryText = timeToExpiry <= 0 ? "Expired" : "\(Int(timeToExpiry)) seconds"

    if let index = sessionData.firstIndex(where: { $0.0 == "Session Expiry" }) {
      sessionData[index] = ("Session Expiry", expiryText)
    }
  }
}

struct UserIdEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var userId: String = ""
  @State private var showingToast = false

  var body: some View {
    NavigationView {
      VStack(spacing: 24) {
        VStack(spacing: 8) {
          Text("Edit User ID")
            .font(.system(.headline, design: .monospaced, weight: .medium))

          Text("Enter a custom user ID")
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.secondary)
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)

        TextField("User ID", text: $userId)
          .font(.system(.body, design: .monospaced))
          .textFieldStyle(.roundedBorder)
          .autocorrectionDisabled()
          .textInputAutocapitalization(.never)
          .padding(.horizontal, 16)

        HStack(spacing: 16) {
          Button("Clear") {
            userId = ""
          }
          .foregroundColor(.white)
          .padding(.horizontal, 24)
          .padding(.vertical, 12)
          .background(Color.gray)
          .cornerRadius(8)

          Button("Save") {
            UserIdStore.setUID(userId)
            showingToast = true
            dismiss()
          }
          .foregroundColor(.white)
          .padding(.horizontal, 24)
          .padding(.vertical, 12)
          .background(userId.isEmpty ? Color.gray : Color.blue)
          .cornerRadius(8)
          .disabled(userId.isEmpty)
        }

        Spacer()
      }
      .padding(.horizontal, 16)
      .navigationTitle("Edit User ID")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
      }
      .onAppear {
        userId = UserIdStore.getUID()
      }
    }
    .overlay(
      ToastView(isShowing: $showingToast)
    )
  }
}

struct SettingsRow: View {
  let title: String
  let value: String
  let isCopyable: Bool
  @State private var showingToast = false

  var body: some View {
    Button(action: {
      if isCopyable {
        UIPasteboard.general.string = value
        showingToast = true
      }
    }) {
      HStack {
        Text(title)
          .font(.system(.caption, design: .monospaced, weight: .medium))
          .foregroundColor(.primary)
        Spacer(minLength: 20)
        Text(value
          .replacingOccurrences(of: "-", with: "\u{2011}")
          .replacingOccurrences(of: "/", with: "\u{2044}")
          .replacingOccurrences(of: ":", with: "\u{2236}")
          .replacingOccurrences(of: ".", with: "\u{2024}"))
          .font(.system(.caption, design: .monospaced))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.trailing)
          .frame(maxWidth: 200, alignment: .trailing)
          .lineLimit(nil)
      }
    }
    .disabled(!isCopyable)
    .overlay(
      ToastView(isShowing: $showingToast)
    )
  }
}

struct ToastView: View {
  @Binding var isShowing: Bool

  var body: some View {
    if isShowing {
      VStack {
        Spacer()
        Text("Copied to Clipboard")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.white)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(Color.black.opacity(0.8))
          .cornerRadius(8)
          .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
              isShowing = false
            }
          }
          .padding(.bottom, 20)
      }
      .transition(.opacity)
      .animation(.easeInOut(duration: 0.3), value: isShowing)
    }
  }
}

struct TelemetryToastView: View {
  @Binding var isShowing: Bool

  var body: some View {
    if isShowing {
      VStack {
        Spacer()
        Text("Telemetry Generated")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.white)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(Color.green.opacity(0.8))
          .cornerRadius(8)
          .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
              isShowing = false
            }
          }
          .padding(.bottom, 20)
      }
      .transition(.opacity)
      .animation(.easeInOut(duration: 0.3), value: isShowing)
    }
  }
}

struct HangPickerView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var selectedHangType: HangType = .threadSleep
  @State private var seconds: Int = 1
  @State private var centiseconds: Int = 0

  var selectedDuration: TimeInterval {
    TimeInterval(seconds) + TimeInterval(centiseconds) / 100.0
  }

  var body: some View {
    // TODO: no SwiftUI view instrumentation for HangPickerView
    NavigationView {
      VStack {
        Text("Select hang type and duration")
          .font(.system(.headline, design: .monospaced, weight: .medium))
          .padding()

        Text("Note: Only hangs longer than 250ms are collected")
          .font(.system(.caption, design: .monospaced))
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.horizontal, 20)
          .padding(.vertical, 8)

        HStack(spacing: 0) {
          Picker("Hang Type", selection: $selectedHangType) {
            ForEach(HangType.allCases, id: \.self) { type in
              HStack {
                Text(type.displayName)
                  .font(.system(.caption, design: .monospaced))
                  .lineLimit(nil)
                Spacer()
              }
              .tag(type)
            }
          }
          .pickerStyle(.wheel)
          .frame(maxWidth: 180)

          Picker("Seconds", selection: $seconds) {
            ForEach(0 ..< 60, id: \.self) { sec in
              Text("\(sec)")
                .font(.system(.caption, design: .monospaced))
                .tag(sec)
            }
          }
          .pickerStyle(.wheel)
          .frame(maxWidth: 80)

          Picker("Centiseconds", selection: $centiseconds) {
            ForEach(0 ..< 100, id: \.self) { cs in
              Text(String(format: ".%02d", cs))
                .font(.system(.caption, design: .monospaced))
                .tag(cs)
            }
          }
          .pickerStyle(.wheel)
          .frame(maxWidth: 60)
        }
        .padding()

        Button("Trigger Hang") {
          triggerAppHang(type: selectedHangType, duration: selectedDuration)
          dismiss()
        }
        .foregroundColor(.white)
        .padding()
        .background(Color.red)
        .cornerRadius(8)
        .padding()

        Spacer()
      }
      .navigationTitle("Trigger App Hang")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
      }
    }
  }

  private func triggerAppHang(type: HangType, duration: TimeInterval) {
    let durationText = String(format: "%.2fs", duration)

    showCountdownToast(durationText: durationText, type: type, duration: duration)
  }

  private func showCountdownToast(durationText: String, type: HangType, duration: TimeInterval) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else { return }

    let toast = createToast(text: "Hang Starting in 3...", in: window)

    var countdown = 3
    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
      countdown -= 1
      if countdown > 0 {
        toast.text = "Hang Starting in \(countdown)..."
      } else {
        timer.invalidate()
        toast.text = "\(type.displayName) for \(durationText)"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          let start = Date()

          switch type {
          case .threadSleep:
            Thread.sleep(forTimeInterval: duration)
          case .syncNetworkCall:
            performSyncNetworkCall(duration: duration)
          case .cpuIntensiveTask:
            performCpuIntensiveTask(duration: duration)
          }

          let end = Date()
          let span = OpenTelemetry.instance.tracerProvider.get(instrumentationName: debugScope)
            .spanBuilder(spanName: "[DEBUG] Triggered Hang - \(type.displayName)")
            .setStartTime(time: start)
            .startSpan()
          span.end(time: end)

          toast.text = "Hang Completed!"

          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            toast.removeFromSuperview()
          }
        }
      }
    }
  }

  private func createToast(text: String, in window: UIWindow) -> UILabel {
    let toast = UILabel()
    toast.text = text
    toast.font = .systemFont(ofSize: 16, weight: .medium)
    toast.textColor = .white
    toast.backgroundColor = .systemRed.withAlphaComponent(0.9)
    toast.textAlignment = .center
    toast.layer.cornerRadius = 8
    toast.clipsToBounds = true
    toast.translatesAutoresizingMaskIntoConstraints = false

    window.addSubview(toast)
    NSLayoutConstraint.activate([
      toast.centerXAnchor.constraint(equalTo: window.centerXAnchor),
      toast.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 20),
      toast.widthAnchor.constraint(equalToConstant: 200),
      toast.heightAnchor.constraint(equalToConstant: 40)
    ])

    return toast
  }

  private func performSyncNetworkCall(duration: TimeInterval) {
    let semaphore = DispatchSemaphore(value: 0)
    let url = URL(string: "https://httpbin.org/delay/\(Int(duration))")!

    let task = URLSession.shared.dataTask(with: url) { _, _, _ in
      semaphore.signal()
    }
    task.resume()
    semaphore.wait()
  }

  private func performCpuIntensiveTask(duration: TimeInterval) {
    let endTime = Date().addingTimeInterval(duration)
    var counter = 0

    while Date() < endTime {
      for i in 0 ..< 100000 {
        counter += i * i
      }
    }
  }
}

enum CrashType: CaseIterable {
  case forceUnwrap
  case indexOutOfBounds
  case fatalError
  case divideByZero
  case stackOverflow

  var displayName: String {
    switch self {
    case .indexOutOfBounds: return "Index Out of Bounds"
    case .fatalError: return "Fatal Error"
    case .forceUnwrap: return "Force Unwrap Nil"
    case .divideByZero: return "Divide by Zero"
    case .stackOverflow: return "Stack Overflow"
    }
  }
}

struct CrashPickerView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var selectedCrashType: CrashType = .forceUnwrap

  var body: some View {
    // TODO: no SwiftUI view instrumentation for CrashPickerView
    NavigationView {
      VStack {
        Text("Select crash type")
          .font(.system(.headline, design: .monospaced, weight: .medium))
          .padding()

        Text("Warning: application will force exit after countdown")
          .font(.system(.caption, design: .monospaced))
          .foregroundColor(.red)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.horizontal, 20)
          .padding(.vertical, 8)

        Picker("Crash Type", selection: $selectedCrashType) {
          ForEach(CrashType.allCases, id: \.self) { type in
            Text(type.displayName)
              .font(.system(.caption, design: .monospaced))
              .lineLimit(nil)
              .tag(type)
          }
        }
        .pickerStyle(.wheel)
        .padding(.horizontal, 16)

        Button("Trigger Crash") {
          triggerCrash(type: selectedCrashType)
          dismiss()
        }
        .foregroundColor(.white)
        .padding()
        .background(Color.red)
        .cornerRadius(8)
        .padding()

        Spacer()
      }
      .navigationTitle("Trigger App Crash")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
      }
    }
  }

  private func triggerCrash(type: CrashType) {
    let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: debugScope)
    let delay: TimeInterval = 5
    logger.logRecordBuilder()
      .setEventName("[DEBUG] Triggered a \(type.displayName) crash")
      .setTimestamp(Date().addingTimeInterval(delay))
      .emit()

    showCrashCountdownToast(type: type, delay: delay)
  }

  private func showCrashCountdownToast(type: CrashType, delay: TimeInterval) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else { return }

    var countdown = Int(delay)
    let toast = createToast(text: "Crash Starting in \(countdown)...", in: window)

    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
      countdown -= 1
      if countdown > 0 {
        toast.text = "Crash Starting in \(countdown)..."
      } else {
        timer.invalidate()
        toast.text = "Triggering \(type.displayName)"

        // Log the crash event before it happens

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          switch type {
          case .indexOutOfBounds:
            let array = [1, 2, 3]
            _ = array[10] // Index out of bounds
          case .fatalError:
            fatalError("Intentional crash for testing")
          case .forceUnwrap:
            let nilValue: String? = nil
            _ = nilValue! // Force unwrap nil
          case .divideByZero:
            let zero = Int.random(in: 0 ... 0) // Runtime zero
            _ = 42 / zero // Division by zero
          case .stackOverflow:
            func recursiveFunction() {
              recursiveFunction() // Infinite recursion
            }
            recursiveFunction()
          }
        }
      }
    }
  }

  private func createToast(text: String, in window: UIWindow) -> UILabel {
    let toast = UILabel()
    toast.text = text
    toast.font = .systemFont(ofSize: 16, weight: .medium)
    toast.textColor = .white
    toast.backgroundColor = .systemRed.withAlphaComponent(0.9)
    toast.textAlignment = .center
    toast.layer.cornerRadius = 8
    toast.clipsToBounds = true
    toast.translatesAutoresizingMaskIntoConstraints = false

    window.addSubview(toast)
    NSLayoutConstraint.activate([
      toast.centerXAnchor.constraint(equalTo: window.centerXAnchor),
      toast.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 20),
      toast.widthAnchor.constraint(equalToConstant: 200),
      toast.heightAnchor.constraint(equalToConstant: 40)
    ])

    return toast
  }
}

struct TelemetryGeneratorView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var logCount: Int = 500
  @State private var spanCount: Int = 500
  @State private var eventSizeKB: Int = 1
  @State private var isGenerating = false
  @State private var showingToast = false
  @State private var totalLogsSent: Int = 0
  @State private var totalSpansSent: Int = 0
  @State private var sessionId: String = "nil"
  @State private var sessionExpiry: String = "nil"
  @State private var timer: Timer?
  @State private var currentSessionId: String = "nil"
  @State private var batchHistory: [(id: String, fullId: String, type: String, count: Int, sessionId: String, fullSessionId: String, eventSizeKB: Int)] = []
  @State private var showingCopyToast = false

  var body: some View {
    // TODO: no SwiftUI view instrumentation for TelemetryGeneratorView
    NavigationView {
      VStack(spacing: 20) {
        // Session Info
        VStack(spacing: 8) {
          Text("SESSION INFO")
            .font(.system(.caption, design: .monospaced, weight: .bold))
            .foregroundColor(.secondary)

          VStack(spacing: 4) {
            HStack {
              Text("ID:")
                .font(.system(.caption2, design: .monospaced, weight: .medium))
                .foregroundColor(.secondary)
              Spacer()
              Text(sessionId)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            }

            HStack {
              Text("EXPIRES:")
                .font(.system(.caption2, design: .monospaced, weight: .medium))
                .foregroundColor(.secondary)
              Spacer()
              Text(sessionExpiry)
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundColor(sessionExpiry.contains("Expired") ? .red : .orange)
            }
          }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)

        // Batch History Section
        VStack(spacing: 8) {
          Text("BATCH HISTORY")
            .font(.system(.caption, design: .monospaced, weight: .bold))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

          VStack(spacing: 0) {
            // Column Headers
            HStack {
              Text("SESSION")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
              Text("BATCH ID")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
              Text("TYPE")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .center)
              Text("SIZE")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 35, alignment: .center)
              Text("COUNT")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray5))

            ScrollView {
              if batchHistory.isEmpty {
                VStack(spacing: 8) {
                  Text("No batches sent yet")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                  Text("Batches will appear here after sending telemetry")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
              } else {
                LazyVStack(spacing: 4) {
                  ForEach(batchHistory.reversed(), id: \.id) { batch in
                    HStack {
                      Button(batch.sessionId) {
                        UIPasteboard.general.string = batch.fullSessionId
                        showingCopyToast = true
                      }
                      .font(.system(.caption2, design: .monospaced, weight: .medium))
                      .foregroundColor(.blue)
                      .frame(width: 60, alignment: .leading)

                      Button(batch.id) {
                        UIPasteboard.general.string = batch.fullId
                        showingCopyToast = true
                      }
                      .font(.system(.caption2, design: .monospaced, weight: .medium))
                      .foregroundColor(.blue)
                      .frame(maxWidth: .infinity, alignment: .leading)

                      Text(batch.type.uppercased())
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundColor(batch.type == "logs" ? .blue : .green)
                        .frame(width: 40, alignment: .center)
                      Text("\(batch.eventSizeKB)KB")
                        .font(.system(.caption2, design: .monospaced, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .center)
                      Text("\(batch.count)")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundColor(batch.type == "logs" ? .blue : .green)
                        .frame(width: 40, alignment: .trailing)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                  }
                }
              }
            }
            .frame(maxHeight: 96)
          }
          .background(Color(.systemGray6))
          .cornerRadius(6)
        }
        .padding(.horizontal)

        // Generator Section
        VStack(spacing: 12) {
          Text("GENERATOR")
            .font(.system(.caption, design: .monospaced, weight: .bold))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

          HStack {
            Text("Logs:")
              .font(.system(.body, design: .monospaced, weight: .medium))
            Spacer()
            Stepper(value: $logCount, in: 100 ... 10000, step: 100) {
              Text("\(logCount)")
                .font(.system(.body, design: .monospaced))
            }
          }

          HStack {
            Text("Spans:")
              .font(.system(.body, design: .monospaced, weight: .medium))
            Spacer()
            Stepper(value: $spanCount, in: 100 ... 10000, step: 100) {
              Text("\(spanCount)")
                .font(.system(.body, design: .monospaced))
            }
          }

          HStack {
            Text("Event Size:")
              .font(.system(.body, design: .monospaced, weight: .medium))
            Spacer()
            Stepper(value: $eventSizeKB, in: 1 ... 30, step: 1) {
              Text("\(eventSizeKB) KB")
                .font(.system(.body, design: .monospaced))
            }
          }
        }
        .padding(.horizontal)

        Button("Send telemetry") {
          sendBoth()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(isGenerating ? Color.gray : Color.blue)
        .cornerRadius(8)
        .disabled(isGenerating)

        Spacer()
      }
      .padding(.horizontal, 16)
      .navigationTitle("Load Test")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
      }
      .onAppear {
        loadSessionData()
        startTimer()
      }
      .onDisappear {
        timer?.invalidate()
        timer = nil
      }
    }
    .overlay(
      TelemetryToastView(isShowing: $showingToast)
    )
    .overlay(
      ToastView(isShowing: $showingCopyToast)
    )
  }

  private func sendLogs() {
    isGenerating = true
    let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: debugScope)
    let fullLogsBatchId = UUID().uuidString
    let logsBatchId = String(fullLogsBatchId.prefix(8))
    let paddingData = String(repeating: "x", count: eventSizeKB * 1024)

    for i in 1 ... logCount {
      logger.logRecordBuilder()
        .setEventName("Generated Log \(i) of \(logCount)")
        .setTimestamp(Date())
        .setAttributes([
          "batch.id": AttributeValue.string(fullLogsBatchId),
          "batch.intended_size": AttributeValue.int(logCount),
          "batch.type": AttributeValue.string("logs"),
          "event.size_kb": AttributeValue.int(eventSizeKB),
          "padding_data": AttributeValue.string(paddingData)
        ])
        .emit()
    }
    totalLogsSent += logCount

    let truncatedSessionId = String(sessionId.prefix(8))
    batchHistory.append((id: logsBatchId, fullId: fullLogsBatchId, type: "logs", count: logCount, sessionId: truncatedSessionId, fullSessionId: sessionId, eventSizeKB: eventSizeKB))

    isGenerating = false
    showingToast = true
  }

  private func sendSpans() {
    isGenerating = true
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: debugScope)
    let fullSpansBatchId = UUID().uuidString
    let spansBatchId = String(fullSpansBatchId.prefix(8))
    let paddingData = String(repeating: "x", count: eventSizeKB * 1024)

    for i in 1 ... spanCount {
      let span = tracer.spanBuilder(spanName: "Generated Span \(i) of \(spanCount)")
        .startSpan()
      span.setAttribute(key: "batch.id", value: fullSpansBatchId)
      span.setAttribute(key: "batch.intended_size", value: spanCount)
      span.setAttribute(key: "batch.type", value: "spans")
      span.setAttribute(key: "event.size_kb", value: eventSizeKB)
      span.setAttribute(key: "padding_data", value: paddingData)
      span.end()
    }
    totalSpansSent += spanCount

    let truncatedSessionId = String(sessionId.prefix(8))
    batchHistory.append((id: spansBatchId, fullId: fullSpansBatchId, type: "spans", count: spanCount, sessionId: truncatedSessionId, fullSessionId: sessionId, eventSizeKB: eventSizeKB))

    isGenerating = false
    showingToast = true
  }

  private func sendBoth() {
    sendLogs()
    sendSpans()
  }

  private func loadSessionData() {
    guard let currentSession = SessionManagerProvider.getInstance().peekSession() else {
      sessionId = "nil"
      sessionExpiry = "nil"
      return
    }

    // Reset counters if session changed
    if currentSessionId != currentSession.id {
      totalLogsSent = 0
      totalSpansSent = 0
      currentSessionId = currentSession.id
    }

    sessionId = currentSession.id
    updateExpiryTime()
  }

  private func startTimer() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      updateExpiryTime()
    }
  }

  private func updateExpiryTime() {
    guard let currentSession = SessionManagerProvider.getInstance().peekSession() else {
      sessionExpiry = "nil"
      return
    }

    // Reset counters if session changed
    if currentSessionId != currentSession.id {
      totalLogsSent = 0
      totalSpansSent = 0
      currentSessionId = currentSession.id
      sessionId = currentSession.id
    }

    let expireTime = currentSession.expireTime
    let timeToExpiry = expireTime.timeIntervalSinceNow
    sessionExpiry = timeToExpiry <= 0 ? "Expired" : "\(Int(timeToExpiry))s"
  }
}

struct CpuTestView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var isRunning = false
  @State private var duration: Int = 30
  @State private var cpuTimer: Timer?
  @State private var logTimer: Timer?
  @State private var startTime: Date?
  @State private var cpuIntensity: Double = 0.0

  var body: some View {
    // TODO: no SwiftUI view instrumentation for CpuTestView
    NavigationView {
      VStack(spacing: 20) {
        Text("CPU Load Test")
          .font(.system(.headline, design: .monospaced, weight: .medium))
          .padding()

        Text("Gradually increases CPU utilization over time")
          .font(.system(.caption, design: .monospaced))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal)

        VStack(spacing: 12) {
          HStack {
            Text("Duration:")
              .font(.system(.body, design: .monospaced, weight: .medium))
            Spacer()
            Stepper(value: $duration, in: 10 ... 300, step: 10) {
              Text("\(duration)s")
                .font(.system(.body, design: .monospaced))
            }
          }

          if isRunning {
            VStack(spacing: 8) {
              Text("CPU Usage: \(Int(cpuIntensity * 100))%")
                .font(.system(.body, design: .monospaced, weight: .medium))
                .foregroundColor(.orange)

              ProgressView(value: cpuIntensity)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
            }
          }
        }
        .padding(.horizontal)

        Button(isRunning ? "Stop Test" : "Start CPU Test") {
          if isRunning {
            stopCpuTest()
          } else {
            startCpuTest()
          }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(isRunning ? Color.red : Color.orange)
        .cornerRadius(8)

        Spacer()
      }
      .padding(.horizontal, 16)
      .navigationTitle("CPU Test")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            stopCpuTest()
            dismiss()
          }
        }
      }
      .onDisappear {
        stopCpuTest()
      }
    }
  }

  private func startCpuTest() {
    isRunning = true
    startTime = Date()
    cpuIntensity = 0.0

    let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: debugScope)

    // Log once per second
    logTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      guard let start = startTime else { return }
      let elapsed = Date().timeIntervalSince(start)

      logger.logRecordBuilder()
        .setEventName("CPU Test Progress \(String(format: "%.1f", elapsed))/\(duration)s")
        .setTimestamp(Date())
        .setAttributes([
          "test.type": AttributeValue.string("cpu_load"),
          "test.elapsed_seconds": AttributeValue.double(elapsed),
          "test.duration_seconds": AttributeValue.int(duration),
          "test.cpu_intensity": AttributeValue.double((cpuIntensity * 100).rounded() / 100),
          "test.progress_percent": AttributeValue.double((elapsed / Double(duration)) * 100)
        ])
        .emit()
    }

    // CPU intensive work with increasing intensity
    cpuTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
      guard let start = startTime else { return }
      let elapsed = Date().timeIntervalSince(start)

      if elapsed >= Double(duration) {
        stopCpuTest()
        return
      }

      // Gradually increase CPU intensity over time (targeting 100% max)
      cpuIntensity = min(elapsed / Double(duration), 1.0)

      // Create sustained CPU load on multiple threads
      let threadCount = max(1, min(Int(cpuIntensity * 8), 8))
      for _ in 0 ..< threadCount {
        DispatchQueue.global(qos: .userInitiated).async {
          // Continuous work without pauses for higher CPU usage
          let endTime = Date().addingTimeInterval(0.09)
          var counter = 0
          while Date() < endTime {
            // More intensive mathematical operations
            for i in 0 ..< 5000 {
              counter += i * i * i + i * i + i
            }
          }
        }
      }
    }
  }

  private func stopCpuTest() {
    isRunning = false
    cpuTimer?.invalidate()
    logTimer?.invalidate()
    cpuTimer = nil
    logTimer = nil

    if let start = startTime {
      let elapsed = Date().timeIntervalSince(start)
      let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: debugScope)

      logger.logRecordBuilder()
        .setEventName("CPU Test Completed")
        .setTimestamp(Date())
        .setAttributes([
          "test.type": AttributeValue.string("cpu_load"),
          "test.total_duration": AttributeValue.double(elapsed),
          "test.max_intensity": AttributeValue.double((cpuIntensity * 100).rounded() / 100)
        ])
        .emit()
    }

    startTime = nil
    cpuIntensity = 0.0
  }
}

struct MemoryTestView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var isRunning = false
  @State private var duration: Int = 30
  @State private var memoryTimer: Timer?
  @State private var logTimer: Timer?
  @State private var startTime: Date?
  @State private var memoryIntensity: Double = 0.0
  @State private var allocatedMemory: [Data] = []

  var body: some View {
    // TODO: no SwiftUI view instrumentation for MemoryTestView
    NavigationView {
      VStack(spacing: 20) {
        Text("Memory Load Test")
          .font(.system(.headline, design: .monospaced, weight: .medium))
          .padding()

        Text("Gradually increases memory allocation over time")
          .font(.system(.caption, design: .monospaced))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal)

        VStack(spacing: 12) {
          HStack {
            Text("Duration:")
              .font(.system(.body, design: .monospaced, weight: .medium))
            Spacer()
            Stepper(value: $duration, in: 10 ... 300, step: 10) {
              Text("\(duration)s")
                .font(.system(.body, design: .monospaced))
            }
          }

          if isRunning {
            VStack(spacing: 8) {
              Text("Memory Allocated: \(Int(memoryIntensity * 50))MB")
                .font(.system(.body, design: .monospaced, weight: .medium))
                .foregroundColor(.blue)

              ProgressView(value: memoryIntensity)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
          }
        }
        .padding(.horizontal)

        Button(isRunning ? "Stop Test" : "Start Memory Test") {
          if isRunning {
            stopMemoryTest()
          } else {
            startMemoryTest()
          }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(isRunning ? Color.red : Color.blue)
        .cornerRadius(8)

        Spacer()
      }
      .padding(.horizontal, 16)
      .navigationTitle("Memory Test")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            stopMemoryTest()
            dismiss()
          }
        }
      }
      .onDisappear {
        stopMemoryTest()
      }
    }
  }

  private func startMemoryTest() {
    isRunning = true
    startTime = Date()
    memoryIntensity = 0.0
    allocatedMemory = []

    let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: debugScope)

    // Log once per second
    logTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
      guard let start = startTime else { return }
      let elapsed = Date().timeIntervalSince(start)

      logger.logRecordBuilder()
        .setEventName("Memory Test Progress \(String(format: "%.1f", elapsed))/\(duration)s")
        .setTimestamp(Date())
        .setAttributes([
          "test.type": AttributeValue.string("memory_load"),
          "test.elapsed_seconds": AttributeValue.double(elapsed),
          "test.duration_seconds": AttributeValue.int(duration),
          "test.memory_allocated_mb": AttributeValue.double(memoryIntensity * 50),
          "test.progress_percent": AttributeValue.double((elapsed / Double(duration)) * 100)
        ])
        .emit()
    }

    // Memory allocation with increasing intensity
    memoryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      guard let start = startTime else { return }
      let elapsed = Date().timeIntervalSince(start)

      if elapsed >= Double(duration) {
        stopMemoryTest()
        return
      }

      // Gradually increase memory allocation over time (up to 50MB for safety)
      memoryIntensity = min(elapsed / Double(duration), 1.0)

      // Allocate memory in 1MB chunks and actually use it to force RSS allocation
      let chunkSize = 1024 * 1024 // 1MB
      let targetChunks = Int(memoryIntensity * 50) // Up to 50 chunks (50MB)

      while allocatedMemory.count < targetChunks {
        var chunk = Data(count: chunkSize)
        // Actually write to the memory to force physical allocation
        chunk.withUnsafeMutableBytes { bytes in
          let buffer = bytes.bindMemory(to: UInt8.self)
          for i in stride(from: 0, to: chunkSize, by: 4096) { // Write every 4KB page
            buffer[i] = UInt8(i % 256)
          }
        }
        allocatedMemory.append(chunk)
      }
    }
  }

  private func stopMemoryTest() {
    isRunning = false
    memoryTimer?.invalidate()
    logTimer?.invalidate()
    memoryTimer = nil
    logTimer = nil

    if let start = startTime {
      let elapsed = Date().timeIntervalSince(start)
      let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: debugScope)

      logger.logRecordBuilder()
        .setEventName("Memory Test Completed")
        .setTimestamp(Date())
        .setAttributes([
          "test.type": AttributeValue.string("memory_load"),
          "test.total_duration": AttributeValue.double(elapsed),
          "test.max_memory_allocated_mb": AttributeValue.double(memoryIntensity * 50)
        ])
        .emit()
    }

    // Release allocated memory
    allocatedMemory.removeAll()
    startTime = nil
    memoryIntensity = 0.0
  }
}
