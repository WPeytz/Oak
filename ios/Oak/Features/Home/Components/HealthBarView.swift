import SwiftUI

struct DayHealth: Identifiable {
    let id: Int // index
    let date: Date
    let healthScore: Int // 0-100
}

func computeDailyHealth(
    transactions: [Transaction],
    fallbackScore: Int
) -> [DayHealth] {
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: transactions) { txn in
        calendar.startOfDay(for: txn.bookedAt)
    }
    let sortedDates = grouped.keys.sorted()
    guard let firstDate = sortedDates.first,
          let lastDate = sortedDates.last else {
        return [DayHealth(id: 0, date: Date(), healthScore: fallbackScore)]
    }

    var days: [DayHealth] = []
    var currentDate = firstDate
    var idx = 0
    var cumulativeIncome: Double = 0
    var cumulativeSpending: Double = 0

    while currentDate <= lastDate {
        if let dayTxns = grouped[currentDate] {
            for txn in dayTxns {
                let amount = NSDecimalNumber(decimal: txn.amount).doubleValue
                if amount > 0 { cumulativeIncome += amount }
                else { cumulativeSpending += abs(amount) }
            }
        }

        let score: Int
        if cumulativeIncome > 0 {
            let ratio = cumulativeSpending / cumulativeIncome
            score = max(0, min(100, Int((1.0 - ratio) * 100)))
        } else if cumulativeSpending > 0 {
            score = 0
        } else {
            score = 100
        }

        days.append(DayHealth(id: idx, date: currentDate, healthScore: score))
        currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        idx += 1
    }

    let today = calendar.startOfDay(for: Date())
    if let last = days.last, last.date < today {
        days.append(DayHealth(id: idx, date: today, healthScore: last.healthScore))
    }
    return days
}

// MARK: - Scroll behavior that does nothing (no snapping)
struct PassthroughScrollBehavior: ScrollTargetBehavior {
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {}
}

struct HealthBarView: View {
    let healthScore: Int
    let transactions: [Transaction]
    let onDateSelected: (Date, Int) -> Void
    @Binding var scrollTarget: Int?
    var isPlaying: Bool = false

    @State private var cachedDailyHealth: [DayHealth] = []

    private var dailyHealth: [DayHealth] { cachedDailyHealth }

    private let primaryBarColor = Color(red: 92/255, green: 157/255, blue: 84/255)
    private let barWidth: CGFloat = 5
    private let spacing: CGFloat = 6

    // Height settings
    private let minBarHeight: CGFloat = 10.0
    private let maxBarHeight: CGFloat = 50.0

    var body: some View {
        GeometryReader { container in
            let midX = container.size.width / 2

            timelineScroll(midX: midX)
        }
        .frame(height: maxBarHeight * 1.8)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.2),
                    .init(color: .black, location: 0.8),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .onAppear {
            cachedDailyHealth = computeDailyHealth(transactions: transactions, fallbackScore: healthScore)
            if scrollTarget == nil {
                scrollTarget = max(0, dailyHealth.count - 1)
            }
        }
        .onChange(of: transactions.count) {
            cachedDailyHealth = computeDailyHealth(transactions: transactions, fallbackScore: healthScore)
            scrollTarget = max(0, dailyHealth.count - 1)
        }
        .onChange(of: scrollTarget) { _, newValue in
            guard !isPlaying else { return }
            guard let idx = newValue,
                  idx >= 0, idx < dailyHealth.count else { return }
            let day = dailyHealth[idx]
            onDateSelected(day.date, day.healthScore)
        }
    }

    @ViewBuilder
    private func timelineScroll(midX: CGFloat) -> some View {
        let scroll = ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .center, spacing: spacing) {
                Color.clear.frame(width: midX - (barWidth / 2))

                ForEach(dailyHealth) { day in
                    barView(day: day, midX: midX)
                        .id(day.id)
                }

                Color.clear.frame(width: midX - (barWidth / 2))
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrollTarget)
        .allowsHitTesting(!isPlaying)
        .sensoryFeedback(.selection, trigger: scrollTarget)

        if isPlaying {
            scroll.scrollTargetBehavior(PassthroughScrollBehavior())
        } else {
            scroll.scrollTargetBehavior(.viewAligned)
        }
    }

    private func barView(day: DayHealth, midX: CGFloat) -> some View {
        let normalizedHeight = minBarHeight + (maxBarHeight - minBarHeight) * CGFloat(day.healthScore) / 100.0
        return Capsule()
            .fill(primaryBarColor)
            .frame(width: barWidth, height: normalizedHeight)
            .visualEffect { content, proxy in
                let frame = proxy.frame(in: .scrollView)
                let distance = abs(frame.midX - midX)
                let influence = max(0, 1.0 - (distance / 35))
                let needleFactor = pow(influence, 1.2)
                let normalizedDistance = min(distance / (midX * 0.9), 1.0)
                let blurAmount = normalizedDistance * 3.0
                return content
                    .scaleEffect(y: 1.0 + (0.5 * needleFactor), anchor: .center)
                    .blur(radius: blurAmount)
                    .opacity(0.4 + (0.6 * (1.0 - normalizedDistance)))
            }
    }
}

#Preview {
    HealthBarView(
        healthScore: 50,
        transactions: [],
        onDateSelected: { _, _ in },
        scrollTarget: .constant(nil)
    )
    .frame(width: 350, height: 100)
    .background(Color.gray.opacity(0.1))
}
