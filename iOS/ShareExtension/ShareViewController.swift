import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private var didStartSaving = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStartSaving else { return }
        didStartSaving = true
        saveIncomingImages()
    }

    private func saveIncomingImages() {
        let providers = inputProviders()
        guard !providers.isEmpty else {
            complete()
            return
        }

        let group = DispatchGroup()
        for provider in providers {
            guard let typeIdentifier = imageTypeIdentifier(for: provider) else { continue }
            group.enter()
            loadImageData(from: provider, typeIdentifier: typeIdentifier) { data in
                defer { group.leave() }
                guard let data, !data.isEmpty else { return }
                try? ScreenshotInboxStore.enqueueImageData(
                    data,
                    suggestedName: provider.suggestedName,
                    typeIdentifier: typeIdentifier,
                    sourceBundleIdentifier: nil,
                    preferredExtension: Self.preferredFileExtension(for: typeIdentifier)
                )
            }
        }

        group.notify(queue: .main) {
            self.complete()
        }
    }

    private func inputProviders() -> [NSItemProvider] {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return [] }
        return items.flatMap { $0.attachments ?? [] }
    }

    private func imageTypeIdentifier(for provider: NSItemProvider) -> String? {
        provider.registeredTypeIdentifiers.first { identifier in
            UTType(identifier)?.conforms(to: .image) == true
        }
    }

    private func loadImageData(
        from provider: NSItemProvider,
        typeIdentifier: String,
        completion: @escaping (Data?) -> Void
    ) {
        provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
            if let data {
                completion(data)
                return
            }

            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                if let data = item as? Data {
                    completion(data)
                } else if let url = item as? URL {
                    completion(try? Data(contentsOf: url))
                } else if let image = item as? UIImage {
                    completion(image.pngData() ?? image.jpegData(compressionQuality: 0.95))
                } else {
                    completion(nil)
                }
            }
        }
    }

    private static func preferredFileExtension(for typeIdentifier: String) -> String? {
        UTType(typeIdentifier)?.preferredFilenameExtension
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
