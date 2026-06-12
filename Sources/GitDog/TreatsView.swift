import SwiftUI

/// Treats screen (design screen 3): balance, progress to cash-out, history.
/// `available` (spendable) and `pending` (escrowed) are shown strictly apart
/// per the contract — pending is never presented as cash-out-able.
struct TreatsView: View {
    @ObservedObject var store: ReviewerStore
    let me: APIClient.Me
    @Binding var route: ReviewerRoute

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().overlay(Theme.cream.opacity(0.1))
            if let t = store.treats {
                content(t)
            } else {
                Spacer()
                ProgressView().controlSize(.small)
                Spacer()
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { route = .inbox } label: { Text("←").font(.system(size: 15)) }
                .buttonStyle(.plain).foregroundStyle(Theme.cream)
            Text("TREATS").font(.custom(Theme.pixelFont, size: 12))
                .foregroundStyle(Theme.orange)
            Spacer()
            Text("Lv.\(me.level) @\(me.login)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.creamDim)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func content(_ t: APIClient.Treats) -> some View {
        CaptureScroll {
            VStack(spacing: 14) {
                VStack(spacing: 8) {
                    Text(formatUsd(t.availableUsd))
                        .font(.custom(Theme.pixelFont, size: 28))
                        .foregroundStyle(Theme.green)
                    if !t.cashoutEligible {
                        Text("cash out unlocks at \(formatUsd(t.cashoutMinUsd)) — keep fetching!")
                            .font(.system(size: 11)).foregroundStyle(Theme.creamDim)
                    }
                    TreatsGauge(treats: t)
                        .frame(height: 12)
                }
                .padding(.top, 8)

                if Double(t.pendingUsd) ?? 0 > 0 {
                    HStack {
                        Text("Pending (in escrow)")
                            .font(.system(size: 12)).foregroundStyle(Theme.creamDim)
                        Spacer()
                        Text(formatUsd(t.pendingUsd))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.orangeSoft)
                    }
                    .padding(11)
                    .background(Theme.navyCard, in: RoundedRectangle(cornerRadius: 11))
                }

                if !t.history.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(t.history) { entry in
                            HistoryRow(entry: entry)
                        }
                    }
                }

                if t.cashoutEligible {
                    Button("Cash Out to Base wallet") { route = .inbox /* cash-out flow: mac#7 follow */ }
                        .buttonStyle(GitDogButton(kind: .money, fullWidth: true))
                } else {
                    Text("🔒 Cash Out — \(remaining(t)) to go")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.creamDim)
                        .frame(maxWidth: .infinity).padding(12)
                        .background(Theme.navyCard, in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(Theme.cream.opacity(0.2), style: StrokeStyle(dash: [4])))
                }
            }
            .padding(16)
        }
    }

    private func remaining(_ t: APIClient.Treats) -> String {
        let gap = (Double(t.cashoutMinUsd) ?? 50) - (Double(t.availableUsd) ?? 0)
        return formatUsd(String(max(gap, 0)))
    }
}

private struct HistoryRow: View {
    let entry: APIClient.Treats.Entry
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 12.5)).foregroundStyle(Theme.cream)
                Text(entry.createdAt, style: .relative)
                    .font(.system(size: 10.5)).foregroundStyle(Theme.creamDim)
            }
            Spacer()
            Text(amount)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(isCredit ? Theme.orangeSoft : Theme.green)
        }
        .padding(.vertical, 9)
        .overlay(Divider().overlay(Theme.cream.opacity(0.06)), alignment: .bottom)
    }

    private var isCredit: Bool { entry.type == "credit_grant" }
    private var label: String {
        switch entry.type {
        case "escrow_release": "Feedback accepted"
        case "credit_grant": "Launch credit*"
        case "cashout": "Cash out"
        case "refund": "Refund"
        default: entry.type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    private var amount: String {
        // formatUsd already carries a "-" for debits; only add "+" for credits.
        let v = Double(entry.amountUsd) ?? 0
        return (v > 0 ? "+" : "") + formatUsd(entry.amountUsd)
    }
}
