import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject var viewModel: DocumentViewModel

    var body: some View {
        HStack(spacing: 16) {
            Text("行 \(viewModel.cursorLine)，列 \(viewModel.cursorColumn)")
                .monospacedDigit()

            Divider().frame(height: 12)

            Text("\(viewModel.content.count) 个字符")
                .monospacedDigit()

            Divider().frame(height: 12)

            Text("\(viewModel.wordCount) 词")
                .monospacedDigit()

            Divider().frame(height: 12)

            Text("\(viewModel.lineCount) 行")
                .monospacedDigit()

            Spacer()

            Text("Markdown")

            Divider().frame(height: 12)

            Text("UTF-8")

            Divider().frame(height: 12)

            Text(viewModel.isModified ? "未保存" : "已保存")
                .foregroundStyle(viewModel.isModified ? Color.orange : Color.secondary)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
    }
}
