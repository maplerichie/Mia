import Foundation

/// Curated list of currencies offered in the "Add / Edit Subscription" form.
/// Limited to the most common subscription-billing currencies so the picker
/// stays scannable; unsupported ISO codes still round-trip through
/// `Subscription.currency` if entered programmatically.
enum CurrencyCatalog {
    struct Entry: Identifiable, Hashable, Sendable {
        let code: String
        let symbol: String
        let name: String
        var id: String { code }
        /// Picker-friendly label, e.g. `"USD ($) – US Dollar"`.
        var displayLabel: String { "\(code) (\(symbol)) – \(name)" }
    }

    static let common: [Entry] = [
        .init(code: "USD", symbol: "$", name: "US Dollar"),
        .init(code: "EUR", symbol: "€", name: "Euro"),
        .init(code: "GBP", symbol: "£", name: "British Pound"),
        .init(code: "JPY", symbol: "¥", name: "Japanese Yen"),
        .init(code: "CNY", symbol: "¥", name: "Chinese Yuan"),
        .init(code: "AUD", symbol: "A$", name: "Australian Dollar"),
        .init(code: "CAD", symbol: "C$", name: "Canadian Dollar"),
        .init(code: "CHF", symbol: "CHF", name: "Swiss Franc"),
        .init(code: "HKD", symbol: "HK$", name: "Hong Kong Dollar"),
        .init(code: "SGD", symbol: "S$", name: "Singapore Dollar"),
        .init(code: "INR", symbol: "₹", name: "Indian Rupee"),
        .init(code: "KRW", symbol: "₩", name: "South Korean Won"),
        .init(code: "BRL", symbol: "R$", name: "Brazilian Real"),
        .init(code: "MXN", symbol: "Mex$", name: "Mexican Peso"),
        .init(code: "SEK", symbol: "kr", name: "Swedish Krona"),
        .init(code: "NOK", symbol: "kr", name: "Norwegian Krone"),
        .init(code: "DKK", symbol: "kr", name: "Danish Krone"),
        .init(code: "PLN", symbol: "zł", name: "Polish Zloty"),
        .init(code: "TRY", symbol: "₺", name: "Turkish Lira"),
        .init(code: "THB", symbol: "฿", name: "Thai Baht"),
        .init(code: "MYR", symbol: "RM", name: "Malaysian Ringgit"),
        .init(code: "IDR", symbol: "Rp", name: "Indonesian Rupiah"),
        .init(code: "VND", symbol: "₫", name: "Vietnamese Dong"),
        .init(code: "PHP", symbol: "₱", name: "Philippine Peso"),
        .init(code: "AED", symbol: "د.إ", name: "UAE Dirham"),
        .init(code: "ZAR", symbol: "R", name: "South African Rand"),
        .init(code: "RUB", symbol: "₽", name: "Russian Ruble")
    ]

    /// Localized symbol for a 3-letter ISO code; falls back to the code if
    /// it isn't in the curated list.
    static func symbol(for code: String) -> String {
        common.first { $0.code == code }?.symbol ?? code
    }
}
