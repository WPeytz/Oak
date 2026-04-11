import SwiftUI

struct GoalDetailScreen: View {
    @EnvironmentObject var appState: AppState
    let goal: SavingsGoal
    @Environment(\.dismiss) var dismiss
    
    @State private var currentGoal: SavingsGoal
    @State private var showAddSavings = false
    @State private var treeGrowthBoost: Double = 0
    
    // Bottom Sheet Physics State (Ligesom i HomeView)
    enum SheetPosition { case collapsed, expanded }
    @State private var sheetPosition: SheetPosition = .collapsed
    @State private var dragOffset: CGFloat = 0
    
    private let oakBrandGreen = Color(red: 0.2, green: 0.4, blue: 0.2)

    init(goal: SavingsGoal) {
        self.goal = goal
        _currentGoal = State(initialValue: goal)
    }

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
                GoalTreeView(progress: currentGoal.progress, growthBoost: treeGrowthBoost)
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
                                    Text(currentGoal.name)
                                        .font(.title2.weight(.bold))
                                        .foregroundStyle(oakBrandGreen)
                                }
                                Spacer()
                                Text("\(Int(currentGoal.progress * 100))%")
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
                                    Text("Add savings blabla")
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
                                            .frame(width: geo.size.width * CGFloat(min(currentGoal.progress, 1.0)))
                                    }
                                }
                                .frame(height: 12)
                                
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Saved")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(formatAmount(currentGoal.currentAmount))
                                            .font(.headline)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("Goal")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(formatAmount(currentGoal.targetAmount))
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
            AddSavingsSheet(
                goalName: currentGoal.name,
                remainingAmount: max(currentGoal.targetAmount - currentGoal.currentAmount, 0)
            ) { amount in
                await addSavings(amount)
            }
        }
    }

    private func addSavings(_ amount: Double) async {
        guard amount > 0, let userId = appState.userId else { return }
        let newAmount = currentGoal.currentAmount + amount

        do {
            let updated = try await APIClient.shared.updateSavingsGoal(
                userId: userId,
                goalId: currentGoal.id,
                currentAmount: newAmount
            )
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                currentGoal = updated
                treeGrowthBoost = 0.18
            }
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(.easeOut(duration: 0.35)) {
                    treeGrowthBoost = 0
                }
            }
        } catch {
            // Keep UI unchanged if network update fails.
        }
    }

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        return (formatter.string(from: NSNumber(value: amount)) ?? "0,00") + " kr."
    }
}

struct AddSavingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let goalName: String
    let remainingAmount: Double
    let onSave: (Double) async -> Void

    @State private var rawDigits = ""
    @State private var isSaving = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var amount: Double {
        (Double(rawDigits) ?? 0) / 100
    }

    private var displayAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        return (formatter.string(from: NSNumber(value: amount)) ?? "0,00") + " kr."
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(goalName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(displayAmount)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("Remaining: \(formatAmount(max(remainingAmount - amount, 0))) kr.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9"], id: \.self) { digit in
                        keypadButton(title: digit) { appendDigit(digit) }
                    }

                    keypadButton(title: "C", isAccent: false) {
                        rawDigits = ""
                    }
                    keypadButton(title: "0") { appendDigit("0") }
                    keypadButton(title: "", systemName: "delete.left.fill", isAccent: false) {
                        _ = rawDigits.popLast()
                    }
                }

                Spacer()

                Button {
                    Task {
                        isSaving = true
                        await onSave(amount)
                        isSaving = false
                        dismiss()
                    }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        }
                        Text("Add Savings")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(red: 0.2, green: 0.4, blue: 0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(amount <= 0 || isSaving)
                .opacity((amount <= 0 || isSaving) ? 0.5 : 1)
            }
            .padding(20)
            .navigationTitle("Add Savings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.68)])
    }

    @ViewBuilder
    private func keypadButton(title: String, systemName: String? = nil, isAccent: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let systemName {
                    Image(systemName: systemName)
                        .font(.system(size: 22, weight: .semibold))
                } else {
                    Text(title)
                        .font(.title2.weight(.semibold))
                }
            }
            .foregroundStyle(isAccent ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(Color.black.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func appendDigit(_ digit: String) {
        guard rawDigits.count < 9 else { return }
        if rawDigits == "0" {
            rawDigits = digit
        } else {
            rawDigits += digit
        }
    }
}
