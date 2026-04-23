import SwiftUI

struct SearchPanelView: View {
    @EnvironmentObject var vm: DocumentViewModel
    @FocusState private var findFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 4) {
                // Find row
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TextField("查找", text: $vm.findText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($findFocused)
                        .onSubmit { vm.findNext() }
                        .onChange(of: vm.findText) { _ in vm.findResult = nil }
                    Button(action: vm.findPrevious) {
                        Image(systemName: "chevron.up").font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                    .disabled(vm.findText.isEmpty)
                    Button(action: vm.findNext) {
                        Image(systemName: "chevron.down").font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                    .disabled(vm.findText.isEmpty)
                }
                .padding(6)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 5))

                // Replace row
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TextField("替换", text: $vm.replaceText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(6)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            // Action buttons
            HStack(spacing: 8) {
                Spacer()
                Button("替换", action: vm.replaceCurrentAndFindNext)
                    .font(.system(size: 11))
                    .buttonStyle(.borderless)
                    .disabled(vm.findText.isEmpty || vm.findResult == nil)
                Button("全部替换", action: vm.replaceAll)
                    .font(.system(size: 11))
                    .buttonStyle(.borderless)
                    .disabled(vm.findText.isEmpty)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            // Result indicator
            if !vm.findText.isEmpty {
                Text(vm.findResult != nil ? "找到匹配项" : "无匹配")
                    .font(.system(size: 10))
                    .foregroundStyle(vm.findResult != nil ? Color.green : Color.orange)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
            }

            Spacer()
        }
        .onAppear {
            DispatchQueue.main.async { findFocused = true }
        }
    }
}
