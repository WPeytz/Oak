import SwiftUI

struct GoalDetailScreen: View {
    @EnvironmentObject var appState: AppState
    let goal: SavingsGoal
    @Environment(\.dismiss) var dismiss
    
    @State private var showAddSavings = false
    
    // Bottom Sheet Physics State (Ligesom i HomeView)
    enum SheetPosition { case collapsed, expanded }
    @State private var sheetPosition: SheetPosition = .collapsed
    @State private var dragOffset: CGFloat = 0
    
    private let oakBrandGreen = Color(red: 0.2, green: 0.4, blue: 0.2)

    var body: some View {
        ZStack(alignment: .top) {
            // LAYER 1: GRADIENT BACKGROUND (Matcher HomeView)
            LinearGradient(
                colors: [Color.white, Color(red: 130/255, green: 213/255, blue: 120/255)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            // LAYER 2: BACKGROUND TREE
            VStack(spacing: 0) {
                // Vi bruger her din GoalTreeView (voxel-stilen)
                GoalTreeView(progress: goal.progress)
                    .frame(height: 380)
                    .padding(.top, 40)
                
                Spacer()
            }

            // LAYER 3: INTERACTIVE BOTTOM SHEET (Liquid Glass)
            GeometryReader { proxy in
                let fullHeight = proxy.size.height
                let expandedOffset: CGFloat = 100
                let collapsedOffset = fullHeight - 340
                
                let baseOffset = (sheetPosition == .expanded) ? expandedOffset : collapsedOffset
                let currentOffset = baseOffset + dragOffset

                VStack(spacing: 0) {
                    // Pull Handle
                    Capsule()
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 25) {
                            
                            // 1. Goal Title & Progress Score
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Goal Details")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(oakBrandGreen.opacity(0.7))
                                    Text(goal.name)
                                        .font(.title2.weight(.bold))
                                        .foregroundStyle(oakBrandGreen)
                                }
                                Spacer()
                                Text("\(Int(goal.progress * 100))%")
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundStyle(oakBrandGreen)
                            }
                            .padding(24)
                            .liquidGlassCard()
                            .padding(.horizontal, 16)

                            // 2. Add Savings Button
                            Button(action: { showAddSavings = true }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Tilføj opsparing")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(oakBrandGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: oakBrandGreen.opacity(0.3), radius: 10, y: 5)
                            }
                            .padding(.horizontal, 16)

                            // 3. Progress Details Card
                            VStack(spacing: 15) {
                                // Progress Bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(oakBrandGreen.opacity(0.1))
                                        Capsule()
                                            .fill(oakBrandGreen)
                                            .frame(width: geo.size.width * CGFloat(goal.progress))
                                    }
                                }
                                .frame(height: 12)
                                
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Opsparet")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(formatAmount(goal.currentAmount))
                                            .font(.headline)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("Mål")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(formatAmount(goal.targetAmount))
                                            .font(.headline)
                                    }
                                }
                            }
                            .padding(24)
                            .liquidGlassCard()
                            .padding(.horizontal, 16)
                            
                            Color.clear.frame(height: 150)
                        }
                    }
                    .scrollDisabled(sheetPosition == .collapsed || dragOffset > 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .offset(y: currentOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation.height
                            dragOffset = (sheetPosition == .expanded && translation < 0) ? translation * 0.3 : translation
                        }
                        .onEnded { value in
                            let velocity = value.velocity.height
                            let target: SheetPosition = velocity < -500 ? .expanded : (velocity > 500 ? .collapsed : (baseOffset + value.predictedEndTranslation.height < (expandedOffset + collapsedOffset) / 2 ? .expanded : .collapsed))
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                                sheetPosition = target
                                dragOffset = 0
                            }
                        }
                )
            }
            .ignoresSafeArea(edges: .bottom)

            // LAYER 4: BACK BUTTON
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(oakBrandGreen)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 5)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showAddSavings) {
            // Her kalder du dit AddSavingsSheet
            Text("Add Savings Interface")
        }
    }

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        return (formatter.string(from: NSNumber(value: amount)) ?? "0,00") + " kr."
    }
}
