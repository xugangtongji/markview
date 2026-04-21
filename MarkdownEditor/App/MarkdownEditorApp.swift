import SwiftUI

@main
struct MarkdownEditorApp: App {
    @StateObject private var viewModel = DocumentViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 800, minHeight: 500)
                .onOpenURL { url in
                    viewModel.openDocument(url: url)
                }
        }
        .windowToolbarStyle(.unified)
        .commands {
            FileCommands(viewModel: viewModel)
        }
    }
}
