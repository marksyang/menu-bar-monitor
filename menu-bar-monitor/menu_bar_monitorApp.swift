import SwiftUI
import AppKit

@main
struct menu_bar_monitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            EmptyView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1, height: 1)
        .restorationBehavior(.disabled)
        
        Window("MonitorBar Detail", id: "mainPanel") {
            MainPanelView()
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    let userPreferences = UserPreference()
    var monitorService = SystemMonitorService()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        userPreferences.load()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let statusItem = statusItem else { return }
        
        let hostingController = NSHostingController<MenuBarView>(rootView: MenuBarView(monitorService: monitorService, preferences: userPreferences))
        
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = .preferredContentSize
            // 強制設定尺寸，避免狀態列視圖高度/寬度塌陷為 0
            hostingController.view.frame.size = NSSize(width: 220, height: 22)
            statusItem.view = hostingController.view
        } else {
            if let button = statusItem.button {
                hostingController.view.translatesAutoresizingMaskIntoConstraints = false
                button.addSubview(hostingController.view)
                NSLayoutConstraint.activate([
                    hostingController.view.topAnchor.constraint(equalTo: button.topAnchor),
                    hostingController.view.bottomAnchor.constraint(equalTo: button.bottomAnchor),
                    hostingController.view.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                    hostingController.view.trailingAnchor.constraint(equalTo: button.trailingAnchor)
                ])
            }
        }
        
        monitorService.startMonitoring()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        monitorService.stopMonitoring()
    }
}
