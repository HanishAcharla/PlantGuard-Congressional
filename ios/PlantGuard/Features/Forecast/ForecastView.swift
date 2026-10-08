import Charts
import SwiftUI

struct ForecastView: View {
    private enum Window: String, CaseIterable { case now = "Next 10 days", spring = "Spring preview" }

    @AppStorage("climateID") private var climateID = ClimateProfile.appleHill.id
    @State private var window: Window = .now
    @State private var selectedDay: Date?

    private var climate: ClimateProfile { ClimateProfile.with(id: climateID) }

    private var anchor: Date {
        switch window {
        case .now: return .now
        case .spring:
            let cal = Calendar.current
            let year = cal.component(.year, from: .now) + (cal.component(.month, from: .now) > 5 ? 1 : 0)
            return cal.date(from: DateComponents(year: year, month: 4, day: 14))!
        }
    }

    var body: some View {
        let days = WeatherSimulator.days(around: anchor, past: window == .now ? 2 : 0, future: 9, climate: climate)
        let focusDay = days.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDay ?? anchor) } ?? days[min(2, days.count - 1)]

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label(climate.name, systemImage: "location.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("Simulated weather").font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .foregroundStyle(Theme.amber)
                        .background(Capsule().fill(Theme.amber.opacity(0.14)))
                }
                Picker("", selection: $window) { ForEach(Window.allCases, id: \.self) { Text($0.rawValue) } }
                    .pickerStyle(.segmented)
                    .onChange(of: window) { _, _ in selectedDay = nil }

                dayStrip(days, focus: focusDay)
                DayDetail(day: focusDay)
                riskChart(days)
                sprayWindows(days)
                MillsCard(day: focusDay)

                Text("Weather here is generated offline from \(climate.name) climate normals so the app works without a connection. Risk scores follow published infection conditions (Mills table for scab) and are a planning aid — confirm with local conditions and your extension service.")
                    .font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 20)
        }
        .tabBarSafeArea()
        .screenBackground()
        .navigationTitle("Infection risk")
    }

    private func dayStrip(_ days: [WeatherDay], focus: WeatherDay) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(days) { day in
                        let top = RiskModel.risks(for: day).first!
                        let isToday = Calendar.current.isDateInToday(day.date)
                        Button {
                            Haptics.tap()
                            withAnimation(.snappy) { selectedDay = day.date }
                        } label: {
                            VStack(spacing: 8) {
                                Text(isToday ? "Today" : day.date.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(.system(size: 12, weight: .semibold))
                                Text(day.date.formatted(.dateTime.day())).font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
                                Image(systemName: day.symbol).symbolRenderingMode(.multicolor).font(.system(size: 20)).frame(height: 24)
                                Text("\(Int(day.highF))°").font(.system(size: 14, weight: .semibold))
                                Text("\(Int(day.lowF))°").font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
                                Capsule().fill(top.level.color).frame(width: 26, height: 5)
                            }
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.vertical, 12).frame(width: 64)
                            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(day == focus ? Theme.parchment.opacity(0.14) : Theme.parchment.opacity(0.05)))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(day == focus ? Theme.parchment.opacity(0.4) : .clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .id(day.date)
                    }
                }
            }
            .scrollClipDisabled()
            .onAppear { proxy.scrollTo(focus.date, anchor: .center) }
        }
    }

    private struct RiskPoint: Identifiable {
        let date: Date
        let disease: Disease
        let score: Double
        var id: String { "\(date.timeIntervalSince1970)-\(disease.rawValue)" }
    }

    private func riskChart(_ days: [WeatherDay]) -> some View {
        let points = days.flatMap { day in RiskModel.risks(for: day).map { RiskPoint(date: day.date, disease: $0.disease, score: $0.score) } }
        let tracked = [Disease.scab, .rust, .powderyMildew, .frogEyeLeafSpot]
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Risk outlook").kickerStyle(Theme.textTertiary)
                Chart {
                    ForEach(days) { day in
                        BarMark(x: .value("Day", day.date, unit: .day), y: .value("Rain", min(1, day.rainMM / 25)))
                            .foregroundStyle(Color(hex: 0x6FA8DC).opacity(0.25))
                    }
                    ForEach(points) { p in
                        LineMark(x: .value("Day", p.date, unit: .day), y: .value("Risk", p.score))
                            .foregroundStyle(by: .value("Disease", p.disease.shortName))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    }
                    RuleMark(y: .value("High", 0.65)).foregroundStyle(Theme.danger.opacity(0.4)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .chartForegroundStyleScale(domain: tracked.map(\.shortName), range: tracked.map(\.color))
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(values: [0, 0.3, 0.65, 1]) { v in
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisValueLabel { Text(["Low", "Mod", "High", ""][[0, 0.3, 0.65, 1].firstIndex(of: v.as(Double.self) ?? 0) ?? 0]).font(.system(size: 9)).foregroundStyle(Theme.textTertiary) }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated)).font(.system(size: 9)).foregroundStyle(Theme.textTertiary)
                    }
                }
                .chartLegend(position: .bottom)
                .frame(height: 190)
                Text("Blue bars show rain.").font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
            }
        }
    }

    @ViewBuilder
    private func sprayWindows(_ days: [WeatherDay]) -> some View {
        let upcoming = days.filter { $0.date >= Calendar.current.startOfDay(for: window == .now ? .now : anchor) }
        let risky = upcoming.first { day in RiskModel.risks(for: day).contains { $0.level == .high } }
        GlassCard(tint: risky == nil ? Theme.canopy500 : Theme.rust) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Spray timing").kickerStyle()
                if let risky, let threat = RiskModel.risks(for: risky).first {
                    let dryBefore = upcoming.filter { $0.date < risky.date && $0.rainMM == 0 }
                    Text("Protect before \(risky.date.formatted(.dateTime.weekday(.wide)))").font(.display(21)).foregroundStyle(Theme.textPrimary)
                    Text("\(threat.disease.name): \(threat.reason).").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    if let dryDay = dryBefore.last {
                        Label("Best window: \(dryDay.date.formatted(.dateTime.weekday(.wide))) — dry, \(Int(dryDay.highF))°F", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.sage)
                    } else {
                        Label("No dry day before the risk period — consider a product with after-infection activity.", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.amber)
                    }
                } else {
                    Text("No high-risk infection periods ahead").font(.display(21)).foregroundStyle(Theme.textPrimary)
                    Text(window == .now ? "Good time for sanitation work — leaf litter, mummies and dead wood — rather than fungicides."
                                        : "Keep scouting and keep protectant coverage on new growth.")
                        .font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}

private struct DayDetail: View {
    let day: WeatherDay

    var body: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Image(systemName: day.symbol).symbolRenderingMode(.multicolor).font(.system(size: 40))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.date.formatted(.dateTime.weekday(.wide).month().day())).font(.display(21)).foregroundStyle(Theme.textPrimary)
                        Text("\(Int(day.highF))° / \(Int(day.lowF))° · \(day.rainMM > 0 ? "\(day.rainMM.formatted()) mm rain" : "dry") · \(Int(day.humidity))% RH · \(Int(day.wetHours)) h wet")
                            .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    }
                }
                ForEach(RiskModel.risks(for: day)) { risk in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: risk.disease.symbol).font(.system(size: 11)).foregroundStyle(risk.disease.color)
                            Text(risk.disease.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(risk.level.label).font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .foregroundStyle(risk.level.color)
                                .background(Capsule().fill(risk.level.color.opacity(0.15)))
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.parchment.opacity(0.07))
                                Capsule().fill(risk.level.color).frame(width: max(4, geo.size.width * risk.score))
                            }
                        }
                        .frame(height: 5)
                        Text(risk.reason).font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
    }
}

