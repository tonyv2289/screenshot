import SwiftUI

struct ScreenshotRollV2DetailScreen: View {
    let item: ScreenshotItem
    let imageURL: URL?
    let onCategoryChange: (ScreenshotCategory) -> Void

    @State private var selectedCategory: ScreenshotCategory

    init(
        item: ScreenshotItem,
        imageURL: URL?,
        onCategoryChange: @escaping (ScreenshotCategory) -> Void
    ) {
        self.item = item
        self.imageURL = imageURL
        self.onCategoryChange = onCategoryChange
        _selectedCategory = State(initialValue: item.category)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                imageSection
                detailsCard
                ocrCard
            }
            .padding(16)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.91, blue: 0.84), Color(red: 0.87, green: 0.91, blue: 0.90)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedCategory) { newCategory in
            onCategoryChange(newCategory)
        }
    }

    private var imageSection: some View {
        Group {
            if let imageURL, let image = LocalImageCache.fullImage(for: imageURL) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.7))
                    .frame(height: 220)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if item.isDuplicate {
                Label("Exact duplicate of an earlier import", systemImage: "square.on.square")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color(red: 0.52, green: 0.22, blue: 0.16))
            }

            Picker("Category", selection: $selectedCategory) {
                ForEach(ScreenshotCategory.allCases) { category in
                    Text(category.title).tag(category)
                }
            }
            .pickerStyle(.menu)

            infoRow(title: "Imported", value: item.importedAt.formatted(date: .abbreviated, time: .shortened))
            infoRow(title: "Size", value: "\(item.pixelWidth) × \(item.pixelHeight)")
            infoRow(title: "Source", value: item.source.rawValue.replacingOccurrences(of: "_", with: " "))
            infoRow(title: "Tags", value: item.tags.joined(separator: ", "))
        }
        .padding(18)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var ocrCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recognized Text")
                .font(.headline)

            Text(item.extractedText.isEmpty ? "No text was recognized in this screenshot." : item.extractedText)
                .font(.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func infoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "—" : value)
                .font(.body.weight(.medium))
        }
    }
}
