import SwiftUI
import PhotosUI

struct LibraryView: View {
    @EnvironmentObject var vm: LibraryViewModel
    @State private var pickerItems: [PhotosPickerItem] = []

    private let grid = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                searchBar
                filtersBar
                if vm.assets.isEmpty && !vm.isImporting {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: grid, spacing: 8) {
                            ForEach(vm.assets, id: \.id) { asset in
                                NavigationLink(destination: DetailView(asset: asset)) {
                                    AssetThumbnail(asset: asset)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
            }
            .navigationTitle("Screenshot Roll")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: SmartCollectionsView()) {
                        Image(systemName: "square.stack.3d.up")
                            .a11yLabel("Smart Collections")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: ImportConstants.maxPhotoPickerItems,
                        matching: .images
                    ) {
                        Image(systemName: "square.and.arrow.down")
                            .a11yLabel("Import with Photo Picker")
                    }
                    .disabled(vm.isImporting)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { vm.toggleSort() }) {
                        Image(systemName: vm.sortByDate ? "calendar" : "text.magnifyingglass")
                            .a11yLabel("Toggle sort")
                    }
                }
            }
            .settingsLink()
            .onChange(of: pickerItems) { newItems in
                Task { await handlePicker(items: newItems) }
            }
            .overlay(alignment: .bottom) {
                if vm.isImporting {
                    importProgressView
                }
            }
            .onAppear { vm.runSearch() }
            .task { await ShareInboxProcessor.processPending() }
        }
    }

    private var importProgressView: some View {
        VStack(spacing: 8) {
            ProgressView(value: vm.importProgress)
                .progressViewStyle(.linear)
            Text("Importing \(vm.importCompleted)/\(vm.importTotal)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    var searchBar: some View {
        HStack {
            TextField("Search screenshots", text: $vm.query)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .onSubmit { vm.runSearch() }
            Menu {
                Button("Sort by Date", action: { if !vm.sortByDate { vm.toggleSort() } })
                Button("Sort by Relevance", action: { if vm.sortByDate { vm.toggleSort() } })
                Divider()
                Button("Clear filters", action: {
                    vm.selectedKinds.removeAll()
                    vm.selectedTickers.removeAll()
                    vm.dateRange = DateRangeFilter(start: nil, end: nil)
                    vm.runSearch()
                })
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            Button(action: { vm.runSearch() }) {
                Image(systemName: "magnifyingglass")
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

    var filtersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ToggleChip(isOn: Binding(
                    get: { vm.includeDuplicates },
                    set: { vm.includeDuplicates = $0; vm.runSearch() }
                ), label: "Show duplicates")
                ForEach(AssetKind.allCases) { kind in
                    ToggleChip(
                        isOn: Binding(
                            get: { vm.selectedKinds.contains(kind) },
                            set: { isOn in
                                if isOn { vm.selectedKinds.insert(kind) } else { vm.selectedKinds.remove(kind) }
                                vm.runSearch()
                            }
                        ),
                        label: kind.displayName
                    )
                }
                ForEach(vm.topTickerChips, id: \.self) { ticker in
                    ToggleChip(
                        isOn: Binding(
                            get: { vm.selectedTickers.contains(ticker) },
                            set: { isOn in
                                if isOn { vm.selectedTickers.insert(ticker) } else { vm.selectedTickers.remove(ticker) }
                                vm.runSearch()
                            }
                        ),
                        label: ticker
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Import only what you choose. Works offline.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: ImportConstants.maxPhotoPickerItems,
                matching: .images
            ) {
                Text("Pick screenshots to start")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.blue, in: Capsule())
                    .foregroundStyle(.white)
                    .a11yLabel("Pick screenshots")
            }
            Text("Tip: Next time, Share → Screenshot Roll to add quickly.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
    }

    /// Process images one at a time to avoid loading all into memory at once.
    /// This is critical for handling large batches (up to 200 images).
    func handlePicker(items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        let batchId = UUID().uuidString
        vm.beginImport(totalCount: items.count)

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await vm.importSingleImage(image, batchId: batchId)
            }
        }

        vm.endImport()
        pickerItems.removeAll()
    }
}

// MARK: - Supporting Views

struct ToggleChip: View {
    @Binding var isOn: Bool
    var label: String

    var body: some View {
        Button(action: { isOn.toggle() }) {
            Text(label)
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isOn ? Color.blue.opacity(0.2) : Color(.secondarySystemBackground), in: Capsule())
        }
    }
}

struct AssetThumbnail: View {
    let asset: Asset

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let image = UIImage(contentsOfFile: asset.filePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 110)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 110)
            }
            if let dup = asset.duplicateOfAssetId {
                Text("dup of #\(dup)")
                    .font(.caption2)
                    .padding(4)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .padding(4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
