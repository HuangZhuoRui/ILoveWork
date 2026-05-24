import SwiftUI
import WidgetKit

@main
struct macosAppApp: App {
    // Fire every 10 seconds to force the widget to regenerate its timeline
    // with fresh entry dates, so the countdown and salary update in near real-time.
    private let widgetRefreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some Scene {
        WindowGroup("ILoveWork — 打工人配置") {
            ContentView()
                .onAppear {
                    // Start OA Background Syncer
                    let _ = OABackgroundSyncer.shared
                    
                    NotificationManager.shared.requestPermission { granted in
                        if granted {
                            let config = ConfigStore.load()
                            NotificationManager.shared.scheduleReminders(config: config)
                        }
                    }
                }
                .onReceive(widgetRefreshTimer) { _ in
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 480, height: 580)
    }
}

