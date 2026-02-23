import SwiftUI
import CoreWLAN

struct MainView : View {
    @State private var logViewModel = LogViewModel()
    @State private var basicNetViewModel = BasicNetViewModel()
    @State private var wiFiViewModel = WiFiViewModel()
    @State private var pingViewModel = PingViewModel()
    @State private var pollIntervalSeconds: Int = 3
    @State private var pollTask: Task<Void, Never>?
    
    // Last Updated State
    @State private var lastUpdatedAt: Date? = nil
    
    private var isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        
        formatter.formatOptions = [
            .withInternetDateTime,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime
        ]
        return formatter
    }()
    
    private let pingTargets = ["1.1.1.1", "8.8.8.8"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerView
                .padding()
                .background(.background)
            
            Divider()
            
            ScrollView {
                // Using .flexible with a min/max prevents the "cramping" that causes overlaps
                let columns = [
                    GridItem(.adaptive(minimum: 350, maximum: .infinity), spacing: 20, alignment: .top)
                ]
                
                LazyVGrid(columns: columns, spacing: 20) {
                    Group {
                        BasicNetView(viewModel: basicNetViewModel)
                        WiFiView(viewModel: wiFiViewModel)
                        PingView(viewModel: pingViewModel)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    
                    // Tools and Logs usually need more horizontal space or consistent height
                    ExternalToolsView(logViewModel: logViewModel)
                    LogView(logViewModel: logViewModel)
                }
                .padding()
            }
        }
        .task {
            startPolling()
        }
        .onChange(of: pollIntervalSeconds) { _, _ in
            startPolling()
        }
        .onDisappear {
            pollTask?.cancel()
        }
    }
    
    private var headerView: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MacNetTools")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Group {
                    if let lastUpdate = lastUpdatedAt {
                        Text("Last updated: \(isoFormatter.string(from: lastUpdate))")
                    } else {
                        Text("Refreshing...")
                    }
                }
                .font(.custom(kMonoFontName, size: 10))
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Text("Poll Interval:")
                    .font(.subheadline)
                
                HStack(spacing: 8) {
                    Button { updatePollInterval(by: -1) } label: { Image(systemName: "minus.circle") }
                    Text("\(pollIntervalSeconds)s")
                        .font(.system(.subheadline, design: .monospaced))
                        .frame(width: 30)
                    Button { updatePollInterval(by: 1) } label: { Image(systemName: "plus.circle") }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    @MainActor
    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                await refreshData()
                try? await Task.sleep(for: .seconds(Double(pollIntervalSeconds)))
            }
        }
    }
    
    @MainActor
    private func refreshData() async {
        async let basicUpdate: Void = refreshBasicNet()
        async let wifiUpdate: Void = refreshWiFi()
        async let pingUpdate: Void = refreshPings()
        
        _ = await (basicUpdate, wifiUpdate, pingUpdate)
        
        lastUpdatedAt = Date()
    }
    
    @MainActor
    private func refreshBasicNet() async {
        let previous = basicNetViewModel.basicNetModel
        let updated = await basicNetViewModel.updateBasicNet()
        
        guard let updated else {
            if previous != nil {
                logViewModel.append("Network data unavailable")
            }
            return
        }
        
        logChange(label: "Local IP", old: previous?.localIp, new: updated.localIp)
        logChange(label: "Subnet Mask", old: previous?.subnetMask, new: updated.subnetMask)
        logChange(label: "Router", old: previous?.routerIp, new: updated.routerIp)
        logChange(label: "MTU", old: previous?.mtu, new: updated.mtu)
        logChange(label: "Public IPv4", old: previous?.publicIpV4, new: updated.publicIpV4)
        logChange(label: "Public IPv6", old: previous?.publicIpV6, new: updated.publicIpV6)
    }
    
    @MainActor
    private func refreshWiFi() async {
        let previous = wiFiViewModel.wiFiModel
        let updated = wiFiViewModel.updateWiFi()
        
        guard let updated else {
            if previous != nil {
                logViewModel.append("WiFi data unavailable")
            }
            return
        }
        
        logChange(label: "SSID", old: previous?.ssid, new: updated.ssid)
        logChange(label: "BSSID", old: previous?.connectedBssid, new: updated.connectedBssid)
        logChange(label: "Interface", old: previous?.interfaceName, new: updated.interfaceName ?? kUnknown)
        logChange(label: "Channel", old: previous?.channel?.channelNumber.description, new: updated.channel.map { "\($0.channelNumber)" } ?? kUnknown)
        logChange(label: "Security", old: previous.map { String(describing: $0.security) }, new: String(describing: updated.security))
        logChange(label: "RSSI", old: previous?.rssi.description, new: updated.rssi.description)
        logChange(label: "Noise", old: previous?.noise.description, new: updated.noise.description)
        logChange(label: "SNR", old: previous?.signalNoiseRatio.description, new: updated.signalNoiseRatio.description)
        logChange(label: "TX Rate", old: previous.map { Int($0.txRateMbps).description }, new: Int(updated.txRateMbps).description)
        logChange(label: "Country", old: previous?.countryCode, new: updated.countryCode)
    }
    
    @MainActor
    private func refreshPings() async {
        var targets: [(display: String, host: String)] = pingTargets.map { ($0, $0) }
        if let router = basicNetViewModel.basicNetModel?.routerIp, router != "0.0.0.0" {
            targets.append(("Router (\(router))", router))
        }
        
        // Run pings in parallel for even faster updates
        await withTaskGroup(of: Void.self) { group in
            for target in targets {
                group.addTask {
                    let result = await pingViewModel.runPing(target: target.host)
                    await pingViewModel.addPing(target: target.display, status: result.status)
                }
            }
        }
    }
    
    @MainActor
    private func logChange(label: String, old: String?, new: String) {
        guard old != new else { return }
        if let old {
            logViewModel.append("\(label): changed from \"\(old)\" to \"\(new)\"")
        }
    }
    
    private func updatePollInterval(by delta: Int) {
        pollIntervalSeconds = max(1, pollIntervalSeconds + delta)
    }
}

#Preview {
    MainView()
}
