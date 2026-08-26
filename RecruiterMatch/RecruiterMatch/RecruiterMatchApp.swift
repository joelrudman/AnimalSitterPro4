import SwiftUI

@main
struct RecruiterMatchApp: App {
    @StateObject private var store = CandidateStore()

    var body: some Scene {
        WindowGroup {
            CandidateListView()
                .environmentObject(store)
                .task {
                    await store.start()
                }
        }
    }
}
