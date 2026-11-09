import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Int = {
        #if DEBUG
        // シミュレータで画面を確認するときに起動時のタブを指定する（0〜3）
        if let tab = ProcessInfo.processInfo.environment["YARIKIRI_INITIAL_TAB"].flatMap(Int.init) {
            return tab
        }
        #endif
        return 0
    }()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }
                .tag(0)

            ObjectivesView()
                .tabItem {
                    Label("目標", systemImage: "flag.fill")
                }
                .tag(1)

            TimelineView()
                .tabItem {
                    Label("タイムライン", systemImage: "list.bullet.rectangle")
                }
                .tag(2)

            HistoryView()
                .tabItem {
                    Label("記録", systemImage: "calendar")
                }
                .tag(3)
        }
        .tint(.blue)
    }
}
