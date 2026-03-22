import SwiftUI

struct GoalTreeView: View {
    let progress: Double // 0.0 to 1.0

    private let pixelSize: CGFloat = 9
    private let gap: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            let centerX = size.width / 2
            let baseY = size.height * 0.88

            drawTrunk(context: &context, centerX: centerX, baseY: baseY)

            if progress < 0.15 {
                drawSapling(context: &context, centerX: centerX, baseY: baseY)
            } else if progress < 0.5 {
                drawSmallTree(context: &context, centerX: centerX, baseY: baseY)
            } else if progress < 0.85 {
                drawMediumTree(context: &context, centerX: centerX, baseY: baseY)
            } else {
                drawMatureTree(context: &context, centerX: centerX, baseY: baseY)
            }
        }
        .frame(height: 200)
    }

    // MARK: - Trunk

    private func drawTrunk(context: inout GraphicsContext, centerX: CGFloat, baseY: CGFloat) {
        let trunkColor = Color(red: 0.55, green: 0.35, blue: 0.15)
        let ps = pixelSize
        let trunkHeight = progress < 0.15 ? 3 : (progress < 0.5 ? 5 : 7)

        for row in 0..<trunkHeight {
            let y = baseY - CGFloat(row) * (ps + gap) - ps
            let width = progress < 0.5 ? 1 : 2
            for col in (-width / 2)...(width / 2) {
                let x = centerX + CGFloat(col) * (ps + gap) - ps / 2
                context.fill(Path(CGRect(x: x, y: y, width: ps, height: ps)), with: .color(trunkColor))
            }
        }
    }

    // MARK: - Sapling (0-15%)

    private func drawSapling(context: inout GraphicsContext, centerX: CGFloat, baseY: CGFloat) {
        let ps = pixelSize
        let green = Color(red: 0.2, green: 0.6, blue: 0.2)

        // Just a few leaves at the top
        let leaves: [(Int, Int)] = [
            (0, 4), (-1, 4), (1, 4), (0, 5),
        ]
        for (col, row) in leaves {
            let x = centerX + CGFloat(col) * (ps + gap) - ps / 2
            let y = baseY - CGFloat(row) * (ps + gap) - ps
            context.fill(Path(CGRect(x: x, y: y, width: ps, height: ps)), with: .color(green.opacity(0.9)))
        }
    }

    // MARK: - Small tree (15-50%)

    private func drawSmallTree(context: inout GraphicsContext, centerX: CGFloat, baseY: CGFloat) {
        let ps = pixelSize

        let canopy: [(row: Int, cols: ClosedRange<Int>)] = [
            (8, -1...1),
            (7, -2...2),
            (6, -3...3),
            (5, -2...2),
        ]

        for layer in canopy {
            let y = baseY - CGFloat(layer.row) * (ps + gap) - ps
            for col in layer.cols {
                let shade = Double.random(in: 0.8...1.0)
                let green = Color(red: 0.1, green: 0.5 + 0.15 * shade, blue: 0.12)
                let x = centerX + CGFloat(col) * (ps + gap) - ps / 2
                context.fill(Path(CGRect(x: x, y: y, width: ps, height: ps)), with: .color(green))
            }
        }
    }

    // MARK: - Medium tree (50-85%)

    private func drawMediumTree(context: inout GraphicsContext, centerX: CGFloat, baseY: CGFloat) {
        let ps = pixelSize

        let canopy: [(row: Int, cols: ClosedRange<Int>)] = [
            (12, -1...1),
            (11, -3...3),
            (10, -4...4),
            (9, -5...5),
            (8, -5...5),
            (7, -4...4),
        ]

        for layer in canopy {
            let y = baseY - CGFloat(layer.row) * (ps + gap) - ps
            for col in layer.cols {
                let shade = Double.random(in: 0.75...1.0)
                let green = Color(red: 0.08, green: 0.5 + 0.18 * shade, blue: 0.1)
                let x = centerX + CGFloat(col) * (ps + gap) - ps / 2
                context.fill(Path(CGRect(x: x, y: y, width: ps, height: ps)), with: .color(green))
            }
        }
    }

    // MARK: - Mature tree (85%+)

    private func drawMatureTree(context: inout GraphicsContext, centerX: CGFloat, baseY: CGFloat) {
        let ps = pixelSize

        let canopy: [(row: Int, cols: ClosedRange<Int>)] = [
            (15, -1...1),
            (14, -3...3),
            (13, -5...5),
            (12, -6...6),
            (11, -7...7),
            (10, -7...7),
            (9, -6...6),
            (8, -5...5),
            (7, -4...4),
        ]

        for layer in canopy {
            let y = baseY - CGFloat(layer.row) * (ps + gap) - ps
            for col in layer.cols {
                let shade = Double.random(in: 0.7...1.0)
                let green = Color(red: 0.06, green: 0.48 + 0.2 * shade, blue: 0.08)
                let x = centerX + CGFloat(col) * (ps + gap) - ps / 2
                context.fill(Path(CGRect(x: x, y: y, width: ps, height: ps)), with: .color(green))
            }
        }
    }
}
