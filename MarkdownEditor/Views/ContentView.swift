import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: DocumentViewModel

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                EditorView()
                    .frame(minWidth: 200)
                PreviewView()
                    .frame(minWidth: 200)
            }
            Divider()
            StatusBarView()
        }
        .navigationTitle(viewModel.windowTitle)
    }
}
