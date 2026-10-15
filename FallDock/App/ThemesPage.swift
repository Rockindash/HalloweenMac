import SwiftUI

/// The Themes page: which theme is on the Dock. Changing automatically (the season, with each
/// festival taking over for the week before its day), or keeping one theme all year.
struct ThemesPage: View {
    @ObservedObject var model: AppModel
    /// The themes in pairs: seasons first, then festivals, in the order they're listed.
    static var rows: [[Settings.Theme]] {
        let themes = Settings.Theme.seasons + Settings.Theme.festivals
        return stride(from: 0, to: themes.count, by: 2).map { Array(themes[$0..<min($0 + 2, themes.count)]) }
    }

    private var isAutomatic: Bool { model.themeChoice == .automatic }

    private var automatic: Binding<Bool> {
        Binding(get: { isAutomatic },
                // Switching it off keeps the theme that's on, so nothing jumps.
                set: { on in choose(on ? .automatic : .keep(model.theme)) })
    }

    private func choose(_ choice: Settings.ThemeChoice) {
        withAnimation(.easeInOut(duration: 0.35)) { model.themeChoice = choice }
    }

    var body: some View {
        PageLayout(title: "Themes") {
            HeroCard(eyebrow: "On your Dock now", title: model.theme.title,
                     subtitle: ThemeSchedule.summary(model.themeChoice), height: 240) {
                Image(nsImage: ThemePreview.image(for: model.theme))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .id(model.theme)
                    .transition(.opacity)
            }

            Card(title: "Change Automatically") {
                SettingRow(symbol: "calendar.badge.clock", color: .pumpkin, title: "Change automatically",
                           detail: "Follows the seasons, and puts each festival on your Dock a week before its day.") {
                    Toggle("", isOn: automatic).labelsHidden().toggleStyle(.switch)
                }
                ThemeYear(now: Date())
                    .opacity(isAutomatic ? 1 : 0.5)
                    .padding(.top, 4)
                if isAutomatic {
                    let changes = model.themeChoice.changes(after: Date(), count: 2)
                    ForEach(Array(changes.enumerated()), id: \.offset) { index, change in
                        Divider()
                        UpcomingRow(theme: change.theme, start: change.date,
                                    end: index + 1 < changes.count ? changes[index + 1].date : nil)
                    }
                } else {
                    Text("Keeping \(model.theme.title) on your Dock all year. Switch on to follow the calendar above.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Pick a Theme").font(.title3.weight(.bold))
                // Two to a row, like the Background pictures.
                VStack(spacing: 14) {
                    ForEach(Self.rows, id: \.self) { row in
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(row, id: \.self) { theme in
                                ThemeTile(theme: theme, isPicked: model.themeChoice == .keep(theme),
                                          isOnNow: model.theme == theme) { choose(.keep(theme)) }
                            }
                            if row.count == 1 { Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                        }
                    }
                }
                Text(isAutomatic
                     ? "Click a theme to keep it on your Dock all year. That switches off Change automatically."
                     : "Click a theme to put it on your Dock.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension Settings.Theme {
    /// The theme's own color, for its marks on the calendar and its symbol.
    var color: Color {
        switch self {
        case .fall: return .pumpkin
        case .halloween: return Color(cgColor: .hex(0x7A4FA3))
        }
    }
}

/// The year at a glance: a band for each season and each festival's week, and where today is.
struct ThemeYear: View {
    var now: Date
    private let calendar = Calendar.current

    /// A stretch of days with the same theme, as day numbers in the year (0-based, both included).
    struct Stretch: Hashable {
        var theme: Settings.Theme
        var first: Int
        var last: Int
    }

    private static var cache: [Int: (days: Int, stretches: [Stretch])] = [:]

    /// The year's stretches, worked out once per year.
    static func stretches(in year: Int, calendar: Calendar = .current) -> (days: Int, stretches: [Stretch]) {
        if let cached = cache[year] { return cached }
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let days = calendar.range(of: .day, in: .year, for: start)?.count else { return (365, []) }
        var stretches: [Stretch] = []
        for day in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: day, to: start) else { continue }
            let theme = Settings.ThemeChoice.automatic.theme(on: date, calendar: calendar)
            if let lastStretch = stretches.last, lastStretch.theme == theme {
                stretches[stretches.count - 1].last = day
            } else {
                stretches.append(Stretch(theme: theme, first: day, last: day))
            }
        }
        cache[year] = (days, stretches)
        return (days, stretches)
    }

    var body: some View {
        let year = calendar.component(.year, from: now)
        let info = Self.stretches(in: year, calendar: calendar)
        let days = info.days
        let stretches = info.stretches
        let today = (calendar.ordinality(of: .day, in: .year, for: now) ?? 1) - 1
        GeometryReader { geometry in
            let width = geometry.size.width
            let x = { (day: Int) -> CGFloat in width * CGFloat(day) / CGFloat(days) }
            ZStack(alignment: .topLeading) {
                // The seasons along the year.
                ForEach(stretches.filter { $0.theme.kind == .season }, id: \.self) { stretch in
                    Rectangle()
                        .fill(stretch.theme.color.gradient)
                        .frame(width: max(1, x(stretch.last + 1) - x(stretch.first)), height: 16)
                        .overlay(alignment: .leading) {
                            if x(stretch.last + 1) - x(stretch.first) > 64 {
                                Text(stretch.theme.title)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.leading, 7)
                            }
                        }
                        .offset(x: x(stretch.first), y: 22)
                }
                // Each festival's week, a little taller, with its symbol over it.
                ForEach(stretches.filter { $0.theme.kind == .festival }, id: \.self) { stretch in
                    let left = x(stretch.first)
                    let right = x(stretch.last + 1)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(stretch.theme.color.gradient)
                        .frame(width: max(4, right - left), height: 24)
                        .offset(x: left, y: 18)
                        .help("\(stretch.theme.title): \(ThemeSchedule.span(stretch, year: year))")
                    Image(systemName: stretch.theme.symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(stretch.theme.color))
                        .offset(x: (left + right) / 2 - 10, y: -4)
                }
                // Today.
                Capsule()
                    .fill(Color.primary)
                    .frame(width: 2, height: 30)
                    .offset(x: x(today) - 1, y: 15)
                Text("Today")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .frame(width: 60)
                    .offset(x: min(max(x(today) - 30, -14), width - 46), y: 47)
                // The months, at the start of each.
                ForEach(1...12, id: \.self) { month in
                    let first = calendar.date(from: DateComponents(year: year, month: month, day: 1))
                        .flatMap { calendar.ordinality(of: .day, in: .year, for: $0) }.map { $0 - 1 } ?? 0
                    Text(calendar.veryShortMonthSymbols[month - 1])
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .offset(x: x(first) + 2, y: 60)
                }
            }
            .frame(width: width, height: 76, alignment: .topLeading)
        }
        .frame(height: 76)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The year's themes")
        .accessibilityIdentifier("theme-year")
    }
}

/// A coming change: which theme, from when, and (for a festival) until when.
private struct UpcomingRow: View {
    var theme: Settings.Theme
    var start: Date
    /// The day the next change happens, so this one lasts until the day before.
    var end: Date?

    var body: some View {
        SettingRow(symbol: theme.symbol, color: theme.color, title: theme.title,
                   detail: ThemeSchedule.upcoming(theme, start: start, end: end)) {
            Text(ThemeSchedule.countdown(to: start))
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

/// A theme as a picture card, two to a row like the Background pictures. Picking it keeps it on the Dock.
struct ThemeTile: View {
    var theme: Settings.Theme
    /// Kept on the Dock all year.
    var isPicked: Bool
    /// On the Dock now (picked, or put there automatically).
    var isOnNow: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                // The preview strip at the bottom, under more of its own sky.
                Rectangle()
                    .fill(ThemePreview.sky(for: theme))
                    .aspectRatio(2.4, contentMode: .fit)
                    .overlay(alignment: .bottom) {
                        Image(nsImage: ThemePreview.image(for: theme))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if theme == .fall {
                            Text("THE ORIGINAL")
                                .font(.system(size: 9, weight: .heavy))
                                .tracking(0.5)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(.black.opacity(0.45)))
                                .padding(8)
                        }
                    }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: theme.symbol).foregroundStyle(theme.color)
                        Text(theme.title).font(.system(size: 13, weight: .semibold))
                        Text(ThemeSchedule.when(theme)).font(.callout).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        if isOnNow && !isPicked {
                            Text("On your Dock")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(theme.color))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    Text(theme.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2, reservesSpace: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardFill)
                .brightness(hovering ? 0.03 : 0))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.pumpkin, lineWidth: isPicked ? 2 : 0))
            .overlay(alignment: .topTrailing) {
                if isPicked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.white, Color.pumpkin)
                        .padding(18)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PressableStyle())
        .onHover { hovering = $0 }
        .help("Keep \(theme.title) on your Dock")
        .accessibilityLabel("\(theme.title) theme")
        .accessibilityIdentifier("theme-\(theme.rawValue)")
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }
}

