import SwiftUI

/// Treats screen (design screen 3): balance, progress to cash-out, history.
/// `available` (spendable) and `pending` (escrowed) are shown strictly apart
/// per the contract — pending is never presented as cash-out-able.
struct TreatsView: View {
    @ObservedObject var store: ReviewerStore
    let me: APIClient.Me
    @Binding var route: ReviewerRoute
    @State private var showInfo = false

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
            Text("TREATS").font(.custom(Theme.pixelFont, size: 11))
                .foregroundStyle(Theme.orange)
            Button("ⓘ") { showInfo.toggle() }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.orangeSoft)
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
                if showInfo { TreatsInfoPanel(treats: t) }
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
                    .background(Theme.navyCard, in: RoundedRectangle(cornerRadius: 13))
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
                        .background(Theme.navyCard, in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13)
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

/// "What are Treats?" explainer (design frame E) — copy mirrors the ledger
/// semantics exactly: pending is escrowed and never spendable; launch credits
/// are spend-only and excluded from the cash-out threshold.
struct TreatsInfoPanel: View {
    let treats: APIClient.Treats

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("🦴 What are Treats?")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.cream)
            Text("Treats are your USDC earnings for feedback. Real money, not points.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.creamDim)
                .fixedSize(horizontal: false, vertical: true)
            infoLine("Available", "\(formatUsd(treats.availableUsd)) — yours, spendable", Theme.green)
            infoLine("Pending", "\(formatUsd(treats.pendingUsd)) — releases ≤48h after you send (sooner if accepted)", Theme.orangeSoft)
            infoLine("Cash out", "from \(formatUsd(treats.cashoutMinUsd)) → your Base wallet (USDC)", Theme.cream)
            infoLine("Launch credits", "spend-only, don't count toward \(formatUsd(treats.cashoutMinUsd))", Theme.orangeSoft)
        }
        .padding(13)
        .background(Theme.navyCard, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.cream.opacity(0.07)))
    }

    private func infoLine(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.creamDim)
            Spacer()
            Text(value).font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(color)
                .multilineTextAlignment(.trailing)
        }
    }
}
