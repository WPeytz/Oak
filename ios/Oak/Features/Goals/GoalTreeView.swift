import SwiftUI

struct GoalTreeView: View {
    let progress: Double // 0.0 til 1.0

    private let pixelSize: CGFloat = 8
    private let gap: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            let centerX = size.width / 2
            let baseY = size.height * 0.9

            // 1. Tegn den nye slanke stamme
            drawSlenderTrunk(context: &context, centerX: centerX, baseY: baseY)

            // 2. Tegn kronen baseret på fremskridt
            // Vi bruger overlappende "skyer" (rektangler) for at ramme Figma-stilen
            drawVoxelCanopy(context: &context, centerX: centerX, baseY: baseY)
        }
        .frame(height: 180)
    }

    // MARK: - New Slender Trunk
    private func drawSlenderTrunk(context: inout GraphicsContext, centerX: CGFloat, baseY: CGFloat) {
        let trunkColor = Color(red: 0.40, green: 0.25, blue: 0.15)
        
        // Stammen er altid 1-2 blokke bred og vokser en smule med progress
        let trunkWidth: CGFloat = 12
        let trunkHeight: CGFloat = progress < 0.2 ? 20 : 35
        
        let trunkRect = CGRect(
            x: centerX - trunkWidth / 2,
            y: baseY - trunkHeight,
            width: trunkWidth,
            height: trunkHeight
        )
        
        context.fill(Path(trunkRect), with: .color(trunkColor))
    }

    // MARK: - Voxel Canopy (Minecraft Style)
    private func drawVoxelCanopy(context: inout GraphicsContext, centerX: CGFloat, baseY: CGFloat) {
        let yAnchor = baseY - (progress < 0.2 ? 25 : 40)
        
        // Farvepalette fra Figma
        let greenDark  = Color(red: 0.18, green: 0.40, blue: 0.22)
        let greenMid   = Color(red: 0.28, green: 0.58, blue: 0.32)
        let greenLight = Color(red: 0.42, green: 0.72, blue: 0.45)

        // Definition af "skyerne" i kronen
        // xOffset, yOffset, size, color, threshold (hvornår den dukker op)
        let canopyParts: [(x: CGFloat, y: CGFloat, s: CGFloat, c: Color, t: Double)] = [
            (0,    0,   45, greenDark,  0.0),  // Grundsten
            (15,  -10,  35, greenMid,   0.15), // Højre side
            (-18, -5,   30, greenDark,  0.30), // Venstre side
            (5,   -25,  38, greenLight, 0.50), // Top midt
            (-12, -20,  25, greenMid,   0.70), // Top venstre
            (18,  -18,  20, greenLight, 0.85), // Detalje højre
            (0,   -35,  22, greenLight, 0.95)  // Toppen af træet
        ]

        for part in canopyParts {
            if progress >= part.t {
                // Beregn størrelse baseret på progress for en blød "vækst" effekt
                let scale = min(1.0, (progress - part.t) / 0.1 + 0.2)
                let currentSize = part.s * CGFloat(scale)
                
                let rect = CGRect(
                    x: centerX + part.x - currentSize / 2,
                    y: yAnchor + part.y - currentSize / 2,
                    width: currentSize,
                    height: currentSize
                )
                
                // Tegn blokken med en lille kant for at fremhæve voxel-looket
                context.fill(Path(rect), with: .color(part.c))
                context.stroke(Path(rect), with: .color(part.c.opacity(0.2)), lineWidth: 1)
            }
        }
    }
}
