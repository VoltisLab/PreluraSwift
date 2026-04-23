import SwiftUI

/// Stylized kit silhouette (generic shirt shape - not club IP). Masked patterns echo each theme’s palette.
struct KitJerseyIconView: View {
    let kit: KitTheme

    private let iconWidth: CGFloat = 56
    private let iconHeight: CGFloat = 46

    var body: some View {
        ZStack {
            KitJerseyPattern(kit: kit)
                .frame(width: iconWidth, height: iconHeight)
                .mask(KitJerseySilhouette())

            KitJerseySilhouette()
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        }
        .frame(width: iconWidth, height: iconHeight)
        .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Silhouette

private struct KitJerseySilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let midX = w / 2

        let neckHalf = w * 0.11
        let topY = h * 0.02
        let shoulderY = h * 0.16
        let sleeveTipY = h * 0.40
        let armpitY = h * 0.34
        let sideInset: CGFloat = w * 0.14
        let hemY = h * 0.94
        let bottomCurve: CGFloat = w * 0.22

        var path = Path()
        path.move(to: CGPoint(x: midX - neckHalf, y: topY))
        path.addQuadCurve(
            to: CGPoint(x: midX + neckHalf, y: topY),
            control: CGPoint(x: midX, y: topY - h * 0.02)
        )
        path.addLine(to: CGPoint(x: w * 0.76, y: shoulderY))
        path.addLine(to: CGPoint(x: w * 0.94, y: sleeveTipY))
        path.addLine(to: CGPoint(x: w * 0.78, y: armpitY))
        path.addLine(to: CGPoint(x: w - sideInset, y: hemY - bottomCurve * 0.35))
        path.addQuadCurve(
            to: CGPoint(x: sideInset, y: hemY - bottomCurve * 0.35),
            control: CGPoint(x: midX, y: hemY + h * 0.04)
        )
        path.addLine(to: CGPoint(x: w * 0.22, y: armpitY))
        path.addLine(to: CGPoint(x: w * 0.06, y: sleeveTipY))
        path.addLine(to: CGPoint(x: w * 0.24, y: shoulderY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Patterns

private struct KitJerseyPattern: View {
    let kit: KitTheme

    var body: some View {
        let p = kit.palette
        switch kit {
        case .blaugranaClassic:
            verticalStripes(colors: [p.primary, p.secondary, p.primary, p.secondary, p.primary], collar: p.accent)
        case .senyeraCatalan:
            verticalStripes(colors: [p.primary, p.secondary, p.primary, p.secondary, p.accent], collar: p.accent.opacity(0.9))
        case .dreamTeamOrange:
            solidBody(p.primary, collar: p.secondary, trim: p.accent)
        case .tealPeacockAway:
            twoToneSleeves(body: p.primary, sleeves: p.secondary, stripe: p.accent)
        case .mintCoastalThird:
            sidePanels(center: p.primary, sides: p.secondary, flash: p.accent)
        case .deepNavyEuropean:
            centerStripe(base: p.primary, stripe: p.secondary, trim: p.accent)
        case .crimsonSenyeraAway:
            chestBand(base: p.primary, band: p.secondary, detail: p.accent)
        case .goldCrestAccents:
            solidBody(p.primary, collar: p.secondary, trim: p.accent.opacity(0.95))
        case .blackoutNightThird:
            blackoutBody(p.primary, accentStripe: p.accent, trim: p.secondary)
        case .softRoseSenyera:
            verticalStripes(colors: [p.secondary, p.primary, p.accent, p.primary, p.secondary], collar: p.accent)
        }
    }

    @ViewBuilder
    private func verticalStripes(colors: [Color], collar: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            HStack(spacing: 0) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, c in
                    Rectangle().fill(c)
                }
            }
            .frame(width: w, height: h)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(collar)
                    .frame(width: w * 0.34, height: h * 0.08)
                    .offset(y: h * 0.04)
            }
        }
    }

    @ViewBuilder
    private func solidBody(_ body: Color, collar: Color, trim: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .top) {
                Rectangle().fill(body)
                Rectangle()
                    .fill(collar)
                    .frame(height: h * 0.22)
                Rectangle()
                    .fill(trim)
                    .frame(height: h * 0.045)
                    .offset(y: h * 0.19)
            }
            .frame(width: w, height: h)
        }
    }

    @ViewBuilder
    private func twoToneSleeves(body: Color, sleeves: Color, stripe: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Rectangle().fill(body)
                HStack(spacing: 0) {
                    Rectangle().fill(sleeves).frame(width: w * 0.22)
                    Spacer(minLength: 0)
                    Rectangle().fill(sleeves).frame(width: w * 0.22)
                }
                Rectangle()
                    .fill(stripe.opacity(0.55))
                    .frame(width: w * 0.08, height: h)
            }
            .frame(width: w, height: h)
        }
    }

    @ViewBuilder
    private func sidePanels(center: Color, sides: Color, flash: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Rectangle().fill(center)
                HStack(spacing: 0) {
                    Rectangle().fill(sides).frame(width: w * 0.18)
                    Spacer(minLength: 0)
                    Rectangle().fill(sides).frame(width: w * 0.18)
                }
                HStack(spacing: w * 0.07) {
                    ForEach(0 ..< 3, id: \.self) { _ in
                        Rectangle().fill(flash.opacity(0.35)).frame(width: w * 0.02)
                    }
                }
            }
            .frame(width: w, height: h)
        }
    }

    @ViewBuilder
    private func centerStripe(base: Color, stripe: Color, trim: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Rectangle().fill(base)
                Rectangle()
                    .fill(stripe)
                    .frame(width: w * 0.16, height: h)
                Capsule()
                    .fill(trim.opacity(0.5))
                    .frame(width: w * 0.42, height: h * 0.06)
                    .offset(y: -h * 0.28)
            }
            .frame(width: w, height: h)
        }
    }

    @ViewBuilder
    private func chestBand(base: Color, band: Color, detail: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Rectangle().fill(base)
                Rectangle()
                    .fill(band)
                    .frame(height: h * 0.16)
                    .offset(y: -h * 0.05)
                Rectangle()
                    .fill(detail)
                    .frame(width: w * 0.12, height: h)
                    .offset(x: w * 0.22)
            }
            .frame(width: w, height: h)
        }
    }

    @ViewBuilder
    private func blackoutBody(_ base: Color, accentStripe: Color, trim: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Rectangle().fill(base)
                Rectangle()
                    .fill(accentStripe.opacity(0.85))
                    .frame(width: w * 0.06, height: h * 0.72)
                    .offset(y: h * 0.06)
                HStack(spacing: 0) {
                    Rectangle().fill(trim.opacity(0.45)).frame(width: w * 0.2)
                    Spacer(minLength: 0)
                    Rectangle().fill(trim.opacity(0.45)).frame(width: w * 0.2)
                }
            }
            .frame(width: w, height: h)
        }
    }
}
