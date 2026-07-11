import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }

            TimelineView()
                .tabItem {
                    Label("タイムライン", systemImage: "list.bullet.rectangle")
                }

            HistoryView()
                .tabItem {
                    Label("記録", systemImage: "calendar")
                }
        }
        .tint(.blue)
    }
}
