import SwiftUI

/// The Themes page: which theme is on the Dock. Changing automatically (the season, with each
/// festival taking over for the week before its day, out of the themes the person keeps in the
/// rotation), or keeping one theme all year.
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
                // The year, what's next and which themes take turns, only while it's on.
                if isAutomatic {
                    VStack(alignment: .leading, spacing: 22) {
                        ThemeYear(now: Date(), rotation: model.rotation)
                        ComingUp(changes: model.themeChoice.changes(after: Date(), count: 2, rotation: model.rotation))
                        RotationPicker(model: model)
                    }
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
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

/// The year at a glance: a ribbon with a band for each season and each festival's week picked out (only
/// the themes in the rotation), the months, and where today is. Pointing at a festival's week, or
/// clicking it, shows its name and dates.
struct ThemeYear: View {
    var now: Date
    var rotation: Set<Settings.Theme>
    private let calendar = Calendar.current
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    /// The festival the pointer is over, and the one clicked to keep its details showing.
    @State private var hovered: Stretch?
    @State private var pinned: Stretch?

    /// A stretch of days with the same theme, as day numbers in the year (0-based, both included).
    struct Stretch: Hashable {
        var theme: Settings.Theme
        var first: Int
        var last: Int
    }

    private static var cache: [String: (days: Int, stretches: [Stretch])] = [:]

    /// The year's stretches with the themes in `rotation`, worked out once per year and rotation.
    static func stretches(in year: Int, rotation: Set<Settings.Theme> = Settings.rotation,
                          calendar: Calendar = .current) -> (days: Int, stretches: [Stretch]) {
        let key = "\(year) " + rotation.map(\.rawValue).sorted().joined(separator: ",")
        if let cached = cache[key] { return cached }
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let days = calendar.range(of: .day, in: .year, for: start)?.count else { return (365, []) }
        var stretches: [Stretch] = []
        for day in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: day, to: start) else { continue }
            let theme = Settings.ThemeChoice.automatic.theme(on: date, rotation: rotation, calendar: calendar)
            if let lastStretch = stretches.last, lastStretch.theme == theme {
                stretches[stretches.count - 1].last = day
            } else {
                stretches.append(Stretch(theme: theme, first: day, last: day))
            }
        }
        cache[key] = (days, stretches)
        return (days, stretches)
    }

    // The rows, from the top: room for a festival's highlight to stand out, the ribbon, the months,
    // and today's tag.
    private static let headroom: CGFloat = 8
    private static let ribbonHeight: CGFloat = 30
    private static let monthRow: CGFloat = 22
    private static let todayRow: CGFloat = 26

    var body: some View {
        let year = calendar.component(.year, from: now)
        let info = Self.stretches(in: year, rotation: rotation, calendar: calendar)
        let festivals = info.stretches.filter { $0.theme.kind == .festival }
        let today = (calendar.ordinality(of: .day, in: .year, for: now) ?? 1) - 1
        let thisMonth = calendar.component(.month, from: now)
        // The first day of each month, as a day of the year.
        let months = (1...12).map { month in
            calendar.date(from: DateComponents(year: year, month: month, day: 1))
                .flatMap { calendar.ordinality(of: .day, in: .year, for: $0) }.map { $0 - 1 } ?? 0
        }
        let top = Self.headroom
        let height = top + Self.ribbonHeight + Self.monthRow + Self.todayRow
        GeometryReader { geometry in
            let width = geometry.size.width
            let x = { (day: Int) -> CGFloat in width * CGFloat(day) / CGFloat(info.days) }
            let todayX = x(today) + x(1) / 2
            ZStack(alignment: .topLeading) {
                ribbon(info.stretches, months: months, today: today, year: year, x: x)
                    .frame(width: width, height: Self.ribbonHeight)
                    .offset(y: top)

                // The months, with this one picked out.
                ForEach(0..<12, id: \.self) { month in
                    let start = x(months[month]), end = x(month == 11 ? info.days : months[month + 1])
                    Text(width / 12 > 34 ? calendar.shortMonthSymbols[month] : calendar.veryShortMonthSymbols[month])
                        .font(.system(size: 10.5, weight: month + 1 == thisMonth ? .bold : .medium))
                        .foregroundStyle(month + 1 == thisMonth ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                        .fixedSize()
                        .position(x: (start + end) / 2, y: top + Self.ribbonHeight + Self.monthRow / 2 + 1)
                }

                // Each festival's week, picked out on the ribbon. Its details show only while it's
                // pointed at, or after a click (until clicked again).
                ForEach(festivals, id: \.self) { stretch in
                    let left = x(stretch.first), right = x(stretch.last + 1)
                    let isShown = (hovered ?? pinned) == stretch
                    FestivalWeek(theme: stretch.theme, width: right - left, isShown: isShown)
                        .frame(width: max(26, right - left + 10), height: Self.ribbonHeight + 16)
                        .contentShape(Rectangle())
                        .onHover { inside in
                            if inside { hovered = stretch } else if hovered == stretch { hovered = nil }
                        }
                        .onTapGesture { pinned = pinned == stretch ? nil : stretch }
                        .accessibilityElement()
                        .accessibilityLabel("\(stretch.theme.title), \(ThemeSchedule.span(stretch, year: year))")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { pinned = pinned == stretch ? nil : stretch }
                        .accessibilityIdentifier("festival-\(stretch.theme.rawValue)")
                        .position(x: (left + right) / 2, y: top + Self.ribbonHeight / 2)
                }
                // Today: a line across the ribbon, and a tag under the months with a dot that gently pulses.
                Capsule()
                    .fill(Color.primary)
                    .overlay(Capsule().stroke(Color.pageBackground.opacity(0.9), lineWidth: 1))
                    .frame(width: 3, height: Self.ribbonHeight + 8)
                    .position(x: todayX, y: top + Self.ribbonHeight / 2)
                    .allowsHitTesting(false)
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.pumpkin)
                        .frame(width: 6, height: 6)
                        .opacity(pulse ? 0.35 : 1)
                    Text("Today, \(ThemeSchedule.day(now))")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
                .fixedSize()
                .position(x: min(max(todayX, 52), width - 52), y: height - Self.todayRow / 2)
                .allowsHitTesting(false)

                if let shown = hovered ?? pinned {
                    let center = (x(shown.first) + x(shown.last + 1)) / 2
                    // A zero-size point just above the festival's week, with the tip sitting on it.
                    Color.clear
                        .frame(width: 1, height: 1)
                        .overlay(alignment: .bottom) {
                            FestivalTip(theme: shown.theme, dates: ThemeSchedule.span(shown, year: year),
                                        when: ThemeSchedule.festivalCountdown(shown, today: today))
                                .fixedSize()
                        }
                        .position(x: center, y: top - 6)
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                }
            }
            .frame(width: width, height: height, alignment: .topLeading)
            .animation(.easeOut(duration: 0.15), value: hovered ?? pinned)
        }
        .frame(height: height)
        .onAppear {
            // (No pulsing in the UI tests, which wait for the window to be still.)
            guard !reduceMotion, !AppEnvironment.isUITesting else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("The year's themes")
        .accessibilityIdentifier("theme-year")
    }

    /// The bands for the seasons and festivals, with faint month lines and the past a little dimmer.
    private func ribbon(_ stretches: [Stretch], months: [Int], today: Int, year: Int,
                        x: @escaping (Int) -> CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(stretches, id: \.self) { stretch in
                let left = x(stretch.first), right = x(stretch.last + 1)
                SeasonBand(theme: stretch.theme, width: right - left, showsName: stretch.theme.kind == .season)
                    .frame(width: max(2, right - left), height: Self.ribbonHeight)
                    .offset(x: left)
            }
            ForEach(months.dropFirst(), id: \.self) { day in
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 1, height: Self.ribbonHeight)
                    .offset(x: x(day))
                    .allowsHitTesting(false)
            }
            Rectangle()
                .fill(Color.black.opacity(0.16))
                .frame(width: x(today), height: Self.ribbonHeight)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.primary.opacity(0.1)))
    }
}

