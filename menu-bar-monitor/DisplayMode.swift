import Foundation

/// Determines how metrics are formatted in the Menu Bar
enum DisplayMode: String, CaseIterable, Identifiable, Codable {
    case compact = "Compact"
    case standard = "Standard"
    case aiMode = "AI Mode"
    case iconMode = "Icon Mode"

    var id: String { rawValue }
}
