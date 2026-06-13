import SwiftUI

/// The breed ladder explainer (design frame F): all 10 breeds with score
/// thresholds and max prices; the signed-in user's rung highlighted with the
/// points needed to reach the next one.
struct BreedLadderView: View {
    let me: APIClient.Me
    /// Token to fetch the live ladder; nil → static fallback only (render harness).
    var token: String? = nil
    @Binding var route: ReviewerRoute
    /// Where ← returns to (set by SignedInView to the route that opened the ladder).
    var backRoute: ReviewerRoute = .inbox

    /// Server ladder once loaded, else the static spec mirror (#70 fallback).
    @State private var rungs: [BreedRung] = BreedRung.ladder

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().overlay(Theme.cream.opacity(0.1))
            Text("Your public GitHub history decides your breed. Higher breeds earn more per feedback. Ship more, climb the ladder.")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.creamDim)
                .padding(.horizontal, 16).padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)
            CaptureScroll {
                VStack(spacing: 0) {
                    ForEach(rungs) { rung in
                        row(rung)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .task(id: token) {
            guard let token else { return }
            if let entries = try? await APIClient(token: token).breeds(), !entries.isEmpty {
                rungs = entries.map(BreedRung.init(from:))
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { route = backRoute } label: { Text("←").font(.system(size: 15)) }
                .buttonStyle(.plain).foregroundStyle(Theme.cream)
            Text("THE BREED LADDER")
                .font(.custom(Theme.pixelFont, size: 10))
                .foregroundStyle(Theme.orange)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func row(_ rung: BreedRung) -> some View {
        let isMe = rung.level == me.level
        return HStack(spacing: 11) {
            AsyncImage(url: rung.imageURL) { image in
                image.resizable().interpolation(.none).scaledToFit()
            } placeholder: {
                Text("🐾").font(.system(size: 14))
            }
            .frame(width: 34, height: 34)
            .background(Theme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9)
                .stroke(isMe ? Theme.orange : Theme.cream.opacity(0.2), lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("\(rung.label) · Lv.\(rung.level)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.cream)
                    if isMe {
                        Text("— you")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.orangeSoft)
                    }
                }
                Text(subtitle(rung, isMe: isMe))
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(Theme.creamDim)
            }
            Spacer()
            Text(formatUsd(rung.maxPriceUsd))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.green)
        }
        .padding(.horizontal, 16).padding(.vertical, 7)
        .background(isMe ? Theme.orange.opacity(0.1) : .clear)
        .overlay(alignment: .leading) {
            if isMe { Rectangle().fill(Theme.orange).frame(width: 3) }
        }
    }

    private func subtitle(_ rung: BreedRung, isMe: Bool) -> String {
        if isMe, let next = rungs.first(where: { $0.level == rung.level + 1 }) {
            let delta = max(next.minScore - me.score, 0)
            return "score \(rung.minScore)+ · \(delta) pts to \(next.label)"
        }
        return "score \(rung.minScore)+"
    }
}