/// One stretch of the ribbon: the theme's color, with its little symbol scattered faintly across it
/// and, for a season with room, its name.
private struct SeasonBand: View {
    var theme: Settings.Theme
    var width: CGFloat
    var showsName: Bool

    var body: some View {
        let named = showsName && width > 80
        Rectangle()
            .fill(theme.color.gradient)
            .overlay(alignment: .trailing) {
                // A sprinkle of the theme's symbol, tilted this way and that.
                HStack(spacing: 16) {
                    ForEach(0..<max(0, Int((width - (named ? 86 : 10)) / 26)), id: \.self) { i in
                        Image(systemName: theme.symbol)
                            .font(.system(size: 10, weight: .bold))
                            .rotationEffect(.degrees(i % 2 == 0 ? -18 : 14))
                            .offset(y: i % 2 == 0 ? -4 : 5)
                    }
                }
                .foregroundStyle(.white.opacity(0.2))
                .padding(.trailing, 8)
            }
            .overlay(alignment: .leading) {
                if named {
                    Label(theme.title, systemImage: theme.symbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                        .padding(.leading, 10)
                }
            }
            .clipped()
    }
}

/// A festival's week, picked out on the ribbon: a little taller than it, in the festival's color with a
/// bright edge and its symbol, glowing more while its details show.
private struct FestivalWeek: View {
    var theme: Settings.Theme
    var width: CGFloat
    var isShown: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(theme.color.gradient)
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5))
            .overlay {
                if width >= 13 {
                    Image(systemName: theme.symbol)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: max(8, width), height: 38)
            .shadow(color: theme.color.opacity(isShown ? 0.8 : 0.45), radius: isShown ? 7 : 3)
            .scaleEffect(isShown ? 1.1 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isShown)
    }
}

