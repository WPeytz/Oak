import SwiftUI

struct GoalTreeView: View {
    let progress: Double // 0.0 til 1.0

    // Animation: Gør at træet vokser blødt i stedet for at hoppe
    var animatedProgress: Double {
        return progress
    }

    var body: some View {
        Canvas { context, size in
            let centerX = size.width / 2
            let baseY = size.height * 0.9

            // 1. Stammen
            drawSlenderTrunk(context: &context, centerX: centerX, baseY: baseY)

            // 2. Kronen (Voxel Style)
            drawVoxelCanopy(context: &context, centerX: centerX, baseY: baseY)
        }
        .frame(height: 200) // Lidt højere for at give plads til det fuldvoksne træ
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)
    }

    private func drawSlenderTrunk(context: inout GraphicsContext, centerX: CGFloat, baseY: CGFloat) {
        let trunkColor = Color(red: 0.40, green: 0.25, blue: 0.15)
        
        // Stammen vokser i højden baseret på progress
        let trunkWidth: CGFloat = 12
        let trunkHeight: CGFloat = progress < 0.2 ? 20 : (20 + (CGFloat(progress) * 25))
        
        let trunkRect = CGRect(
            x: centerX - trunkWidth / 2,
            y: baseY - trunkHeight,
            width: trunkWidth,
            height: trunkHeight
        )
        
        context.fill(Path(trunkRect), with: .color(trunkColor))
    }

    private func drawVoxelCanopy(context: inout GraphicsContext, centerX: CGFloat, baseY: CGFloat) {
        // yAnchor følger stammens top
        let trunkHeight: CGFloat = progress < 0.2 ? 20 : (20 + (CGFloat(progress) * 25))
        let yAnchor = baseY - trunkHeight
        
        let greenDark  = Color(red: 0.18, green: 0.40, blue: 0.22)
        let greenMid   = Color(red: 0.28, green: 0.58, blue: 0.32)
        let greenLight = Color(red: 0.42, green: 0.72, blue: 0.45)

        let canopyParts: [(x: CGFloat, y: CGFloat, s: CGFloat, c: Color, t: Double)] = [
            (0,    0,   45, greenDark,  0.0),
            (15,  -10,  35, greenMid,   0.15),
            (-18, -5,   30, greenDark,  0.30),
            (5,   -25,  38, greenLight, 0.50),
            (-12, -20,  25, greenMid,   0.70),
            (18,  -18,  20, greenLight, 0.85),
            (0,   -35,  22, greenLight, 0.95)
        ]

        for part in canopyParts {
            if progress >= part.t {
                // Udregn individuel part-scale for "pop-up" effekt
                let partProgress = min(1.0, (progress - part.t) / 0.1)
                let scale = partProgress
                let currentSize = part.s * CGFloat(scale)
                
                let rect = CGRect(
                    x: centerX + part.x - currentSize / 2,
                    y: yAnchor + part.y - currentSize / 2,
                    width: currentSize,
                    height: currentSize
                )
                
                context.fill(Path(rect), with: .color(part.c))
                context.stroke(Path(rect), with: .color(.black.opacity(0.1)), lineWidth: 0.5)
            }
        }
    }
}
