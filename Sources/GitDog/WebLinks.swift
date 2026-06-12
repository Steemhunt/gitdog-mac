import AppKit

/// Bridges from the popover to the web surfaces (sender side lives on the web
/// by design — gitdog-mac#20). Plain URLs only: the web handles its own
/// session, so the app stays auth-mode-agnostic.
enum WebLinks {
    static func openDashboard() { open(path: "/dashboard") }
    static func openScoreCard(login: String) { open(path: "/score/\(login)") }

    private static func open(path: String) {
        let url = AppConfig.serverURL.appending(path: path)
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else { return }
        NSWorkspace.shared.open(url)
    }
}

/// The breed ladder (gitdog-mac#22). Static mirror of the server's scoring
/// spec (docs/PROPOSAL-gitdog-old.md §8 + price ladder) until GET /api/v1/breeds
/// lands (Steemhunt/gitdog#70) — then this becomes the offline fallback.
struct BreedRung: Identifiable {
    let level: Int
    let label: String
    let minScore: Int
    let maxPriceUsd: Int
    let art: String

    var id: Int { level }

    static let ladder: [BreedRung] = [
        .init(level: 1, label: "Chihuahua", minScore: 120, maxPriceUsd: 2, art: "breed-01-chihuahua.jpg"),
        .init(level: 2, label: "Pomeranian", minScore: 180, maxPriceUsd: 2, art: "breed-02-pomeranian.jpg"),
        .init(level: 3, label: "Corgi", minScore: 250, maxPriceUsd: 4, art: "breed-03-corgi.jpg"),
        .init(level: 4, label: "Beagle", minScore: 330, maxPriceUsd: 4, art: "breed-04-beagle.jpg"),
        .init(level: 5, label: "Shiba", minScore: 420, maxPriceUsd: 7, art: "breed-05-shiba.jpg"),
        .init(level: 6, label: "Border Collie", minScore: 520, maxPriceUsd: 7, art: "breed-06-collie.jpg"),
        .init(level: 7, label: "Husky", minScore: 630, maxPriceUsd: 12, art: "breed-07-husky.jpg"),
        .init(level: 8, label: "Shepherd", minScore: 750, maxPriceUsd: 12, art: "breed-08-shepherd.jpg"),
        .init(level: 9, label: "Doberman", minScore: 870, maxPriceUsd: 20, art: "breed-09-doberman.jpg"),
        .init(level: 10, label: "Mastiff", minScore: 950, maxPriceUsd: 20, art: "breed-10-mastiff.jpg"),
    ]

    var imageURL: URL { AppConfig.serverURL.appending(path: "/breeds/\(art)") }
}
