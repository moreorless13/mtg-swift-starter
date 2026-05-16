import Foundation

enum ScryfallCardServiceError: Error, Equatable, LocalizedError {
    case noUsableText
    case badResponse
    case notFound(String)
    case api(String)

    var errorDescription: String? {
        switch self {
        case .noUsableText:
            "No card name or collector details were recognized. Try a sharper scan with the card filling the frame."
        case .badResponse:
            "Scryfall returned an unexpected response."
        case .notFound(let query):
            "No Scryfall match found for \(query)."
        case .api(let message):
            "Scryfall request failed: \(message)"
        }
    }
}

struct ScryfallCardService: CardIdentifying {
    typealias DataLoader = (URLRequest) async throws -> (Data, HTTPURLResponse)

    private let baseURL: URL
    private let dataLoader: DataLoader
    private let decoder = JSONDecoder()

    init(
        baseURL: URL = URL(string: "https://api.scryfall.com")!,
        dataLoader: @escaping DataLoader = ScryfallCardService.liveDataLoader
    ) {
        self.baseURL = baseURL
        self.dataLoader = dataLoader
    }

    func identify(_ recognizedText: RecognizedCardText) async throws -> CardIdentificationResult {
        if
            let setCode = recognizedText.setCodeCandidate?.trimmedNonEmpty,
            let collectorNumber = recognizedText.collectorNumberCandidate?.trimmedNonEmpty
        {
            do {
                let card = try await fetchCard(path: "/cards/\(setCode.lowercased())/\(collectorNumber)")
                return .exact(try await cardSummary(from: card))
            } catch ScryfallCardServiceError.notFound where recognizedText.nameCandidate?.trimmedNonEmpty != nil {
                // Fall through to fuzzy-name print candidates when exact print metadata was noisy.
            }
        }

        guard let name = recognizedText.nameCandidate?.trimmedNonEmpty else {
            throw ScryfallCardServiceError.noUsableText
        }

        let namedCard = try await fetchNamedCard(fuzzyName: name)
        let printCards = try await fetchPrints(exactName: namedCard.name)
        let summaries = try await summaries(from: printCards)

        guard !summaries.isEmpty else {
            return .notFound(name)
        }

        if summaries.count == 1, let card = summaries.first {
            return .exact(card)
        }

        return .candidates(summaries)
    }

    private static func liveDataLoader(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScryfallCardServiceError.badResponse
        }

        return (data, httpResponse)
    }

    private func fetchNamedCard(fuzzyName: String) async throws -> ScryfallCardDTO {
        try await fetchCard(path: "/cards/named", queryItems: [
            URLQueryItem(name: "fuzzy", value: fuzzyName)
        ])
    }

    private func fetchPrints(exactName: String) async throws -> [ScryfallCardDTO] {
        let escapedName = exactName.replacingOccurrences(of: "\"", with: "\\\"")
        let response: ScryfallListDTO<ScryfallCardDTO> = try await fetch(
            path: "/cards/search",
            queryItems: [
                URLQueryItem(name: "q", value: "!\"\(escapedName)\""),
                URLQueryItem(name: "unique", value: "prints"),
                URLQueryItem(name: "order", value: "released"),
                URLQueryItem(name: "dir", value: "desc")
            ]
        )

        return response.data
    }

    private func fetchCard(path: String, queryItems: [URLQueryItem] = []) async throws -> ScryfallCardDTO {
        try await fetch(path: path, queryItems: queryItems)
    }

    private func summaries(from cards: [ScryfallCardDTO]) async throws -> [MTGCardSummary] {
        var setIconCache: [String: URL?] = [:]
        var summaries: [MTGCardSummary] = []

        for card in cards {
            let iconURL: URL?

            if let cachedURL = setIconCache[card.set] {
                iconURL = cachedURL
            } else {
                iconURL = try? await fetchSetIconURL(setCode: card.set)
                setIconCache[card.set] = iconURL
            }

            summaries.append(card.makeSummary(setIconURL: iconURL))
        }

        return summaries
    }

    private func cardSummary(from card: ScryfallCardDTO) async throws -> MTGCardSummary {
        let iconURL = try? await fetchSetIconURL(setCode: card.set)
        return card.makeSummary(setIconURL: iconURL)
    }

    private func fetchSetIconURL(setCode: String) async throws -> URL? {
        let set: ScryfallSetDTO = try await fetch(path: "/sets/\(setCode.lowercased())")
        return set.iconSVGURI
    }

    private func fetch<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        let data = try await fetchData(path: path, queryItems: queryItems)

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw ScryfallCardServiceError.api(error.localizedDescription)
        }
    }

    private func fetchData(path: String, queryItems: [URLQueryItem]) async throws -> Data {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        components?.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components?.url else {
            throw ScryfallCardServiceError.badResponse
        }

        var request = URLRequest(url: url)
        request.setValue("mtg-xproject-starter/1.0 (iOS learning project)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")

        let (data, response) = try await dataLoader(request)

        switch response.statusCode {
        case 200..<300:
            return data
        case 404:
            throw ScryfallCardServiceError.notFound(url.lastPathComponent)
        default:
            throw ScryfallCardServiceError.api("HTTP \(response.statusCode)")
        }
    }
}

private struct ScryfallListDTO<Item: Decodable>: Decodable {
    let data: [Item]
}

private struct ScryfallCardDTO: Decodable {
    let id: String
    let name: String
    let set: String
    let setName: String?
    let collectorNumber: String
    let scryfallURI: URL?
    let imageURIs: ImageURIs?
    let typeLine: String?
    let manaCost: String?
    let rarity: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case set
        case setName = "set_name"
        case collectorNumber = "collector_number"
        case scryfallURI = "scryfall_uri"
        case imageURIs = "image_uris"
        case typeLine = "type_line"
        case manaCost = "mana_cost"
        case rarity
    }

    struct ImageURIs: Decodable {
        let normal: URL?
        let small: URL?
    }

    func makeSummary(setIconURL: URL?) -> MTGCardSummary {
        MTGCardSummary.make(
            id: id,
            name: name,
            manaCost: manaCost,
            type: typeLine,
            setCode: set,
            setName: setName,
            collectorNumber: collectorNumber,
            setIconURL: setIconURL,
            imageURL: imageURIs?.normal ?? imageURIs?.small,
            rarity: rarity
        )
    }
}

private struct ScryfallSetDTO: Decodable {
    let iconSVGURI: URL?

    enum CodingKeys: String, CodingKey {
        case iconSVGURI = "icon_svg_uri"
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
