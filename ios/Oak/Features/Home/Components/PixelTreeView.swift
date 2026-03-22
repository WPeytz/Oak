import SwiftUI

struct PixelTreeView: View {
    let healthScore: Int // 0-100
    let treeState: String

    private let pixelSize: CGFloat = 8
    private let gap: CGFloat = 1

    var body: some View {
        ZStack {
            // City skyline silhouette
            CitylineView()
                .offset(y: 60)

            // Tree
            Canvas { context, size in
                let centerX = size.width / 2
                let baseY = size.height * 0.85

                // Draw trunk
                drawTrunk(context: &context, centerX: centerX, baseY: baseY)

                // Draw canopy or bare branches based on health
                if healthScore > 20 {
                    drawCanopy(context: &context, centerX: centerX, baseY: baseY)
                } else {
                    drawBareBranches(context: &context, centerX: centerX, baseY: baseY)
                }

                // Falling leaves
                if healthScore < 70 && healthScore > 10 {
                    drawFallingLeaves(context: &context, centerX: centerX, baseY: baseY)
                }

                // Birds on bare tree
                if healthScore <= 20 {
                    drawBirds(context: &context, centerX: centerX, baseY: baseY)
                }
            }
            .frame(height: 220)
        }
    }

    // MARK: - Trunk

    private func drawTrunk(context: inout GraphicsContext, centerX: CGFloat, baseY: CGFloat) {
        let trunkColor = healthScore > 20 ? Color(red: 0.45, green: 0.3, blue: 0.15) : Color(red: 0.5, green: 0.35, blue: 0.2)
        let ps = pixelSize

        // Main trunk
        for row in 0..<8 {
            let y = baseY - CGFloat(row) * (ps + gap) - ps
            for col in -1...1 {
                let x = centerX + CGFloat(col) * (ps + gap) - ps / 2
                context.fill(Path(CGRect(x: x, y: y, width: ps, height: ps)), with: .color(trunkColor))
            }
        }

        // Roots
        let rootY = baseY
        for col in [-3, -2, 2, 3] {
            let x = centerX + CGFloat(col) * (ps + gap) - ps / 2
            context.fill(Path(CGRect(x: x, y: rootY - ps, width: ps, height: ps)), with: .color(trunkColor.opacity(0.7)))
        }
    }

    // MARK: - Canopy (living tree)

    private func drawCanopy(context: inout GraphicsContext, centerX: CGFloat, baseY: CGFloat) {
        let density = Double(min(100, max(20, healthScore))) / 100.0
        let ps = pixelSize

        // Canopy layers - pixel art style
        let canopyData: [(row: Int, cols: ClosedRange<Int>)] = [
            (16, -2...2),
            (15, -4...4),
            (14, -5...5),
            (13, -6...6),
            (12, -7...7),
            (11, -8...8),
            (10, -8...8),
            (9, -7...7),
            (8, -6...6),
        ]

        for layer in canopyData {
            let y = baseY - CGFloat(layer.row) * (ps + gap) - ps
            for col in layer.cols {
                // Skip some pixels based on health to create sparse look
                let shouldDraw = Double.random(in: 0...1) < density
                if shouldDraw {
                    let x = centerX + CGFloat(col) * (ps + gap) - ps / 2
                    let shade = Double.random(in: 0.7...1.0)
                    let green: Color
                    if healthScore >= 80 {
                        green = Color(red: 0.1 * shade, green: (0.55 + 0.15 * shade), blue: 0.1 * shade)
                    } else if healthScore >= 50 {
                        green = Color(red: 0.2 * shade, green: (0.5 + 0.1 * shade), blue: 0.1 * shade)
                    } else {
                        green = Color(red: (0.4 + 0.2 * shade), green: (0.4 + 0.1 * shade), blue: 0.05)
                    }
                    context.fill(Path(CGRect(x: x, y: y, width: ps, height: ps)), with: .color(green))
                }
            }
        }
    }

    // MARK: - Bare branches (dead tree)

