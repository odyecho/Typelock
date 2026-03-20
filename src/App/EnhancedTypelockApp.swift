import SwiftUI

@main
struct EnhancedTypelockApp: App {
    @NSApplicationDelegateAdaptor(EnhancedAppDelegate.self) var appDelegate

    var body: some Scene {
        // 状态栏应用不需要主窗口
        Settings {
            EmptyView()
        }
        .commands {
            // 移除默认的菜单命令
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .pasteboard) {}
        }
    }
}
