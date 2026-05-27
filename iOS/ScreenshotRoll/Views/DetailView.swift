import SwiftUI
import UIKit

struct DetailView: View {
    let asset: Asset
    @State private var ocrPreview: String = ""
    @State private var manualKind: AssetKind?
    @State private var entities: [ExtractedEntity] = []
    @State private var relatedItems: [RelatedAssetSummary] = []
    @State private var actions: [DetectedAction] = []
    @State private var copiedMessage: String?

    var body: some View {
        ScrollView {
            if let image = UIImage(contentsOfFile: asset.filePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            VStack(alignment: .leading, spacing: 12) {
                Picker("Tag", selection: Binding(
                    get: { manualKind ?? asset.kind },
                    set: { newKind in
                        manualKind = newKind
                        DatabaseService.shared.updateKind(newKind, forAssetId: asset.id)
                    }
                )) {
                    ForEach(AssetKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                DetailMetadataRow(asset: asset)

                if !actions.isEmpty {
                    DetailSection(title: "Actions") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                            ForEach(actions) { action in
                                ActionCard(action: action, onCopy: copyAction)
                            }
                        }
                    }
                }

                if !asset.tickers.isEmpty {
                    Text("Tickers: \(asset.tickers.joined(separator: ", "))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !entities.isEmpty {
                    DetailSection(title: "Context") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                            ForEach(Array(entities.prefix(8))) { entity in
                                EntityChip(entity: entity)
                            }
                        }
                    }
                }

                if !relatedItems.isEmpty {
                    DetailSection(title: "Related Memory") {
                        LazyVStack(spacing: 10) {
                            ForEach(relatedItems) { item in
                                NavigationLink(destination: DetailView(asset: item.asset)) {
                                    RelatedAssetCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if !ocrPreview.isEmpty {
                    DetailSection(title: "OCR Text") {
                        Text(ocrPreview)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Detail")
        .onAppear { loadDetailData() }
        .safeAreaInset(edge: .bottom) {
            if let copiedMessage {
                Text(copiedMessage)
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 10)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func loadDetailData() {
        ocrPreview = DatabaseService.shared.fetchOCRPreview(assetId: asset.id) ?? ""
        entities = DatabaseService.shared.getEntities(forAssetId: asset.id)
        actions = ActionExtractionService.actions(for: asset, ocrText: ocrPreview, entities: entities)
        relatedItems = DatabaseService.shared.getRelatedAssets(forAssetId: asset.id)
            .prefix(6)
            .compactMap { related in
                guard let relatedAsset = DatabaseService.shared.getAsset(byId: related.assetId) else { return nil }
                return RelatedAssetSummary(
                    asset: relatedAsset,
                    relationshipType: related.type,
                    strength: related.strength,
                    preview: DatabaseService.shared.fetchOCRPreview(assetId: related.assetId) ?? ""
                )
            }
    }

    private func copyAction(_ action: DetectedAction) {
        guard let copyValue = action.copyValue else { return }
        UIPasteboard.general.string = copyValue
        copiedMessage = "\(action.title) copied"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            copiedMessage = nil
        }
    }
}

private struct RelatedAssetSummary: Identifiable {
    let asset: Asset
    let relationshipType: RelationshipType
    let strength: Double
    let preview: String

    var id: Int64 { asset.id }
}

private struct DetailSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
    }
}

private struct DetailMetadataRow: View {
    let asset: Asset

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                MetadataBadge(title: asset.source.displayName, systemImage: asset.source.icon)
                MetadataBadge(title: asset.kind.displayName, systemImage: asset.kind.icon)
                if asset.duplicateOfAssetId != nil {
                    MetadataBadge(title: "Possible Duplicate", systemImage: "square.on.square")
                }
            }

            Text(asset.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MetadataBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray6), in: Capsule())
    }
}

private struct ActionCard: View {
    let action: DetectedAction
    let onCopy: (DetectedAction) -> Void

    var body: some View {
        Group {
            if let destination = action.destination {
                Link(destination: destination) {
                    cardContent
                }
            } else {
                Button(action: { onCopy(action) }) {
                    cardContent
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: action.systemImage)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
            Text(action.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(action.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct EntityChip: View {
    let entity: ExtractedEntity

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: entity.type.icon)
            Text(entity.value)
                .lineLimit(1)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct RelatedAssetCard: View {
    let item: RelatedAssetSummary

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let image = UIImage(contentsOfFile: item.asset.filePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipped()
                    .cornerRadius(10)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.relationshipType.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                if !item.preview.isEmpty {
                    Text(item.preview)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                } else {
                    Text("Open related screenshot")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text("Strength \(Int(item.strength * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
