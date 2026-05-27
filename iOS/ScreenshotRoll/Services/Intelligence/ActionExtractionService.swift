import Foundation

struct DetectedAction: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case copyOCR
        case openURL
        case email
        case call
        case text
        case map
        case copyDate
    }

    let kind: Kind
    let title: String
    let subtitle: String
    let systemImage: String
    let destination: URL?
    let copyValue: String?

    var id: String {
        "\(kind.rawValue)|\(destination?.absoluteString ?? copyValue ?? subtitle)"
    }

    var isCopyAction: Bool {
        destination == nil && copyValue != nil
    }
}

enum ActionExtractionService {
    static func actions(for asset: Asset, ocrText: String, entities: [ExtractedEntity]) -> [DetectedAction] {
        var actions: [DetectedAction] = []

        let trimmedText = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            actions.append(
                DetectedAction(
                    kind: .copyOCR,
                    title: "Copy OCR",
                    subtitle: "Copy recognized text",
                    systemImage: "doc.on.doc",
                    destination: nil,
                    copyValue: trimmedText
                )
            )
        }

        let detectorTypes = NSTextCheckingResult.CheckingType(rawValue:
            NSTextCheckingResult.CheckingType.link.rawValue |
            NSTextCheckingResult.CheckingType.phoneNumber.rawValue |
            NSTextCheckingResult.CheckingType.address.rawValue |
            NSTextCheckingResult.CheckingType.date.rawValue
        )
        for result in detectorResults(in: ocrText, types: detectorTypes) {
            if let url = result.url {
                switch url.scheme?.lowercased() {
                case "mailto":
                    let email = url.resourceSpecifier.removingPercentEncoding ?? url.resourceSpecifier
                    actions.append(
                        DetectedAction(
                            kind: .email,
                            title: "Email",
                            subtitle: email,
                            systemImage: "envelope",
                            destination: url,
                            copyValue: nil
                        )
                    )
                case "http", "https":
                    actions.append(
                        DetectedAction(
                            kind: .openURL,
                            title: "Open Link",
                            subtitle: friendlyURLLabel(url),
                            systemImage: "link",
                            destination: url,
                            copyValue: nil
                        )
                    )
                default:
                    break
                }
            }

            if let phoneNumber = result.phoneNumber {
                let sanitized = phoneNumber.filter { $0.isNumber || $0 == "+" }
                if let callURL = URL(string: "tel://\(sanitized)") {
                    actions.append(
                        DetectedAction(
                            kind: .call,
                            title: "Call",
                            subtitle: phoneNumber,
                            systemImage: "phone",
                            destination: callURL,
                            copyValue: nil
                        )
                    )
                }
                if let smsURL = URL(string: "sms:\(sanitized)") {
                    actions.append(
                        DetectedAction(
                            kind: .text,
                            title: "Text",
                            subtitle: phoneNumber,
                            systemImage: "message",
                            destination: smsURL,
                            copyValue: nil
                        )
                    )
                }
            }

            if let address = formattedAddress(from: result),
               let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let mapsURL = URL(string: "http://maps.apple.com/?q=\(encoded)") {
                actions.append(
                    DetectedAction(
                        kind: .map,
                        title: "Open in Maps",
                        subtitle: address,
                        systemImage: "map",
                        destination: mapsURL,
                        copyValue: nil
                    )
                )
            }

            if let date = result.date {
                let formatted = date.formatted(date: .abbreviated, time: .shortened)
                actions.append(
                    DetectedAction(
                        kind: .copyDate,
                        title: "Copy Date",
                        subtitle: formatted,
                        systemImage: "calendar",
                        destination: nil,
                        copyValue: formatted
                    )
                )
            }
        }

        // If OCR detectors miss a visible URL entity, still surface it.
        for entity in entities where entity.type == .url {
            guard let url = URL(string: entity.value) else { continue }
            actions.append(
                DetectedAction(
                    kind: .openURL,
                    title: "Open Link",
                    subtitle: friendlyURLLabel(url),
                    systemImage: "link",
                    destination: url,
                    copyValue: nil
                )
            )
        }

        // Finance-aware parsing is part of the thesis, so expose tickers as copyable context.
        if !asset.tickers.isEmpty {
            actions.append(
                DetectedAction(
                    kind: .copyOCR,
                    title: "Copy Tickers",
                    subtitle: asset.tickers.joined(separator: ", "),
                    systemImage: "chart.line.uptrend.xyaxis",
                    destination: nil,
                    copyValue: asset.tickers.joined(separator: ", ")
                )
            )
        }

        return deduplicated(actions).prefix(8).map { $0 }
    }

    private static func detectorResults(in text: String, types: NSTextCheckingResult.CheckingType) -> [NSTextCheckingResult] {
        guard !text.isEmpty else { return [] }
        guard let detector = try? NSDataDetector(types: types.rawValue) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.matches(in: text, options: [], range: range)
    }

    private static func formattedAddress(from result: NSTextCheckingResult) -> String? {
        if let components = result.addressComponents {
            let orderedKeys = [
                NSTextCheckingKey.street.rawValue,
                NSTextCheckingKey.city.rawValue,
                NSTextCheckingKey.state.rawValue,
                NSTextCheckingKey.zip.rawValue,
                NSTextCheckingKey.country.rawValue
            ]
            let parts = orderedKeys.compactMap { components[$0] }.filter { !$0.isEmpty }
            if !parts.isEmpty {
                return parts.joined(separator: ", ")
            }
        }
        return nil
    }

    private static func friendlyURLLabel(_ url: URL) -> String {
        if let host = url.host, !host.isEmpty {
            return host + url.path
        }
        return url.absoluteString
    }

    private static func deduplicated(_ actions: [DetectedAction]) -> [DetectedAction] {
        var seen = Set<String>()
        var unique: [DetectedAction] = []
        for action in actions {
            if seen.insert(action.id).inserted {
                unique.append(action)
            }
        }
        return unique
    }
}
