import SwiftUI

struct PingView : View {
    @State private var viewModel = PingViewModel()
    @State private var target = "8.8.8.8"
    var logViewModel: LogViewModel?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pings")
                .font(.headline)
            
            TextField("Host or IP", text: $target)
                .textFieldStyle(.roundedBorder)
            
            Button {
                runPing()
            } label: {
                Label("Ping", systemImage: "paperplane")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Divider()
            
            if viewModel.pings.isEmpty {
                ContentUnavailableView("No ping data", systemImage: "waveform.path.ecg")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.pings) { ping in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ping.target)
                                    .fontWeight(.bold)
                                Text(ping.status)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 280, maxWidth: .infinity, maxHeight: 450)
    }
    
    private func runPing() {
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        Task {
            let result = await viewModel.runPing(target: trimmed)
            
            await MainActor.run {
                viewModel.addPing(target: trimmed, status: result.status)
                logViewModel?.append("Ping \(trimmed): \(result.status)")
                result.logLines.forEach { line in
                    logViewModel?.append(line)
                }
            }
        }
    }
}

#Preview {
    PingView()
}
