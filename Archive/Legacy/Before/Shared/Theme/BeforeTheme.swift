import SwiftUI

enum BeforeTheme {
    static let ember = Color(red: 0.984, green: 0.525, blue: 0.286)
    static let ink = Color(red: 0.101, green: 0.098, blue: 0.125)
    static let fog = Color(red: 0.949, green: 0.949, blue: 0.973)
    static let moss = Color(red: 0.329, green: 0.482, blue: 0.349)
    static let rose = Color(red: 0.675, green: 0.275, blue: 0.333)
    static let soft = Color(red: 0.992, green: 0.964, blue: 0.933)

    static let panel = LinearGradient(
        colors: [Color.white.opacity(0.86), soft.opacity(0.92)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let background = LinearGradient(
        colors: [fog, soft.opacity(0.75), Color.white],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