/// A festival's details over its week: its name, dates and when it's next on the Dock.
private struct FestivalTip: View {
    var theme: Settings.Theme
    var dates: String
    var when: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: theme.symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(theme.color.gradient))
                VStack(alignment: .leading, spacing: 1) {
                    Text(theme.title).font(.system(size: 12, weight: .bold))
                    Text(dates).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Text(when)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(theme.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(theme.color.opacity(0.15)))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.regularMaterial))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            Triangle(pointsDown: true)
                .fill(Color.primary.opacity(0.25))
                .frame(width: 12, height: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("festival-tip")
    }
}

/// A small triangle, for pointing from a tag to its place.
private struct Triangle: Shape {
    var pointsDown: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tip = pointsDown ? rect.maxY : rect.minY, base = pointsDown ? rect.minY : rect.maxY
        path.move(to: CGPoint(x: rect.minX, y: base))
        path.addLine(to: CGPoint(x: rect.maxX, y: base))
        path.addLine(to: CGPoint(x: rect.midX, y: tip))
        path.closeSubpath()
        return path
    }
}

/// The next changes, side by side: which theme, when, and how long until then.
private struct ComingUp: View {
    var changes: [(theme: Settings.Theme, date: Date)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Coming up")
            if changes.isEmpty {
                Text("\(Settings.ThemeChoice.automatic.theme(on: Date()).title) stays on your Dock all year: it's the only theme in the rotation.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(changes.enumerated()), id: \.offset) { index, change in
                        UpcomingCard(theme: change.theme,
                                     dates: ThemeSchedule.upcoming(change.theme, start: change.date,
                                                                   end: index + 1 < changes.count ? changes[index + 1].date : nil),
                                     countdown: ThemeSchedule.countdown(to: change.date))
                    }
                }
            }
        }
    }
}

/// A coming change: the theme's badge, its name and dates, and a countdown.
private struct UpcomingCard: View {
    var theme: Settings.Theme
    var dates: String
    var countdown: String

