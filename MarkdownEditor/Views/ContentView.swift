import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: DocumentViewModel

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HSplitView {
                    EditorView()
                        .frame(minWidth: 200)
                    if viewModel.showPreview {
                        PreviewView()
                            .frame(minWidth: 200)
                    }
                }
                // Floating preview toggle button — bottom-right corner
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.showPreview.toggle()
                            }
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
            Divider()
            StatusBarView()
        }
        .navigationTitle(viewModel.windowTitle)
    }
}
