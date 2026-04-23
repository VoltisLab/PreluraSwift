import SwiftUI

/// Distinct decorative pattern per kit (subtle; respects “patterns off” via parent).
struct KitThemePatternLayer: View {
    let kit: KitTheme
    let palette: ThemePalette

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                switch kit {
                case .blaugranaClassic:
                    verticalStripeField(width: size.width, height: size.height, a: palette.primary, b: palette.secondary)
                case .senyeraCatalan:
                    horizontalStripeField(height: size.height, width: size.width, a: palette.primary, b: palette.secondary)
                case .dreamTeamOrange:
                    sunburstField(size: size, core: palette.primary, ray: palette.accent)
                case .tealPeacockAway:
                    diagonalWeaveField(size: size, a: palette.primary, b: palette.accent)
                case .mintCoastalThird:
                    dotLatticeField(size: size, dot: palette.secondary, halo: palette.accent)
                case .deepNavyEuropean:
                    gridField(size: size, line: palette.accent.opacity(0.55))
                case .crimsonSenyeraAway:
                    chevronField(size: size, a: palette.secondary, b: palette.accent)
                case .goldCrestAccents:
                    diagonalGoldField(size: size, gold: palette.accent, deep: palette.secondary)
                case .blackoutNightThird:
                    scanlineField(size: size, line: palette.accent)
                case .softRoseSenyera:
                    bubbleField(size: size, rose: palette.primary, gold: palette.accent)
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private func verticalStripeField(width: CGFloat, height: CGFloat, a: Color, b: Color) -> some View {
        HStack(spacing: 0) {
            ForEach(0 ..< 24, id: \.self) { i in
                Rectangle()
                    .fill(i.isMultiple(of: 2) ? a.opacity(0.35) : b.opacity(0.28))
                    .frame(width: width / 24)
            }
        }
        .frame(width: width, height: height)
        .rotationEffect(.degrees(-8))
        .offset(x: -width * 0.06, y: height * 0.05)
    }

    private func horizontalStripeField(height: CGFloat, width: CGFloat, a: Color, b: Color) -> some View {
        VStack(spacing: 0) {
            ForEach(0 ..< 18, id: \.self) { i in
                Rectangle()
                    .fill(i.isMultiple(of: 2) ? a.opacity(0.32) : b.opacity(0.26))
                    .frame(height: height / 18)
            }
        }
        .frame(width: width, height: height)
        .rotationEffect(.degrees(4))
    }

    private func sunburstField(size: CGSize, core: Color, ray: Color) -> some View {
        Canvas { ctx, sz in
            let c = CGPoint(x: sz.width * 0.2, y: sz.height * 0.15)
            for i in 0 ..< 14 {
                let t = CGFloat(i) / 14 * .pi * 2
                let inner = CGPoint(x: c.x + cos(t) * 20, y: c.y + sin(t) * 20)
                let outer = CGPoint(x: c.x + cos(t) * max(sz.width, sz.height), y: c.y + sin(t) * max(sz.width, sz.height))
                var p = Path()
                p.move(to: inner)
                p.addLine(to: outer)
                ctx.stroke(p, with: .color(ray.opacity(0.22)), lineWidth: 2)
            }
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 28, y: c.y - 28, width: 56, height: 56)), with: .color(core.opacity(0.25)))
        }
        .frame(width: size.width, height: size.height)
    }

    private func diagonalWeaveField(size: CGSize, a: Color, b: Color) -> some View {
        Canvas { ctx, sz in
            let step: CGFloat = 26
            var x: CGFloat = -sz.height
            while x < sz.width + sz.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x + sz.height, y: sz.height))
                ctx.stroke(p, with: .color(x.truncatingRemainder(dividingBy: step * 2) < step ? a.opacity(0.22) : b.opacity(0.18)), lineWidth: 2)
                x += step
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func dotLatticeField(size: CGSize, dot: Color, halo: Color) -> some View {
        Canvas { ctx, sz in
            let step: CGFloat = 34
            var y: CGFloat = 0
            while y < sz.height + step {
                var x: CGFloat = (y.truncatingRemainder(dividingBy: step * 2) < step ? 0 : step / 2)
                while x < sz.width + step {
                    let r: CGFloat = 3
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(dot.opacity(0.35)))
                    ctx.stroke(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)), with: .color(halo.opacity(0.12)), lineWidth: 1)
                    x += step
                }
                y += step
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func gridField(size: CGSize, line: Color) -> some View {
        Canvas { ctx, sz in
            let step: CGFloat = 48
            var x: CGFloat = 0
            while x < sz.width {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: sz.height))
                ctx.stroke(p, with: .color(line.opacity(0.2)), lineWidth: 1)
                x += step
            }
            var y: CGFloat = 0
            while y < sz.height {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: sz.width, y: y))
                ctx.stroke(p, with: .color(line.opacity(0.16)), lineWidth: 1)
                y += step
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func chevronField(size: CGSize, a: Color, b: Color) -> some View {
        Canvas { ctx, sz in
            let h: CGFloat = 36
            var y: CGFloat = -h
            var toggle = false
            while y < sz.height + h {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: sz.width * 0.5, y: y + h * 0.55))
                p.addLine(to: CGPoint(x: sz.width, y: y))
                ctx.stroke(p, with: .color((toggle ? a : b).opacity(0.2)), lineWidth: 2)
                y += h * 0.85
                toggle.toggle()
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func diagonalGoldField(size: CGSize, gold: Color, deep: Color) -> some View {
        Canvas { ctx, sz in
            let step: CGFloat = 70
            var x: CGFloat = -sz.height
            while x < sz.width + sz.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x + sz.height * 0.45, y: sz.height))
                ctx.stroke(p, with: .color(x.truncatingRemainder(dividingBy: step * 2) < step ? gold.opacity(0.28) : deep.opacity(0.18)), lineWidth: 1.5)
                x += 22
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func scanlineField(size: CGSize, line: Color) -> some View {
        Canvas { ctx, sz in
            var y: CGFloat = 0
            while y < sz.height {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: sz.width, y: y))
                ctx.stroke(p, with: .color(line.opacity(0.14)), lineWidth: 1)
                y += 4
            }
        }
        .frame(width: size.width, height: size.height)
        .rotationEffect(.degrees(-2))
    }

    private func bubbleField(size: CGSize, rose: Color, gold: Color) -> some View {
        Canvas { ctx, sz in
            let spots: [CGPoint] = [
                CGPoint(x: sz.width * 0.15, y: sz.height * 0.2),
                CGPoint(x: sz.width * 0.82, y: sz.height * 0.18),
                CGPoint(x: sz.width * 0.55, y: sz.height * 0.62),
                CGPoint(x: sz.width * 0.28, y: sz.height * 0.78),
                CGPoint(x: sz.width * 0.72, y: sz.height * 0.88),
            ]
            for (i, c) in spots.enumerated() {
                let r: CGFloat = 40 + CGFloat(i) * 8
                let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color((i.isMultiple(of: 2) ? rose : gold).opacity(0.12)))
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
