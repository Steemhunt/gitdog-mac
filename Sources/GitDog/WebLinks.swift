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

/// The breed ladder view model (gitdog-mac#22). The live ladder comes from GET
/// /api/v1/breeds (Steemhunt/gitdog#70 — reflects admin threshold/price
/// overrides); this static mirror of the scoring spec is the offline fallback
/// shown until that fetch succeeds.
struct BreedRung: Identifiable {
    let level: Int
    let label: String
    let minScore: Int
    /// Money string ("2", "20.00"); rendered via formatUsd so the server's
    /// decimals and the static fallback's plain ints display identically.
    let maxPriceUsd: String
    let imageURL: URL

    var id: Int { level }

    private static func artURL(_ name: String) -> URL {
        AppConfig.serverURL.appending(path: "/breeds/\(name)")
    }

    /// Map a server ladder entry to the view model.
    init(from entry: APIClient.BreedLadderEntry) {
        level = entry.level
        label = entry.label
        minScore = entry.minScore
        maxPriceUsd = entry.maxPriceUsd
        imageURL = URL(string: entry.imageUrl) ?? Self.artURL("breed-01-chihuahua.jpg")
    }

    init(level: Int, label: String, minScore: Int, maxPriceUsd: String, art: String) {
        self.level = level
        self.label = label
        self.minScore = minScore
        self.maxPriceUsd = maxPriceUsd
        self.imageURL = Self.artURL(art)
    }

    static let ladder: [BreedRung] = [
        .init(level: 1, label: "Chihuahua", minScore: 120, maxPriceUsd: "2", art: "breed-01-chihuahua.jpg"),
        .init(level: 2, label: "Pomeranian", minScore: 180, maxPriceUsd: "2", art: "breed-02-pomeranian.jpg"),
        .init(level: 3, label: "Corgi", minScore: 250, maxPriceUsd: "4", art: "breed-03-corgi.jpg"),
        .init(level: 4, label: "Beagle", minScore: 330, maxPriceUsd: "4", art: "breed-04-beagle.jpg"),
        .init(level: 5, label: "Shiba", minScore: 420, maxPriceUsd: "7", art: "breed-05-shiba.jpg"),
        .init(level: 6, label: "Border Collie", minScore: 520, maxPriceUsd: "7", art: "breed-06-collie.jpg"),
        .init(level: 7, label: "Husky", minScore: 630, maxPriceUsd: "12", art: "breed-07-husky.jpg"),
        .init(level: 8, label: "Shepherd", minScore: 750, maxPriceUsd: "12", art: "breed-08-shepherd.jpg"),
        .init(level: 9, label: "Doberman", minScore: 870, maxPriceUsd: "20", art: "breed-09-doberman.jpg"),
        .init(level: 10, label: "Mastiff", minScore: 950, maxPriceUsd: "20", art: "breed-10-mastiff.jpg"),
    ]
}