    var body: some View {
        HStack(spacing: 10) {
            Badge(symbol: theme.symbol, color: theme.color)
            VStack(alignment: .leading, spacing: 1) {
                Text(theme.title).font(.system(size: 13, weight: .semibold))
                Text(dates).font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(countdown)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(theme.color.opacity(0.14)))
                .fixedSize()
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(theme.color.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(theme.color.opacity(0.22)))
    }
}

/// Which themes take turns when the Dock changes automatically, grouped into seasons and festivals.
private struct RotationPicker: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: "In the rotation")
                Spacer()
                Text("\(model.rotation.count) of \(Settings.Theme.allCases.count) themes")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(Settings.Theme.Kind.allCases, id: \.self) { kind in
                let themes = Settings.Theme.allCases.filter { $0.kind == kind }
                if !themes.isEmpty {
                    Text(kind.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    // Two to a row. (Not a lazy grid: those leave out rows that aren't on screen yet.)
                    VStack(spacing: 10) {
                        ForEach(stride(from: 0, to: themes.count, by: 2).map { Array(themes[$0..<min($0 + 2, themes.count)]) }, id: \.self) { row in
                            HStack(spacing: 10) {
                                ForEach(row, id: \.self) { theme in
                                    RotationRow(theme: theme, model: model)
                                }
                                if row.count == 1 { Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                            }
                        }
                    }
                }
            }
            Text("Switch a theme off to skip it. The season before it stays on longer, and a festival's week stays with the season.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A theme with a switch for whether it's in the rotation. The last season can't be switched off.
private struct RotationRow: View {
    var theme: Settings.Theme
    @ObservedObject var model: AppModel

    var body: some View {
        let isIn = model.rotation.contains(theme)
        let locked = isIn && !model.canLeaveRotation(theme)
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Badge(symbol: theme.symbol, color: theme.color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(theme.title).font(.system(size: 13, weight: .semibold))
                    Text(ThemeSchedule.dates(theme, rotation: model.rotation))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .saturation(isIn ? 1 : 0)
            .opacity(isIn ? 1 : 0.55)
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(get: { isIn }, set: { on in
                withAnimation(.easeInOut(duration: 0.3)) { model.setInRotation(theme, on) }
            }))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(locked)
            .accessibilityIdentifier("rotation-\(theme.rawValue)")
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.04)))
        .help(locked ? "At least one season stays in, for the days between festivals." : "")
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

    /// When a theme is on in the rotation: a festival's week ("Oct 24 to Oct 31"), a season's start
    /// ("From Sep 1"), or "All year, between festivals" for the only season.
    static func dates(_ theme: Settings.Theme, rotation: Set<Settings.Theme>, now: Date = Date(), calendar: Calendar = .current) -> String {
        if theme.kind == .festival { return window(theme, now: now) }
        let otherSeasons = rotation.filter { $0 != theme && $0.kind == .season }
        guard let start = theme.seasonStart, !otherSeasons.isEmpty,
              let date = calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: start.month, day: start.day))
        else { return "All year, between festivals" }
        return "From \(day(date))"
    }

    /// A coming change in words: "Oct 24 to Oct 31" for a festival's week, or "From Nov 1".
    static func upcoming(_ theme: Settings.Theme, start: Date, end: Date?, calendar: Calendar = .current) -> String {
        if theme.kind == .festival, let end, let last = calendar.date(byAdding: .day, value: -1, to: end) {
            return "\(day(start)) to \(day(last))"
        }
        return "From \(day(start))"
    }

    /// When a festival's week (in this year's ribbon) is on, from day of the year `today`: "On your Dock
    /// now", "In 9 days", or "Back next year".
    static func festivalCountdown(_ stretch: ThemeYear.Stretch, today: Int) -> String {
        if (stretch.first...stretch.last).contains(today) { return "On your Dock now" }
        if stretch.first < today { return "Back next year" }
        let days = stretch.first - today
        return days == 1 ? "Tomorrow" : "In \(days) days"
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
