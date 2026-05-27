import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: StoreService
    @State private var confirmingDelete = false
    @State private var showingPaywall = false

    var body: some View {
        Form {
            Section("Plan") {
                HStack {
                    Label("Current plan", systemImage: "creditcard")
                    Spacer()
                    Text(store.activeTier.displayName)
                        .foregroundStyle(.secondary)
                }
                if !store.hasPremium {
                    HStack {
                        Label("Free memory slots left", systemImage: "tray.2")
                        Spacer()
                        Text("\(store.remainingFreeSlots(currentCount: DatabaseService.shared.totalAssetCount()))")
                            .foregroundStyle(.secondary)
                    }
                }
                Button(store.hasPremium ? "Manage Purchases" : "Upgrade to Pro") {
                    showingPaywall = true
                }
            }
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
        .sheet(isPresented: $showingPaywall) {
            StorePaywallView(reason: "Choose the plan that fits your screenshot workflow.")
                .environmentObject(store)
        }
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
