import Foundation
import os.log

enum Loggers {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.tonyv2289.screenshotroll"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let db = Logger(subsystem: subsystem, category: "db")
    static let ocr = Logger(subsystem: subsystem, category: "ocr")
    static let tagging = Logger(subsystem: subsystem, category: "tagging")
    static let importFlow = Logger(subsystem: subsystem, category: "import")
    static let background = Logger(subsystem: subsystem, category: "background")
}
