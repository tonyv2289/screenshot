import SwiftUI

struct DetailView: View {
    let asset: Asset
    @State private var ocrPreview: String = ""
    @State private var manualKind: AssetKind?

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

                if !asset.tickers.isEmpty {
                    Text("Tickers: \(asset.tickers.joined(separator: ", "))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !ocrPreview.isEmpty {
                    Text(ocrPreview)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(8)
                }
            }
            .padding()
        }
        .navigationTitle("Detail")
        .onAppear { loadPreview() }
        .accessibilityElement(children: .contain)
    }

    private func loadPreview() {
        // For MVP: fetch snippet from FTS by asset id
        ocrPreview = DatabaseService.shared.fetchOCRPreview(assetId: asset.id) ?? ""
    }
}

