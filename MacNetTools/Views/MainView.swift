import SwiftUI
import CoreWLAN

struct MainView : View {
    @State private var logViewModel = LogViewModel()
    @State private var basicNetViewModel = BasicNetViewModel()
    @State private var wiFiViewModel = WiFiViewModel()
    @State private var pingViewModel = PingViewModel()
    @State private var pollIntervalSeconds: Int = 3
    @State private var pollTask: Task<Void, Never>?
    
    private let pingTargets = ["1.1.1.1", "8.8.8.8"]
    
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    HStack {
                        Text("MacNetTools")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Spacer()
                        HStack(spacing: 8) {
                            Text("Poll:")
                            Button {
                                updatePollInterval(by: -1)
                            } label: { Image(systemName: "minus.circle") }
                            Text("\(pollIntervalSeconds)s")
                                .font(.custom(kMonoFontName, size: 12))
                                .frame(minWidth: 32)
                            Button {
                                updatePollInterval(by: 1)
                            } label: { Image(systemName: "plus.circle") }
                        }
                    }
                    
                    let columns = [GridItem(.adaptive(minimum: 320), spacing: 16, alignment: .top)]
                    
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        BasicNetView(viewModel: basicNetViewModel)
                        WiFiView(viewModel: wiFiViewModel)
                        PingView(viewModel: pingViewModel)
                        ExternalToolsView(logViewModel: logViewModel)
                        LogView(logViewModel: logViewModel)
                    }
                    .frame(minWidth: proxy.size.width * 0.95)
                }
                .padding(16)
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
    
    @MainActor
    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor in
            while !Task.isCancelled {
                await refreshData()
                try? await Task.sleep(for: .seconds(Double(pollIntervalSeconds)))
            }
        }
    }
    
    @MainActor
    private func refreshData() async {
        await refreshBasicNet()
        await refreshWiFi()
        await refreshPings()
    }
    
    @MainActor
    private func refreshBasicNet() async {
        let previous = basicNetViewModel.basicNetModel
        let updated = basicNetViewModel.updateBasicNet()
        
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
        
        for target in targets {
            let result = await pingViewModel.runPing(target: target.host)
            await MainActor.run {
                pingViewModel.addPing(target: target.display, status: result.status)
            }
        }
    }
    
    @MainActor
    private func logChange(label: String, old: String?, new: String) {
        guard old != new else { return }
        if let old {
            logViewModel.append("\(label): changed from \"\(old)\" to \"\(new)\"")
        } else {
            logViewModel.append("\(label): set to \"\(new)\"")
        }
    }
    
    private func updatePollInterval(by delta: Int) {
        pollIntervalSeconds = max(1, pollIntervalSeconds + delta)
    }
}

#Preview {
    MainView()
}
