import SwiftUI

struct MainView : View {
    @State private var viewModel = MainViewModel()
    
    var body: some View {
        VStack {
            WiFiView()
        }
    }
}

#Preview {
    MainView()
}