/// Words for which theme is on and when it changes.
enum ThemeSchedule {
    /// "Oct 24".
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// What kind of theme it is, and a festival's day: "Season", or "Festival, Oct 31".
    static func when(_ theme: Settings.Theme, now: Date = Date()) -> String {
        guard theme.kind == .festival else { return "Season" }
        let year = Calendar.current.component(.year, from: now)
        guard let date = theme.festivalDay(in: year) else { return "Festival" }
        return "Festival, \(day(date))"
    }

    /// When the calendar puts a festival on the Dock this year, like "Oct 24 to Oct 31".
    static func window(_ theme: Settings.Theme, now: Date = Date()) -> String {
        let year = Calendar.current.component(.year, from: now)
        guard let week = theme.festivalWeek(in: year) else { return "between festivals" }
        return "\(day(week.lowerBound)) to \(day(week.upperBound))"
    }

    /// A stretch of the year in words, like "Oct 24 to Oct 31".
    static func span(_ stretch: ThemeYear.Stretch, year: Int, calendar: Calendar = .current) -> String {
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let first = calendar.date(byAdding: .day, value: stretch.first, to: start),
              let last = calendar.date(byAdding: .day, value: stretch.last, to: start) else { return "" }
        return "\(day(first)) to \(day(last))"
    }

    /// A coming change in words: "Oct 24 to Oct 31" for a festival's week, or "From Nov 1".
    static func upcoming(_ theme: Settings.Theme, start: Date, end: Date?, calendar: Calendar = .current) -> String {
        if theme.kind == .festival, let end, let last = calendar.date(byAdding: .day, value: -1, to: end) {
            return "\(day(start)) to \(day(last))"
        }
        return "From \(day(start))"
    }

    /// "Tomorrow", or "In 9 days".
    static func countdown(to date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case ...0: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(days) days"
        }
    }

    /// "Fall stays on your Dock all year." or "Fall now, then Halloween on Oct 24."
    static func summary(_ choice: Settings.ThemeChoice, now: Date = Date()) -> String {
        let theme = choice.theme(on: now)
        guard let next = choice.next(after: now) else { return "\(theme.title) stays on your Dock all year." }
        return "\(theme.title) now, then \(next.theme.title) on \(day(next.date))."
    }
}
