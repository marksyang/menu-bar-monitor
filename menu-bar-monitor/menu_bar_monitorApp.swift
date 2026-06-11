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
                .positionTopRight()
        }
        .restorationBehavior(.disabled)
        .windowLevel(.floating)
        .windowResizability(.contentSize)
   
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
        guard let statusItem = statusItem,
                  let button = statusItem.button else { return }
            
        let hostingController = NSHostingController(
            rootView: MenuBarView(monitorService: monitorService, preferences: userPreferences)
        )
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        button.addSubview(hostingController.view)
        button.frame.size = NSSize(width: 220, height: 22)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: button.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: button.trailingAnchor),
        ])
        
        monitorService.startMonitoring()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        monitorService.stopMonitoring()
    }
}

// MARK: - 視窗位置調整 Modifier
extension View {
    func positionTopRight() -> some View {
        self.modifier(TopRightWindowModifier())
    }
}

private struct TopRightWindowModifier: ViewModifier {
    @State private var isReadyToShow = false

    func body(content: Content) -> some View {
        content
            .opacity(isReadyToShow ? 1 : 0)
            .allowsHitTesting(isReadyToShow)
            .onAppear {
                guard let window = NSApp.windows.first(where: { $0.title == "MonitorBar Detail" }) else {
                    isReadyToShow = true
                    return
                }
                
                // 先移到螢幕外
                window.setFrameOrigin(NSPoint(x: -9999, y: -9999))
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard let screen = NSScreen.main else {
                        isReadyToShow = true
                        return
                    }
                    let targetX = screen.visibleFrame.maxX - window.frame.width
                    let targetY = screen.visibleFrame.maxY - window.frame.height
                    window.setFrameOrigin(NSPoint(x: targetX, y: targetY))
                    isReadyToShow = true
                }
            }
    }
}



