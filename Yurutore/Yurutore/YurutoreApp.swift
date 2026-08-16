import SwiftUI

@main
struct YurutoreApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
