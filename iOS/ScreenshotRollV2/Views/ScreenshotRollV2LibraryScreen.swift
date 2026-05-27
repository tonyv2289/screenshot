import PhotosUI
import SwiftUI

struct ScreenshotRollV2LibraryScreen: View {
    @StateObject private var viewModel = ScreenshotRollV2LibraryViewModel()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var confirmsDelete = false

    private let grid = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroCard
                    controlsCard

                    if let statusMessage = viewModel.statusMessage {
                        statusBanner(message: statusMessage)
                    }

                    if viewModel.filteredItems.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: grid, spacing: 14) {
                            ForEach(viewModel.filteredItems) { item in
                                NavigationLink {
                                    ScreenshotRollV2DetailScreen(
                                        item: item,
                                        imageURL: viewModel.imageURL(for: item),
                                        onCategoryChange: { category in
                                            Task {
                                                await viewModel.updateCategory(for: item.id, to: category)
                                            }
                                        }
                                    )
                                } label: {
                                    ScreenshotTile(item: item, imageURL: viewModel.imageURL(for: item))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
            .background(background.ignoresSafeArea())
            .navigationTitle("Screenshot Roll v2")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        confirmsDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 100,
                        matching: .images
                    ) {
                        Label("Import", systemImage: "plus.viewfinder")
                    }
                    .disabled(viewModel.isImporting)
                }
            }
            .task {
                await viewModel.refresh()
            }
            .onChange(of: pickerItems) { newItems in
                Task {
                    await viewModel.importItems(from: newItems)
                    pickerItems = []
                }
            }
            .overlay(alignment: .bottom) {
                if viewModel.isImporting {
                    progressCard
                        .padding()
                }
            }
            .alert("Delete the entire v2 library?", isPresented: $confirmsDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteAll()
                    }
                }
            } message: {
                Text("This removes imported images and metadata for Screenshot Roll v2 only.")
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("A first-principles rewrite for the actual job: import screenshots, read them, and find them later.")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                StatBadge(title: "Library", value: "\(viewModel.stats.totalCount)")
                StatBadge(title: "OCR Ready", value: "\(viewModel.stats.textReadyCount)")
                StatBadge(title: "Duplicates", value: "\(viewModel.stats.duplicateCount)")
            }

            Text("Local files, explicit state, exact-duplicate checks, and zero speculative features.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(red: 0.18, green: 0.34, blue: 0.33), Color(red: 0.66, green: 0.34, blue: 0.17)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search OCR text, tags, or category", text: $viewModel.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text("Category")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "All",
                            isSelected: viewModel.selectedCategory == nil
                        ) {
                            viewModel.selectedCategory = nil
                        }

                        ForEach(viewModel.availableCategories) { category in
                            FilterChip(
                                title: category.title,
                                isSelected: viewModel.selectedCategory == category
                            ) {
                                if viewModel.selectedCategory == category {
                                    viewModel.selectedCategory = nil
                                } else {
                                    viewModel.selectedCategory = category
                                }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Picker("Sort", selection: $viewModel.sortMode) {
                    ForEach(LibrarySortMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Duplicates", isOn: $viewModel.showsDuplicates)
                    .toggleStyle(.switch)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: 132, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
    }

    private func statusBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(red: 0.16, green: 0.46, blue: 0.31))
            Text(message)
                .font(.footnote.weight(.medium))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing here yet")
                .font(.title3.weight(.bold))
            Text("Import a handful of screenshots and this version will build a simple local library with OCR and duplicate-aware metadata.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Importing \(viewModel.importCompleted) of \(viewModel.importTotal)")
                .font(.headline)
            ProgressView(
                value: Double(viewModel.importCompleted),
                total: Double(max(viewModel.importTotal, 1))
            )
            .tint(Color(red: 0.66, green: 0.34, blue: 0.17))
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.95, green: 0.91, blue: 0.84), Color(red: 0.87, green: 0.91, blue: 0.90)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct ScreenshotTile: View {
    let item: ScreenshotItem
    let imageURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LocalThumbnailView(url: imageURL)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack(spacing: 8) {
                Label(item.category.title, systemImage: item.category.systemImage)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if item.isDuplicate {
                    Text("Duplicate")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.52, green: 0.22, blue: 0.16), in: Capsule())
                        .foregroundStyle(.white)
                }
            }

            Text(item.extractedText.isEmpty ? "No text detected." : item.extractedText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct StatBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.72))
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isSelected
                    ? Color(red: 0.18, green: 0.34, blue: 0.33)
                    : Color(red: 0.92, green: 0.91, blue: 0.89),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
