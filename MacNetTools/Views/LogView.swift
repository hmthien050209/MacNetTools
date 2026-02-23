import SwiftUI

struct LogView : View {
    var logViewModel: LogViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Activity Log")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    logViewModel.clear()
                }
                .controlSize(.small)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(logViewModel.entries) { entry in
                        Text(entry.message)
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
}

#Preview {
    LogView(logViewModel: LogViewModel())
}
