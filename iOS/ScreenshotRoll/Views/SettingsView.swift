import SwiftUI

struct SettingsView: View {
    @State private var confirmingDelete = false
    var body: some View {
        Form {
            Section("Privacy") {
                Label("All processing on device", systemImage: "lock")
                Label("We do not collect data", systemImage: "nosign")
            }
            Section {
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Text("Delete All Data")
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Delete All Data?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteAll() }
        } message: {
            Text("This will permanently erase your library and index.")
        }
    }

    private func deleteAll() {
        DatabaseService.shared.deleteAllData()
        // Remove asset files
        let dir = SharedContainer.assetsDirectoryURL()
        if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for f in files { try? FileManager.default.removeItem(at: f) }
        }
    }
}

