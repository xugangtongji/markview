import SwiftUI

@main
struct MarkdownEditorApp: App {
    @StateObject private var viewModel = DocumentViewModel()
    @StateObject private var sidebarVM = SidebarViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(sidebarVM)
                .frame(minWidth: 800, minHeight: 500)
                .onOpenURL { url in
                    viewModel.openDocument(url: url)
                }
                .onAppear {
                    sidebarVM.bind(to: viewModel)
                }
        }
        .windowToolbarStyle(.unified)
        .commands {
            FileCommands(viewModel: viewModel, sidebarVM: sidebarVM)
        }
    }
}
