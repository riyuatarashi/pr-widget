import SwiftUI
import UIKit

// MARK: - Palette « Bleuet » (la même que l'icône, Design/icon-final/pr-radar-bleuet.svg)

extension Color {
    static let bleuetIndigo = Color(hex: 0x4F5BD5)
    static let bleuetLavender = Color(hex: 0x8E7CF0)
    static let bleuetSky = Color(hex: 0xBFE3FF)
    static let bleuetGold = Color(hex: 0xFFC857)
    static let bleuetOlive = Color(hex: 0x55703A)
    static let bleuetCream = Color(hex: 0xFFF3E6)

    /// Accent : indigo sur fond clair, lavande sur fond sombre (StandBy) pour rester lisible.
    static let prAccent = Color(light: 0x4F5BD5, dark: 0x9D8FF5)
    /// Texte posé sur l'accent (badge « NOUVELLE PR »).
    static let prOnAccent = Color(light: 0xFFFFFF, dark: 0x1B1640)
    /// Vert feuille, pour les états « tout va bien ».
    static let prLeaf = Color(light: 0x55703A, dark: 0x9BBF73)

    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Campanule

/// La fleur-cloche de l'icône, dessinée à partir des mêmes tracés que le SVG.
/// Le point d'attache à la tige est en haut au centre : idéal comme ancre pour la faire se balancer.
struct Campanula: View {
    /// Rotation du battant (en degrés), pour qu'il suive le balancement avec un temps de retard.
    var clapperSwing: Double = 0

    var body: some View {
        ZStack {
            ZStack {
                CampanulaShape(.clapperStem).fill(Color.bleuetOlive)
                CampanulaShape(.clapper).fill(Color.bleuetGold)
            }
            .rotationEffect(.degrees(clapperSwing), anchor: CampanulaShape.mouthAnchor)

            CampanulaShape(.middle).fill(Color.bleuetSky)
            CampanulaShape(.left).fill(Color.bleuetIndigo)
            CampanulaShape(.right).fill(Color.bleuetLavender)
        }
        .aspectRatio(CampanulaShape.aspectRatio, contentMode: .fit)
    }
}

struct CampanulaShape: Shape {
    enum Part {
        case middle, left, right, clapperStem, clapper
    }

    /// Repère du SVG : x de -230 à 230, y de -10 à 550.
    static let aspectRatio: CGFloat = 460 / 560
    static let mouthAnchor = UnitPoint(x: 0.5, y: (430 + 10) / 560)

    let part: Part

    init(_ part: Part) {
        self.part = part
    }

    private typealias Curve = (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)

    private static let middle: (start: CGPoint, curves: [Curve]) = (CGPoint(x: 0, y: 6), [
        (70, 10, 104, 80, 106, 170), (110, 270, 150, 336, 200, 398), (140, 422, 76, 440, 0, 444),
        (-76, 440, -140, 422, -200, 398), (-150, 336, -110, 270, -106, 170), (-104, 80, -70, 10, 0, 6),
    ])

    private static let leftPetal: (start: CGPoint, curves: [Curve]) = (CGPoint(x: 0, y: 0), [
        (-70, 4, -110, 74, -114, 164), (-118, 264, -160, 334, -222, 394),
        (-164, 414, -104, 422, -46, 414), (-34, 300, -22, 120, 0, 0),
    ])

    func path(in rect: CGRect) -> Path {
        let point = { (x: CGFloat, y: CGFloat) in
            CGPoint(x: rect.minX + (x + 230) / 460 * rect.width, y: rect.minY + (y + 10) / 560 * rect.height)
        }
        let scale = rect.width / 460

        var path = Path()
        func trace(_ shape: (start: CGPoint, curves: [Curve]), mirrored: Bool = false) {
            let m: CGFloat = mirrored ? -1 : 1
            path.move(to: point(m * shape.start.x, shape.start.y))
            for c in shape.curves {
                path.addCurve(
                    to: point(m * c.4, c.5),
                    control1: point(m * c.0, c.1),
                    control2: point(m * c.2, c.3)
                )
            }
            path.closeSubpath()
        }

        switch part {
        case .middle:
            trace(Self.middle)
        case .left:
            trace(Self.leftPetal)
        case .right:
            trace(Self.leftPetal, mirrored: true)
        case .clapperStem:
            let top = point(-11, 420)
            path.addRoundedRect(
                in: CGRect(x: top.x, y: top.y, width: 22 * scale, height: 76 * scale),
                cornerSize: CGSize(width: 11 * scale, height: 11 * scale)
            )
        case .clapper:
            let center = point(0, 512)
            let radius = 34 * scale
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
        return path
    }
}
