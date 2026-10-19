import SwiftData
import SwiftUI

// MARK: - Toast

struct Toast: Identifiable {
    let id = UUID()
    let message: String
    let entry: Entry?
}

struct ToastView: View {
    @Environment(\.modelContext) private var context
    let toast: Toast
    let onDismiss: () -> Void
    let onDetails: (Entry) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(toast.message)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            Spacer(minLength: 0)
            if let entry = toast.entry {
                if !(entry.tracker?.sortedFields.isEmpty ?? true) {
                    Button("Details") { onDetails(entry) }
                }
                Button("Undo") {
                    EntryFactory.delete(entry, in: context)
                    onDismiss()
                }
            }
        }
        .font(.subheadline.weight(.bold))
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
        .foregroundStyle(Color(.systemBackground))
        .tint(Color(.systemBackground))
        .background(Capsule().fill(Color(.label)))
        .task(id: toast.id) {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { onDismiss() }
        }
    }
}

// MARK: - Tracker card

struct TrackerCard: View {
    let tracker: Tracker
    /// Entry counts by start-of-day for (at least) the last 7 days.
    let counts: [Date: Int]
    let onPlus: () -> Void

    private var days: [Date] { (0..<7).map { Day.add($0 - 6, to: Date()) } }

    var body: some View {
        let today = counts[Day.start(Date())] ?? 0
        VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: tracker.symbol)
                        .foregroundStyle(tracker.color)
                    Text(tracker.name)
                        .font(.headline)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                HStack(alignment: .center, spacing: 10) {
                    Text(verbatim: "\(today)")
                        .font(.system(size: 38, weight: today == 0 ? .semibold : .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(today == 0 ? .secondary : .primary)
                        .contentTransition(.numericText())
                    if tracker.dailyGoal > 0 {
                        Text("of \(tracker.dailyGoal)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    TallyMarks(count: today, color: tracker.color)
                }
                .frame(minHeight: 44)
            }
            Spacer(minLength: 0)
            PlusCircle(color: tracker.color, mode: tracker.logMode, progress: progress(today), action: onPlus)
                .accessibilityLabel(Text("Log \(tracker.name)"))
        }
            WeekStrip(days: days, counts: counts, color: tracker.color)
        }
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .leading) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground))
                Rectangle().fill(tracker.color).frame(width: 5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .animation(.snappy, value: today)
    }

    private func progress(_ today: Int) -> Double? {
        guard tracker.dailyGoal > 0 else { return nil }
        return min(1, Double(today) / Double(tracker.dailyGoal))
    }
}

struct PlusCircle: View {
    let color: Color
    let mode: LogMode
    let progress: Double?
    let action: () -> Void
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            ZStack {
                Circle().fill(color)
                Text(verbatim: "+1")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                if mode == .form {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .offset(y: 17)
                }
            }
            .frame(width: 68, height: 68)
            .padding(5)
            .overlay {
                if let progress {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Circle()
                        .stroke(color.opacity(0.2), lineWidth: 3)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.increase, trigger: taps)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

struct WeekStrip: View {
    let days: [Date]
    let counts: [Date: Int]
    let color: Color

    var body: some View {
        let values = days.map { counts[$0] ?? 0 }
        let maxValue = max(1, values.max() ?? 1)
        HStack(spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                let v = values[i]
                VStack(spacing: 0) {
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(v == 0 ? "·" : "\(v)")
                        .font(.footnote.weight(.semibold).monospacedDigit())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(v == 0 ? 0 : 0.18 + 0.5 * Double(v) / Double(maxValue)))
                )
                .overlay {
                    if i == days.count - 1 {
                        RoundedRectangle(cornerRadius: 6).strokeBorder(color, lineWidth: 1.5)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "\(day.formatted(.dateTime.weekday(.wide))): \(v)"))
            }
        }
    }
}

/// Hand-drawn tally marks in groups of five.
struct TallyMarks: View {
    let count: Int
    let color: Color

    var body: some View {
        let shown = min(count, 20)
        HStack(spacing: 4) {
            if shown > 0 {
                Canvas { ctx, size in
                    for i in 0..<shown {
                        let g = CGFloat(i / 5), j = i % 5, x0 = g * 30
                        var p = Path()
                        if j < 4 {
                            let x = x0 + 4 + CGFloat(j) * 5.5
                            let jit = CGFloat((i * 37) % 7 - 3) * 0.28
                            p.move(to: CGPoint(x: x + jit, y: 4))
                            p.addLine(to: CGPoint(x: x - jit, y: 24))
                        } else {
                            p.move(to: CGPoint(x: x0 + 1, y: 20))
                            p.addLine(to: CGPoint(x: x0 + 25, y: 8))
                        }
                        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    }
                }
                .frame(width: CGFloat((shown + 4) / 5) * 30, height: 28)
            }
            if count > 20 {
                Text(verbatim: "+\(count - 20)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Small helpers

struct FlowChips: View {
    let items: [String]
    var selected: String? = nil
    let color: Color
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    let isOn = item == selected
                    Button { onTap(item) } label: {
                        Text(item)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .foregroundStyle(isOn ? .white : .primary)
                            .background(Capsule().fill(isOn ? color : color.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
