import SwiftUI

extension Color {
    /// Parses "#RGB", "#RRGGBB", "#RRGGBBAA", "rgb(r,g,b)", "rgba(r,g,b,a)".
    /// Returns gray if unparseable.
    init(hexString: String) {
        let text = hexString.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.hasPrefix("#") {
            var hex = String(text.dropFirst())
            if hex.count == 3 || hex.count == 4 {
                hex = hex.map { "\($0)\($0)" }.joined()
            }
            var value: UInt64 = 0
            guard Scanner(string: hex).scanHexInt64(&value) else {
                self = .gray
                return
            }
            switch hex.count {
            case 6:
                self = Color(
                    red: Double((value >> 16) & 0xFF) / 255,
                    green: Double((value >> 8) & 0xFF) / 255,
                    blue: Double(value & 0xFF) / 255
                )
            case 8:
                self = Color(
                    red: Double((value >> 24) & 0xFF) / 255,
                    green: Double((value >> 16) & 0xFF) / 255,
                    blue: Double((value >> 8) & 0xFF) / 255,
                    opacity: Double(value & 0xFF) / 255
                )
            default:
                self = .gray
            }
            return
        }

        if text.lowercased().hasPrefix("rgb") {
            let numbers = text
                .drop(while: { $0 != "(" }).dropFirst()
                .prefix(while: { $0 != ")" })
                .split(separator: ",")
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if numbers.count >= 3 {
                self = Color(
                    red: numbers[0] / 255,
                    green: numbers[1] / 255,
                    blue: numbers[2] / 255,
                    opacity: numbers.count >= 4 ? numbers[3] : 1
                )
                return
            }
        }

        self = .gray
    }
}
