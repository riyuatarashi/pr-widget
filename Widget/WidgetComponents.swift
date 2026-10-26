import AppIntents
import SwiftUI
import UIKit
import WidgetKit

struct WidgetBackground: View {
    let isAlerting: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.09, green: 0.10, blue: 0.12), Color(red: 0.05, green: 0.06, blue: 0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.prAccent.opacity(isAlerting ? 0.28 : 0), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 220
            )
        }
    }
}

/// La cloche et ses ondes : c'est elle qui « sonne » quand une PR arrive.
struct BellView: View {
    let phase: PREntry.Phase
    let isAlerting: Bool
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            ripple(visible: phase == .ring, expanded: phase >= .swing)
            ripple(visible: phase == .ringAgain, expanded: phase == .settle)

            Circle()
                .fill(Color.prAccent.opacity(isAlerting ? 0.22 : 0.10))

            Image(systemName: isAlerting ? "bell.badge.fill" : "bell.fill")
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(isAlerting ? Color.prAccent : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .rotationEffect(.degrees(phase.bellAngle), anchor: UnitPoint(x: 0.5, y: 0.12))
                .animation(.spring(duration: 0.7, bounce: 0.55), value: phase)
        }
        .frame(width: size, height: size)
        .widgetAccentable()
    }

    private func ripple(visible: Bool, expanded: Bool) -> some View {
        Circle()
            .stroke(Color.prAccent, lineWidth: 2)
            .scaleEffect(expanded ? 1.9 : 1)
            .opacity(visible ? 0.8 : 0)
            .animation(.easeOut(duration: 1.1), value: phase)
    }
}

struct CountView: View {
    let count: Int
    let size: CGFloat

    var body: some View {
        Text("\(count)")
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(count)))
            .animation(.smooth, value: count)
    }
}

struct NewBadge: View {
    var body: some View {
        Text("NOUVELLE PR")
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(.black)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.prAccent, in: .capsule)
            .widgetAccentable()
    }
}

struct SpotlightView: View {
    let pr: PullRequestSummary
    let isNew: Bool
    let avatar: Data?
    let titleLines: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if isNew {
                NewBadge()
                    .padding(.bottom, 1)
                    .transition(.scale.combined(with: .opacity))
            }
            Text(pr.repositoryName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(pr.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(titleLines)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4) {
                AvatarView(data: avatar, size: 14)
                Text("\(pr.author) · #\(pr.number)")
                if pr.isDraft {
                    Image(systemName: "pencil.circle")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }
}

struct PRRow: View {
    let pr: PullRequestSummary
    let isNew: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(isNew ? Color.prAccent : Color.white.opacity(0.18))
                .frame(width: 7, height: 7)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 1) {
                Text(pr.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("\(pr.repositoryName) · \(pr.author) · \(pr.createdAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct AvatarView: View {
    let data: Data?
    let size: CGFloat

    var body: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: size, height: size)
        }
    }
}

struct CalmView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(Color.prAccent)
                .widgetAccentable()
            Text("Tout est calme")
                .font(.headline)
            Text("Aucune review en attente.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Heure de la dernière synchro ; un tap force un rafraîchissement (widget interactif).
struct UpdatedView: View {
    let entry: PREntry

    var body: some View {
        Button(intent: RefreshPullRequestsIntent()) {
            HStack(spacing: 3) {
                Image(systemName: symbol)
                if entry.snapshot.fetchedAt > .distantPast {
                    Text(entry.snapshot.fetchedAt, style: .time)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var symbol: String {
        switch entry.snapshot.status {
        case .ok: "arrow.clockwise"
        case .authExpired: "key.fill"
        case .failed, .signedOut: "exclamationmark.triangle.fill"
        }
    }
}

struct MessageView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Color.prAccent)
            Spacer(minLength: 0)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(DeepLink.home.url)
    }
}

#Preview("StandBy", as: .systemSmall) {
    PRRadarWidget()
} timeline: {
    PREntry(date: .now, snapshot: PREntry.sample.snapshot, spotlight: PREntry.sample.others.first)
    PREntry(date: .now, snapshot: PREntry.sample.snapshot, spotlight: PREntry.sample.spotlight, phase: .ring)
    PREntry(date: .now, snapshot: PREntry.sample.snapshot, spotlight: PREntry.sample.spotlight, phase: .swing)
    PREntry(date: .now, snapshot: PREntry.sample.snapshot, spotlight: PREntry.sample.spotlight, phase: .ringAgain)
    PREntry(date: .now, snapshot: PREntry.sample.snapshot, spotlight: PREntry.sample.spotlight, phase: .settle)
}

#Preview("Medium", as: .systemMedium) {
    PRRadarWidget()
} timeline: {
    PREntry.sample
}

#Preview("Large", as: .systemLarge) {
    PRRadarWidget()
} timeline: {
    PREntry.sample
}
