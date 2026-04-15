import SwiftUI

struct GoalTreeView: View {
    let progress: Double
    var growthBoost: Double = 0

    private var healthPercentage: CGFloat {
        CGFloat(min(max(progress + growthBoost, 0), 1))
    }

    var body: some View {
        VoxelTreeView(healthPercentage: healthPercentage)
            .allowsHitTesting(false)
    }
}
