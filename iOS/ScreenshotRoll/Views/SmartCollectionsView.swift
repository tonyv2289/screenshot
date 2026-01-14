import SwiftUI

/// Smart Collections view showing automatic groupings by content type
struct SmartCollectionsView: View {
    @State private var contentCounts: [ContentType: Int] = [:]
    @State private var topAuthors: [(String, Int)] = []
    @State private var topTopics: [(String, Int)] = []
    @State private var selectedCollection: ContentType?
    @State private var showingExportSheet = false

    var body: some View {
        NavigationStack {
            List {
                // Content Type Collections
                Section("Content Types") {
                    ForEach(ContentType.allCases, id: \.self) { type in
                        let count = contentCounts[type] ?? 0
                        NavigationLink(destination: CollectionDetailView(contentType: type)) {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 30)
                                Text(type.displayName)
                                Spacer()
                                Text("\(count)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .disabled(count == 0)
                    }
                }

                // Top Authors
                if !topAuthors.isEmpty {
                    Section("People You Follow") {
                        ForEach(topAuthors.prefix(5), id: \.0) { author, count in
                            NavigationLink(destination: EntityResultsView(entityType: .username, value: author)) {
                                HStack {
                                    Image(systemName: "person.circle")
                                        .foregroundColor(.blue)
                                    Text(author)
                                    Spacer()
                                    Text("\(count)")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // Topics
                if !topTopics.isEmpty {
                    Section("Topics") {
                        ForEach(topTopics.prefix(5), id: \.0) { topic, count in
                            NavigationLink(destination: EntityResultsView(entityType: .topic, value: topic)) {
                                HStack {
                                    Image(systemName: "tag")
                                        .foregroundColor(.orange)
                                    Text(topic)
                                    Spacer()
                                    Text("\(count)")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // AI Export
                Section("AI Integration") {
                    Button(action: { showingExportSheet = true }) {
                        HStack {
                            Image(systemName: "brain")
                                .foregroundColor(.purple)
                            Text("Export for AI")
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Collections")
            .onAppear(perform: loadData)
            .sheet(isPresented: $showingExportSheet) {
                AIExportSheet()
            }
        }
    }

    private func loadData() {
        contentCounts = DatabaseService.shared.getContentTypeCounts()
        topAuthors = DatabaseService.shared.getTopEntities(type: .username, limit: 10)
            .map { ($0.value, $0.count) }
        topTopics = DatabaseService.shared.getTopEntities(type: .topic, limit: 10)
            .map { ($0.value, $0.count) }
    }
}

/// Shows all screenshots of a specific content type
struct CollectionDetailView: View {
    let contentType: ContentType
    @State private var assets: [Asset] = []

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                ForEach(assets, id: \.id) { asset in
                    NavigationLink(destination: DetailView(asset: asset)) {
                        AsyncImage(url: URL(fileURLWithPath: asset.filePath)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 100, height: 100)
                        .clipped()
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(contentType.displayName)
        .onAppear {
            assets = DatabaseService.shared.findAssets(byContentType: contentType)
        }
    }
}

/// Shows results for a specific entity (author, topic, etc.)
struct EntityResultsView: View {
    let entityType: EntityType
    let value: String
    @State private var assetIds: [Int64] = []

    var body: some View {
        ScrollView {
            if assetIds.isEmpty {
                Text("No screenshots found")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack {
                    ForEach(assetIds, id: \.self) { assetId in
                        if let text = DatabaseService.shared.fetchOCRPreview(assetId: assetId) {
                            VStack(alignment: .leading) {
                                Text(text.prefix(200))
                                    .font(.body)
                                    .lineLimit(4)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(value)
        .onAppear {
            assetIds = DatabaseService.shared.findAssets(withEntityType: entityType, value: value)
        }
    }
}

/// Sheet for exporting knowledge to AI
struct AIExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var exportText: String = ""
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Export Your Knowledge")
                    .font(.title2)
                    .bold()

                Text("Copy this to share with AI assistants so they understand what you're interested in.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                ScrollView {
                    Text(exportText)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .frame(maxHeight: 300)

                Button(action: copyToClipboard) {
                    HStack {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied!" : "Copy to Clipboard")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                exportText = AIExportService.shared.exportForAIContext()
            }
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = exportText
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}

#Preview {
    SmartCollectionsView()
}
