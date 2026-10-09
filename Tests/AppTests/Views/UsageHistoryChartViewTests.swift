import Testing
import Foundation
import SwiftUI
import Domain
import Quotas
@testable import ClaudeBar

/// The daily dashboard's thirty-day chart. It is the one card that used to
/// start at no opacity and fade in from `.onAppear`, so it drew a second or
/// so after the popover opened — and never at all in a still render, which is
/// how the demo's screenshots are taken. The cards beside it draw the moment
/// they are there, and the popover fades itself in as one.
@Suite
struct UsageHistoryChartViewTests {

    @Test @MainActor
    func `should draw the thirty-day chart as soon as it is on screen`() throws {
        let chart = UsageHistoryChartView(days: days())

        let drawn = try #require(rendered(of: chart))
        let blank = try #require(rendered(of: chart.opacity(0)))

        #expect(drawn != blank, "the chart card is blank until it animates in")
    }

    // MARK: - The days a month of a tool's logs reads as

    private func days() -> Quotas.Days {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let stats = (0..<30).map { back -> DailyUsageStat in
            let day = calendar.date(byAdding: .day, value: -back, to: today)!
            guard back > 0 else { return .empty(for: day) }
            return DailyUsageStat(date: day, totalCost: Decimal(back) * 0.42, totalTokens: back * 15_000,
                                  workingTime: Double(back) * 600, sessionCount: 1, inputTokens: back * 12_000,
                                  outputTokens: back * 3_000, cacheReadTokens: back * 200_000,
                                  lines: [ModelUsageLine(model: "claude-sonnet-sample", inputTokens: back * 12_000,
                                                         outputTokens: back * 3_000, totalTokens: back * 15_000,
                                                         cost: Decimal(back) * 0.42)])
        }
        return Quotas.Days(stats, knowsCost: true)
    }

    // MARK: - Rendering

    /// What a view draws, as bytes — two renders the same size that differ
    /// differ in ink, whatever order their pixels are in. The theme is the
    /// popover's own: the environment's default paints nothing, and a card
    /// with no ink cannot be told apart from one nobody can see.
    @MainActor
    private func rendered<V: View>(of view: V) -> Data? {
        let theme = ThemeRegistry.shared.resolveTheme(for: "light", systemColorScheme: .light)
        let renderer = ImageRenderer(content: view
            .frame(width: 400)
            .environment(\.appTheme, theme))
        renderer.scale = 1
        return renderer.cgImage.flatMap { image in
            image.dataProvider.flatMap { (($0.data as NSData?) as Data?) }
        }
    }
}
