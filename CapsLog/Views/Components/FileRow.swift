import SwiftUI

struct FileRow: View {
    let file: SpaceFile

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading) {
                    Text(file.title)
                    if !file.folder.isEmpty {
                        Text(file.folder)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if file.permission == .readOnly {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Read-only")
            }
        }
    }
}
