import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: DocumentViewModel

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Main split + floating toggle button
                ZStack {
                    HSplitView {
                        EditorView()
                            .frame(minWidth: 200)
                        PreviewView()
                            .frame(
                                minWidth: viewModel.showPreview ? 200 : 0,
                                maxWidth: viewModel.showPreview ? .infinity : 0
                            )
                            .opacity(viewModel.showPreview ? 1 : 0)
                    }
                    // Floating preview toggle button — bottom-right corner
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                viewModel.showPreview.toggle()
                            } label: {
                                Image(systemName: viewModel.showPreview ? "sidebar.right" : "sidebar.right.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(radius: 2, y: 1)
                            }
                            .buttonStyle(.borderless)
                            .help(viewModel.showPreview ? "隐藏预览" : "显示预览")
                            .padding(12)
                        }
                    }
                }
                // Find bar slides down from top
                if viewModel.showFindBar {
                    FindBarView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.showFindBar)
            Divider()
            StatusBarView()
        }
        .navigationTitle(viewModel.windowTitle)
    }
}
