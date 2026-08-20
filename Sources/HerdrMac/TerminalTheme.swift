import SwiftUI

struct ThemeRGB: Hashable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    init(_ hex: UInt32) {
        red = UInt8((hex >> 16) & 0xFF)
        green = UInt8((hex >> 8) & 0xFF)
        blue = UInt8(hex & 0xFF)
    }

    var color: Color {
        Color(
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255
        )
    }
}

struct TerminalThemePalette: Hashable {
    let background: ThemeRGB
    let foreground: ThemeRGB
    let cursor: ThemeRGB
    let selection: ThemeRGB
    let ansi: [ThemeRGB]
}

/// Herdr 0.8.2's built-in themes, in the same order as `THEME_NAMES` in the
/// official source. This is deliberately not an independent Mac theme catalog.
enum TerminalTheme: String, CaseIterable, Identifiable {
    case catppuccin
    case catppuccinLatte = "catppuccin-latte"
    case terminal
    case tokyoNight = "tokyo-night"
    case tokyoNightDay = "tokyo-night-day"
    case dracula
    case nord
    case gruvbox
    case gruvboxLight = "gruvbox-light"
    case oneDark = "one-dark"
    case oneLight = "one-light"
    case solarized
    case solarizedLight = "solarized-light"
    case kanagawa
    case kanagawaLotus = "kanagawa-lotus"
    case rosePine = "rose-pine"
    case rosePineDawn = "rose-pine-dawn"
    case vesper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .catppuccin: "Catppuccin Mocha"
        case .catppuccinLatte: "Catppuccin Latte"
        case .terminal: "Terminal"
        case .tokyoNight: "Tokyo Night"
        case .tokyoNightDay: "Tokyo Night Day"
        case .dracula: "Dracula"
        case .nord: "Nord"
        case .gruvbox: "Gruvbox Dark"
        case .gruvboxLight: "Gruvbox Light"
        case .oneDark: "One Dark"
        case .oneLight: "One Light"
        case .solarized: "Solarized Dark"
        case .solarizedLight: "Solarized Light"
        case .kanagawa: "Kanagawa"
        case .kanagawaLotus: "Kanagawa Lotus"
        case .rosePine: "Rose Pine"
        case .rosePineDawn: "Rose Pine Dawn"
        case .vesper: "Vesper"
        }
    }

    var subtitle: String {
        switch self {
        case .catppuccin: "Herdr 默认深色主题"
        case .catppuccinLatte: "Catppuccin 的官方浅色版本"
        case .terminal: "使用宿主终端的 ANSI 调色板"
        case .tokyoNight: "蓝紫色深色主题"
        case .tokyoNightDay: "Tokyo Night 的官方浅色版本"
        case .dracula: "紫、粉与绿色高对比主题"
        case .nord: "低对比冷蓝色主题"
        case .gruvbox: "暖色复古深色主题"
        case .gruvboxLight: "Gruvbox 的官方浅色版本"
        case .oneDark: "Atom 风格深色主题"
        case .oneLight: "Atom 风格浅色主题"
        case .solarized: "Solarized 深色主题"
        case .solarizedLight: "Solarized 浅色主题"
        case .kanagawa: "受日本浮世绘启发的深色主题"
        case .kanagawaLotus: "Kanagawa 的官方浅色版本"
        case .rosePine: "低饱和深色主题"
        case .rosePineDawn: "Rose Pine 的官方浅色版本"
        case .vesper: "极简高对比深色主题"
        }
    }

    var isLight: Bool {
        switch self {
        case .catppuccinLatte, .tokyoNightDay, .gruvboxLight, .oneLight,
             .solarizedLight, .kanagawaLotus, .rosePineDawn:
            true
        default:
            false
        }
    }

    var preferredColorScheme: ColorScheme { isLight ? .light : .dark }

    var palette: TerminalThemePalette {
        return switch self {
        case .catppuccin:
            Self.makePalette(
                background: 0x181825, foreground: 0xCDD6F4, accent: 0x89B4FA,
                selection: 0x313244, overlay: 0x6C7086,
                red: 0xF38BA8, green: 0xA6E3A1, yellow: 0xF9E2AF,
                blue: 0x89B4FA, mauve: 0xCBA6F7, teal: 0x94E2D5
            )
        case .catppuccinLatte:
            Self.makePalette(
                background: 0xEFF1F5, foreground: 0x4C4F69, accent: 0x1E66F5,
                selection: 0xCCD0DA, overlay: 0x9CA0B0,
                red: 0xD20F39, green: 0x40A02B, yellow: 0xDF8E1D,
                blue: 0x1E66F5, mauve: 0x8839EF, teal: 0x179299
            )
        case .terminal:
            TerminalThemePalette(
                background: ThemeRGB(0x101014),
                foreground: ThemeRGB(0xEAEAEA),
                cursor: ThemeRGB(0x5E9EFF),
                selection: ThemeRGB(0x303039),
                ansi: Self.colors(
                    0x101014, 0xD95468, 0x68B723, 0xE6C446,
                    0x5E9EFF, 0xA88BFA, 0x55C2D9, 0xEAEAEA,
                    0x66666D, 0xFF6B7A, 0x87D75F, 0xFFE46B,
                    0x83B6FF, 0xC2A7FF, 0x7AD7E8, 0xFFFFFF
                )
            )
        case .tokyoNight:
            Self.makePalette(
                background: 0x1A1B26, foreground: 0xC0CAF5, accent: 0x7AA2F7,
                selection: 0x24283B, overlay: 0x565F89,
                red: 0xF7768E, green: 0x9ECE6A, yellow: 0xE0AF68,
                blue: 0x7AA2F7, mauve: 0xBB9AF7, teal: 0x7DCFFF
            )
        case .tokyoNightDay:
            Self.makePalette(
                background: 0xE1E2E7, foreground: 0x3760BF, accent: 0x2E7DE9,
                selection: 0xC4C8DA, overlay: 0x8990B3,
                red: 0xF52A65, green: 0x587539, yellow: 0x8C6C3E,
                blue: 0x2E7DE9, mauve: 0x7847BD, teal: 0x118C74
            )
        case .dracula:
            Self.makePalette(
                background: 0x282A36, foreground: 0xF8F8F2, accent: 0xBD93F9,
                selection: 0x44475A, overlay: 0x6272A4,
                red: 0xFF5555, green: 0x50FA7B, yellow: 0xF1FA8C,
                blue: 0x8BE9FD, mauve: 0xFF79C6, teal: 0x8BE9FD
            )
        case .nord:
            Self.makePalette(
                background: 0x2E3440, foreground: 0xECEFF4, accent: 0x88C0D0,
                selection: 0x3B4252, overlay: 0x4C566A,
                red: 0xBF616A, green: 0xA3BE8C, yellow: 0xEBCB8B,
                blue: 0x81A1C1, mauve: 0xB48EAD, teal: 0x8FBCBB
            )
        case .gruvbox:
            Self.makePalette(
                background: 0x282828, foreground: 0xEBDBB2, accent: 0xD79921,
                selection: 0x3C3836, overlay: 0x928374,
                red: 0xFB4934, green: 0xB8BB26, yellow: 0xFABD2F,
                blue: 0x83A598, mauve: 0xD3869B, teal: 0x8EC07C
            )
        case .gruvboxLight:
            Self.makePalette(
                background: 0xFBF1C7, foreground: 0x3C3836, accent: 0x076678,
                selection: 0xEBDBB2, overlay: 0x928374,
                red: 0x9D0006, green: 0x79740E, yellow: 0xB57614,
                blue: 0x076678, mauve: 0x8F3F71, teal: 0x427B58
            )
        case .oneDark:
            Self.makePalette(
                background: 0x282C34, foreground: 0xABB2BF, accent: 0x61AFEF,
                selection: 0x2C313A, overlay: 0x5C6370,
                red: 0xE06C75, green: 0x98C379, yellow: 0xE5C07B,
                blue: 0x61AFEF, mauve: 0xC678DD, teal: 0x56B6C2
            )
        case .oneLight:
            Self.makePalette(
                background: 0xFAFAFA, foreground: 0x383A42, accent: 0x4078F2,
                selection: 0xF0F0F1, overlay: 0xA0A1A7,
                red: 0xE45649, green: 0x50A14F, yellow: 0xC18401,
                blue: 0x4078F2, mauve: 0xA626A4, teal: 0x0184BC
            )
        case .solarized:
            Self.makePalette(
                background: 0x002B36, foreground: 0x93A1A1, accent: 0x268BD2,
                selection: 0x073642, overlay: 0x586E75,
                red: 0xDC322F, green: 0x859900, yellow: 0xB58900,
                blue: 0x268BD2, mauve: 0xD33682, teal: 0x2AA198
            )
        case .solarizedLight:
            Self.makePalette(
                background: 0xFDF6E3, foreground: 0x657B83, accent: 0x268BD2,
                selection: 0xEEE8D5, overlay: 0x93A1A1,
                red: 0xDC322F, green: 0x859900, yellow: 0xB58900,
                blue: 0x268BD2, mauve: 0xD33682, teal: 0x2AA198
            )
        case .kanagawa:
            Self.makePalette(
                background: 0x1F1F28, foreground: 0xDCD7BA, accent: 0x7E9CD8,
                selection: 0x2A2A37, overlay: 0x727169,
                red: 0xC34043, green: 0x76946A, yellow: 0xC0A36E,
                blue: 0x7E9CD8, mauve: 0x957FB8, teal: 0x7FB4CA
            )
        case .kanagawaLotus:
            Self.makePalette(
                background: 0xF2ECBC, foreground: 0x545464, accent: 0x4D699B,
                selection: 0xDCD5AC, overlay: 0xA09CAC,
                red: 0xC84053, green: 0x6F894E, yellow: 0x77713F,
                blue: 0x4D699B, mauve: 0x624C83, teal: 0x4E8CA2
            )
        case .rosePine:
            Self.makePalette(
                background: 0x191724, foreground: 0xE0DEF4, accent: 0xC4A7E7,
                selection: 0x1F1D2E, overlay: 0x6E6A86,
                red: 0xEB6F92, green: 0x31748F, yellow: 0xF6C177,
                blue: 0x31748F, mauve: 0xC4A7E7, teal: 0x9CCFD8
            )
        case .rosePineDawn:
            Self.makePalette(
                background: 0xFAF4ED, foreground: 0x464261, accent: 0x907AA9,
                selection: 0xF2E9E1, overlay: 0x9893A5,
                red: 0xB4637A, green: 0x286983, yellow: 0xEA9D34,
                blue: 0x286983, mauve: 0x907AA9, teal: 0x56949F
            )
        case .vesper:
            Self.makePalette(
                background: 0x1A1A1A, foreground: 0xFFFFFF, accent: 0xFFC799,
                selection: 0x232323, overlay: 0x5C5C5C,
                red: 0xFF8080, green: 0x99FFE4, yellow: 0xFFC799,
                blue: 0xB0B0B0, mauve: 0xFFD1A8, teal: 0x66DDCC
            )
        }
    }

    var previewColors: [ThemeRGB] {
        let palette = palette
        return [palette.foreground, palette.cursor, palette.ansi[2], palette.ansi[4], palette.ansi[3]]
    }

    private static func makePalette(
        background: UInt32,
        foreground: UInt32,
        accent: UInt32,
        selection: UInt32,
        overlay: UInt32,
        red: UInt32,
        green: UInt32,
        yellow: UInt32,
        blue: UInt32,
        mauve: UInt32,
        teal: UInt32
    ) -> TerminalThemePalette {
        TerminalThemePalette(
            background: ThemeRGB(background),
            foreground: ThemeRGB(foreground),
            cursor: ThemeRGB(accent),
            selection: ThemeRGB(selection),
            ansi: Self.colors(
                background, red, green, yellow, blue, mauve, teal, foreground,
                overlay, red, green, yellow, blue, mauve, teal, foreground
            )
        )
    }

    private static func colors(_ values: UInt32...) -> [ThemeRGB] {
        values.map(ThemeRGB.init)
    }
}
