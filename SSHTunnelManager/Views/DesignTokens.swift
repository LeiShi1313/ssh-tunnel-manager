import SwiftUI

// MARK: - Color Palette (from Stitch Design System)

extension Color {
    // Primary
    static let dsPrimary = Color(hex: 0x4C49C9)
    static let dsPrimaryDim = Color(hex: 0x3F3BBD)
    static let dsPrimaryContainer = Color(hex: 0x9695FF)
    static let dsOnPrimary = Color(hex: 0xF4F1FF)

    // Secondary
    static let dsSecondary = Color(hex: 0x6149B2)
    static let dsSecondaryContainer = Color(hex: 0xD7CAFF)

    // Tertiary
    static let dsTertiary = Color(hex: 0x973773)
    static let dsTertiaryContainer = Color(hex: 0xFD8BCC)

    // Surface
    static let dsSurface = Color(hex: 0xFAF4FF)
    static let dsSurfaceContainer = Color(hex: 0xEDE4FF)
    static let dsSurfaceContainerLow = Color(hex: 0xF5EEFF)
    static let dsSurfaceContainerHigh = Color(hex: 0xE7DEFF)
    static let dsSurfaceContainerHighest = Color(hex: 0xE2D7FF)

    // On Surface
    static let dsOnSurface = Color(hex: 0x312950)
    static let dsOnSurfaceVariant = Color(hex: 0x5F5680)

    // Outline
    static let dsOutline = Color(hex: 0x7A719C)
    static let dsOutlineVariant = Color(hex: 0xB2A7D6)

    // Error
    static let dsError = Color(hex: 0xB41340)
    static let dsErrorContainer = Color(hex: 0xF74B6D)

    // Convenience initializer from hex
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - Design Constants

enum DS {
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusLarge: CGFloat = 16

    static let cardPadding: CGFloat = 12
    static let sectionPadding: CGFloat = 16

    static let iconCircleSize: CGFloat = 36

    static let cardShadow: some ShapeStyle = Color.black.opacity(0.06)
}
