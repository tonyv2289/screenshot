import UIKit
import Social

final class ShareViewController: SLComposeServiceViewController {
    override func isContentValid() -> Bool { true }

    override func didSelectPost() {
        guard let items = (extensionContext?.inputItems as? [NSExtensionItem]) else {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        let groupInbox = SharedContainer.sharedInboxURL()
        let providers: [NSItemProvider] = items.compactMap { $0.attachments }.flatMap { $0 }
        let group = DispatchGroup()
        for provider in providers where provider.hasItemConformingToTypeIdentifier("public.image") {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.image", options: nil) { item, _ in
                defer { group.leave() }
                if let url = item as? URL, let data = try? Data(contentsOf: url) {
                    let filename = UUID().uuidString + ".jpg"
                    let dest = groupInbox.appendingPathComponent(filename)
                    try? data.write(to: dest, options: [.atomic, .completeFileProtection])
                } else if let image = item as? UIImage, let data = image.jpegData(compressionQuality: 0.95) {
                    let filename = UUID().uuidString + ".jpg"
                    let dest = groupInbox.appendingPathComponent(filename)
                    try? data.write(to: dest, options: [.atomic, .completeFileProtection])
                }
            }
        }
        group.notify(queue: .main) {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    override func configurationItems() -> [Any]! { [] }
}

