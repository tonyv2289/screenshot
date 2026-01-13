import Foundation
import os.log

enum Loggers {
    static let app = Logger(subsystem: "com.yourcompany.screenshotroll", category: "app")
    static let db = Logger(subsystem: "com.yourcompany.screenshotroll", category: "db")
    static let ocr = Logger(subsystem: "com.yourcompany.screenshotroll", category: "ocr")
    static let tagging = Logger(subsystem: "com.yourcompany.screenshotroll", category: "tagging")
    static let importFlow = Logger(subsystem: "com.yourcompany.screenshotroll", category: "import")
    static let background = Logger(subsystem: "com.yourcompany.screenshotroll", category: "background")
}

