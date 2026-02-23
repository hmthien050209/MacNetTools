import SwiftUI

struct LogView : View {
    var logViewModel: LogViewModel
    @State private var searchText = ""
    
    var body: some View {
        let filtered = logViewModel.filteredEntries(searchText: searchText)
        
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Activity Log")
                        .font(.headline)
                    Spacer()
                    Button("Clear logs") {
                        logViewModel.clear()
                    }
                    .controlSize(.small)
                }
                
                HStack {
                    TextField("Filter...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    Spacer()
                    Button("Clear filter") {
                        searchText = ""
                    }
                    .controlSize(.small)
                }
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(filtered) { entry in
                            Text(entry.message)
                                .font(.custom(kMonoFontName, size: 11))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .id(entry.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .onChange(of: filtered.count) { _, _ in
                        if let last = filtered.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .background(.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.2))
            )
        }
        .frame(minWidth: 400, maxWidth: .infinity, maxHeight: 400, alignment: .topLeading)
    }
}

#Preview {
    LogView(logViewModel: LogViewModel())
}
