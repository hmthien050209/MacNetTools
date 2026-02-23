import SwiftUI

struct MainView : View {
    @State private var viewModel = MainViewModel()
    @State private var logViewModel = LogViewModel()
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                BasicNetView(logViewModel: logViewModel)
                WiFiView(logViewModel: logViewModel)
                PingView(logViewModel: logViewModel)
            }
            
            HStack(alignment: .top, spacing: 16) {
                ExternalToolsView(logViewModel: logViewModel)
                LogView(logViewModel: logViewModel)
            }
        }
        .padding()
    }
}

#Preview {
    MainView()
}