private struct MillsCard: View {
    let day: WeatherDay

    private struct Point: Identifiable { let t: Double; let h: Double; var id: Double { t } }

    var body: some View {
        let curve = stride(from: 34.0, through: 78.0, by: 1).compactMap { t in RiskModel.millsHours(atF: t).map { Point(t: t, h: $0) } }
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("How scab risk is scored").kickerStyle(Theme.textTertiary)
                Text("Scab spores need leaves to stay wet long enough at a given temperature. Below the curve: no infection.")
                    .font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                Chart {
                    ForEach(curve) { p in
                        AreaMark(x: .value("Temp °F", p.t), yStart: .value("Hours", p.h), yEnd: .value("Max", 50))
                            .foregroundStyle(Theme.rust.opacity(0.18))
                        LineMark(x: .value("Temp °F", p.t), y: .value("Hours", p.h)).foregroundStyle(Theme.rustLight)
                    }
                    if day.wetHours > 0 {
                        PointMark(x: .value("Temp °F", min(78, max(34, day.wetTempF))), y: .value("Hours", min(48, day.wetHours)))
                            .foregroundStyle(Theme.parchment).symbolSize(90)
                            .annotation(position: .top) { Text("selected day").font(.system(size: 9)).foregroundStyle(Theme.textSecondary) }
                    }
                }
                .chartYScale(domain: 0...50)
                .chartXAxisLabel("Temperature while wet (°F)", alignment: .center)
                .chartYAxisLabel("Hours wet")
                .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 9)).foregroundStyle(Theme.textTertiary) } }
                .chartYAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(Theme.hairline); AxisValueLabel().font(.system(size: 9)).foregroundStyle(Theme.textTertiary) } }
                .frame(height: 170)
                Text("Shaded = infection likely (approximate Mills table, light infection).").font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
            }
        }
    }
}
