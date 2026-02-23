import SwiftUI

struct LogView : View {
    @State private var viewModel = LogViewModel()
    var logViewModel: LogViewModel?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Activity Log")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    if let logViewModel {
                        logViewModel.clear()
                    } else {
                        viewModel.clear()
                    }
                }
                .controlSize(.small)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(logEntries.enumerated()), id: \.offset) { _, entry in
                        Text(entry)
                            .font(.custom(kMonoFontName, size: 11))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .frame(minWidth: 400, maxWidth: .infinity, maxHeight: 400, alignment: .topLeading)
    }
    
    private var logEntries: [String] {
        // Prefer the shared model if provided
        if let logViewModel {
            return logViewModel.entries
        }
        return viewModel.entries
    }
}

#Preview {
    LogView()
}
