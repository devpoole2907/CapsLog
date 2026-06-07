import SwiftUI

struct NewFileView: View {
    let existingPaths: [String]
    let createFile: @MainActor (String) async -> String?
    let openFile: @MainActor (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var path: String
    @State private var isCreating = false
    @State private var errorMessage: String?

    init(
        existingPaths: [String],
        suggestedPath: String,
        createFile: @escaping @MainActor (String) async -> String?,
        openFile: @escaping @MainActor (String) -> Void
    ) {
        self.existingPaths = existingPaths
        self.createFile = createFile
        self.openFile = openFile
        _path = State(initialValue: suggestedPath)
    }

    var body: some View {
        Form {
            Section {
                TextField("Journal/Today.md", text: $path)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .disabled(isCreating)
                    .onSubmit(create)
            } header: {
                Text("Path")
            } footer: {
                Text(footerText)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .modalFormStyle(
            title: "New File",
            primaryTitle: "Create",
            isPrimaryDisabled: isCreateDisabled,
            isSaving: isCreating,
            primaryAction: create
        )
        .onChange(of: path) {
            errorMessage = nil
        }
    }

    private var normalizedPath: String? {
        var trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\", with: "/")

        while trimmed.hasPrefix("/") {
            trimmed.removeFirst()
        }

        let components = trimmed
            .split(separator: "/")
            .map(String.init)

        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            return nil
        }

        var normalized = components.joined(separator: "/")
        if !normalized.lowercased().hasSuffix(".md") {
            normalized += ".md"
        }

        return normalized
    }

    private var isCreateDisabled: Bool {
        normalizedPath == nil || hasKnownDuplicate || isCreating
    }

    private var hasKnownDuplicate: Bool {
        guard let normalizedPath else {
            return false
        }

        let existing = Set(existingPaths.map { $0.lowercased() })
        return existing.contains(normalizedPath.lowercased())
    }

    private var footerText: String {
        guard let normalizedPath else {
            return "Enter a file name or path."
        }

        if hasKnownDuplicate {
            return "A file at this path already exists."
        }

        if normalizedPath != path.trimmingCharacters(in: .whitespacesAndNewlines) {
            return "Creates \(normalizedPath)."
        }

        return "Use folders with slashes when needed."
    }

    @MainActor
    private func create() {
        guard let normalizedPath, !hasKnownDuplicate else {
            return
        }

        isCreating = true

        Task {
            let errorMessage = await createFile(normalizedPath)
            isCreating = false

            if let errorMessage {
                self.errorMessage = errorMessage
            } else {
                dismiss()
                openFile(normalizedPath)
            }
        }
    }
}
