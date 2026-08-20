import AppKit
import SwiftUI

struct HerdrLogoMarkView: View {
    let color: Color
    var size: CGFloat = 20

    var body: some View {
        Group {
            if let image = Self.logoImage {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .scaledToFit()
                    .foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private static let logoImage: NSImage? = {
        let packagedURL = Bundle.main.url(
            forResource: "HerdrLogoMark",
            withExtension: "svg"
        )
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/HerdrLogoMark.svg")
        guard let url = packagedURL ?? (FileManager.default.fileExists(atPath: sourceURL.path) ? sourceURL : nil),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.isTemplate = true
        return image
    }()
}