    private func drawBareBranches(context: inout GraphicsContext, centerX: CGFloat, baseY: CGFloat) {
        let branchColor = Color(red: 0.5, green: 0.35, blue: 0.2)
        let ps = pixelSize

        // Left branch
        let leftBranch: [(Int, Int)] = [
            (-1, 9), (-2, 10), (-3, 11), (-4, 12), (-5, 13),
            (-6, 13), (-7, 14), (-4, 13), (-3, 14), (-2, 15),
        ]
        for (col, row) in leftBranch {
            let x = centerX + CGFloat(col) * (ps + gap) - ps / 2
            let y = baseY - CGFloat(row) * (ps + gap) - ps
            context.fill(Path(CGRect(x: x, y: y, width: ps, height: ps)), with: .color(branchColor))
        }

        // Right branch
        let rightBranch: [(Int, Int)] = [
            (1, 9), (2, 10), (3, 11), (4, 12), (5, 12),
            (6, 13), (3, 12), (4, 13), (5, 14),
        ]
        for (col, row) in rightBranch {
            let x = centerX + CGFloat(col) * (ps + gap) - ps / 2
            let y = baseY - CGFloat(row) * (ps + gap) - ps
            context.fill(Path(CGRect(x: x, y: y, width: ps, height: ps)), with: .color(branchColor))
        }

        // Top
        let top: [(Int, Int)] = [
            (0, 9), (0, 10), (0, 11), (0, 12), (0, 13), (-1, 14), (-1, 15),
        ]
        for (col, row) in top {
            let x = centerX + CGFloat(col) * (ps + gap) - ps / 2
            let y = baseY - CGFloat(row) * (ps + gap) - ps
            context.fill(Path(CGRect(x: x, y: y, width: ps, height: ps)), with: .color(branchColor))
        }
    }

    // MARK: - Falling leaves

    private func drawFallingLeaves(context: inout GraphicsContext, centerX: CGFloat, baseY: CGFloat) {
        let ps = pixelSize * 0.7
        let leafColor = healthScore > 40
            ? Color(red: 0.2, green: 0.6, blue: 0.15)
            : Color(red: 0.6, green: 0.4, blue: 0.1)

        let leaves: [(CGFloat, CGFloat)] = [
            (-50, 30), (60, 45), (-30, 60), (45, 70), (-55, 50),
        ]
        for (dx, dy) in leaves.prefix(max(1, (100 - healthScore) / 15)) {
            let x = centerX + dx
            let y = baseY - 80 + dy
            context.fill(Path(CGRect(x: x, y: y, width: ps, height: ps)), with: .color(leafColor.opacity(0.8)))
        }
    }

    // MARK: - Birds

    private func drawBirds(context: inout GraphicsContext, centerX: CGFloat, baseY: CGFloat) {
        let birdColor = Color(red: 0.2, green: 0.2, blue: 0.2)
        let ps = pixelSize * 0.6

        let birdPositions: [(CGFloat, CGFloat)] = [
            (-55, -130), (50, -120), (-20, -140),
        ]
        for (dx, dy) in birdPositions {
            let x = centerX + dx
            let y = baseY + dy
            // Simple pixel bird: V shape
            context.fill(Path(CGRect(x: x - ps, y: y - ps, width: ps, height: ps)), with: .color(birdColor))
            context.fill(Path(CGRect(x: x, y: y, width: ps, height: ps)), with: .color(birdColor))
            context.fill(Path(CGRect(x: x + ps, y: y - ps, width: ps, height: ps)), with: .color(birdColor))
        }
    }
}

// MARK: - City skyline

struct CitylineView: View {
    var body: some View {
        Canvas { context, size in
            let color = Color.gray.opacity(0.12)
            let w = size.width
            let baseY = size.height * 0.7

            // Buildings as simple rectangles
            let buildings: [(x: CGFloat, width: CGFloat, height: CGFloat)] = [
                (0.05, 0.06, 0.25),
                (0.12, 0.04, 0.35),
                (0.17, 0.07, 0.20),
                (0.26, 0.05, 0.40),
                (0.32, 0.03, 0.30),
                (0.38, 0.06, 0.22),
                (0.46, 0.04, 0.38),
                (0.52, 0.07, 0.28),
                (0.60, 0.03, 0.18),
                (0.65, 0.05, 0.32),
                (0.72, 0.06, 0.24),
                (0.80, 0.04, 0.36),
                (0.86, 0.05, 0.20),
                (0.92, 0.06, 0.28),
            ]

            for b in buildings {
                let rect = CGRect(
                    x: b.x * w,
                    y: baseY - b.height * size.height,
                    width: b.width * w,
                    height: b.height * size.height + 20
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(height: 120)
    }
}
