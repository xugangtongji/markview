import SwiftUI

@main
struct MarkdownEditorApp: App {
    @StateObject private var viewModel = DocumentViewModel()
    @StateObject private var sidebarVM = SidebarViewModel()
    @StateObject private var tabsVM = TabsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(sidebarVM)
                .environmentObject(tabsVM)
                .frame(minWidth: 900, minHeight: 500)
                .onOpenURL { url in
                    guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                    NotificationCenter.default.post(
                        name: .openNewTab,
                        object: nil,
                        userInfo: ["url": url, "content": content]
                    )
                }
        }
        .windowToolbarStyle(.unified)
        .commands {
            FileCommands(viewModel: viewModel, sidebarVM: sidebarVM, tabsVM: tabsVM)
        }
    }
}
