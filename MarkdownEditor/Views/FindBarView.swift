import SwiftUI

struct FindBarView: View {
    @EnvironmentObject var vm: DocumentViewModel
    @FocusState private var findFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            // Find row
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                TextField("查找", text: $vm.findText)
                    .textFieldStyle(.plain)
                    .focused($findFocused)
                    .onSubmit { vm.findNext() }
                    .onChange(of: vm.findText) { _ in vm.findResult = nil }
                Button(action: vm.findPrevious) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(vm.findText.isEmpty)
                Button(action: vm.findNext) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(vm.findText.isEmpty)
                Button {
                    vm.showFindBar = false
                    vm.findResult = nil
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }
            // Replace row
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                TextField("替换", text: $vm.replaceText)
                    .textFieldStyle(.plain)
                Button("替换", action: vm.replaceCurrentAndFindNext)
                    .buttonStyle(.borderless)
                    .disabled(vm.findText.isEmpty || vm.findResult == nil)
                Button("全部替换", action: vm.replaceAll)
                    .buttonStyle(.borderless)
                    .disabled(vm.findText.isEmpty)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .onAppear {
            DispatchQueue.main.async { findFocused = true }
        }
    }
}
