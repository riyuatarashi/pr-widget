import SwiftUI
import WidgetKit

@main
struct PRRadarWidgetBundle: WidgetBundle {
    var body: some Widget {
        PRRadarWidget()
    }
}

struct PRRadarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConfig.widgetKind, provider: PRTimelineProvider()) { entry in
            PRWidgetView(entry: entry)
        }
        .configurationDisplayName("PR Radar")
        .description("Les pull requests qui attendent ta review, avec une petite animation quand une nouvelle arrive.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
    }
}

struct PRWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PREntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family.isAccessory {
                    Color.clear
                } else {
                    WidgetBackground(isAlerting: entry.isAlerting)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch (entry.snapshot.status, family.isAccessory) {
        case (.signedOut, false):
            MessageView(symbol: "person.crop.circle.badge.plus", title: "PR Radar", message: "Connecte-toi à GitHub dans l'app.")
        case (.authExpired, false) where entry.snapshot.pullRequests.isEmpty:
            MessageView(symbol: "key.fill", title: "Reconnexion", message: "Ta session GitHub a expiré, ouvre l'app.")
        default:
            switch family {
            case .systemMedium: MediumView(entry: entry)
            case .systemLarge, .systemExtraLarge: LargeView(entry: entry)
            case .accessoryCircular: CircularView(entry: entry)
            case .accessoryRectangular: RectangularView(entry: entry)
            default: SmallView(entry: entry)
            }
        }
    }
}

private extension WidgetFamily {
    var isAccessory: Bool {
        switch self {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: true
        default: false
        }
    }
}

// MARK: - Tailles

/// Le format affiché en StandBy (iPhone posé en paysage pendant la charge) : il y est agrandi en plein écran.
struct SmallView: View {
    let entry: PREntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                BellView(phase: entry.phase, isAlerting: entry.isAlerting, size: 40)
                Spacer()
                CountView(count: entry.count, size: 34)
            }
            Spacer(minLength: 6)
            if let pr = entry.spotlight {
                SpotlightView(pr: pr, isNew: entry.isNew(pr), avatar: entry.avatar, titleLines: entry.isNew(pr) ? 2 : 3)
                    .id(pr.id)
                    .transition(.push(from: .bottom))
            } else {
                CalmView()
            }
        }
        .animation(.smooth(duration: 0.8), value: entry.spotlight?.id)
        .widgetURL(entry.spotlight.map(DeepLink.open) ?? DeepLink.home.url)
    }
}

struct MediumView: View {
    let entry: PREntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                BellView(phase: entry.phase, isAlerting: entry.isAlerting, size: 44)
                Spacer(minLength: 4)
                CountView(count: entry.count, size: 38)
                Text("à reviewer")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                UpdatedView(entry: entry)
                    .padding(.top, 4)
            }
            .frame(width: 92, alignment: .leading)

            if let pr = entry.spotlight {
                VStack(alignment: .leading, spacing: 8) {
                    SpotlightView(pr: pr, isNew: entry.isNew(pr), avatar: entry.avatar, titleLines: 2)
                        .id(pr.id)
                        .transition(.push(from: .bottom))
                    if let next = entry.others.first {
                        Divider().overlay(Color.primary.opacity(0.08))
                        Link(destination: DeepLink.open(next)) {
                            PRRow(pr: next, isNew: entry.isNew(next))
                        }
                    }
                    Spacer(minLength: 0)
                }
            } else {
                CalmView()
            }
        }
        .animation(.smooth(duration: 0.8), value: entry.spotlight?.id)
        .widgetURL(entry.spotlight.map(DeepLink.open) ?? DeepLink.home.url)
    }
}

struct LargeView: View {
    let entry: PREntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                BellView(phase: entry.phase, isAlerting: entry.isAlerting, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text("À reviewer")
                        .font(.headline)
                    UpdatedView(entry: entry)
                }
                Spacer()
                CountView(count: entry.count, size: 40)
            }

            if let pr = entry.spotlight {
                Link(destination: DeepLink.open(pr)) {
                    SpotlightView(pr: pr, isNew: entry.isNew(pr), avatar: entry.avatar, titleLines: 3)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.prAccent.opacity(entry.isNew(pr) ? 0.12 : 0.06), in: .rect(cornerRadius: 14))
                }
                .id(pr.id)
                .transition(.push(from: .bottom))

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(entry.others.prefix(4)) { other in
                        Link(destination: DeepLink.open(other)) {
                            PRRow(pr: other, isNew: entry.isNew(other))
                        }
                    }
                }
                Spacer(minLength: 0)
            } else {
                Spacer()
                CalmView()
                Spacer()
            }
        }
        .animation(.smooth(duration: 0.8), value: entry.spotlight?.id)
    }
}

struct CircularView: View {
    let entry: PREntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Campanula(clapperSwing: entry.phase.clapperAngle)
                    .frame(height: 16)
                    .rotationEffect(.degrees(entry.phase.bellAngle), anchor: .top)
                Text("\(entry.count)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: Double(entry.count)))
            }
        }
        .animation(.spring(duration: 0.7, bounce: 0.5), value: entry.phase)
        .widgetURL(entry.spotlight.map(DeepLink.open) ?? DeepLink.home.url)
    }
}

struct RectangularView: View {
    let entry: PREntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Campanula(clapperSwing: entry.phase.clapperAngle)
                    .frame(height: 16)
                    .rotationEffect(.degrees(entry.phase.bellAngle), anchor: .top)
                Text(entry.count == 0 ? "Rien à reviewer" : "\(entry.count) à reviewer")
                    .contentTransition(.numericText(value: Double(entry.count)))
            }
            .font(.headline)
            .widgetAccentable()
            if let pr = entry.spotlight {
                Text(pr.title).font(.caption).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(duration: 0.7, bounce: 0.5), value: entry.phase)
        .widgetURL(entry.spotlight.map(DeepLink.open) ?? DeepLink.home.url)
    }
}
