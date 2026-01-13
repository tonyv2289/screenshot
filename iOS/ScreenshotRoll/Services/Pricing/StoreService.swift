import Foundation
import StoreKit
import Combine

final class StoreService: ObservableObject {
    static let shared = StoreService()
    @Published var isPurchased: Bool = true // For MVP dev, default unlocked; wire to StoreKit later
    private init() {}
}

