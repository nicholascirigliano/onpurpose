import SwiftUI

@main
struct OnPurposeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = Store.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}

struct ContentView: View {
    @Environment(Store.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    private let ticker = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.tab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(Tab.today)
            PeopleView()
                .tabItem { Label("People", systemImage: "person.2") }
                .tag(Tab.people)
            InboxView()
                .tabItem { Label("Inbox", systemImage: "tray") }
                .badge(store.unrepliedCount)
                .tag(Tab.inbox)
        }
        .sheet(item: $store.pendingSend) { SendSheet(request: $0) }
        .sheet(item: $store.pendingReply) { ReplySheet(message: $0) }
        .sheet(item: $store.pendingNag) { NagSheet(message: $0) }
        .task {
            Cloud.listenForPurposeBacks { id, reply, at in
                store.applyPurposeBack(remoteID: id, reply: reply, at: at)
            }
            await Scheduler.requestPermission()
            store.reschedule()
        }
        .onReceive(ticker) { store.now = $0 }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.now = .now }
        }
    }
}
