import Foundation
import MTGSDKSwift

protocol MTGCardFetching {
    func fetchCards(named query: String) async throws -> [MTGCardSummary]
}

enum MTGCardServiceError: Error, Equatable, LocalizedError {
    case emptyQuery
    case sdk(String)

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            "Enter a card name before searching."
        case .sdk(let message):
            "MTG SDK request failed: \(message)"
        }
    }
}

struct MTGCardService: MTGCardFetching {
    typealias SearchHandler = (String, @escaping (Swift.Result<[MTGCardSummary], Error>) -> Void) -> Void

    private let searchHandler: SearchHandler

    init(searchHandler: @escaping SearchHandler = MTGCardService.liveSearchHandler()) {
        self.searchHandler = searchHandler
    }

    func fetchCards(named query: String) async throws -> [MTGCardSummary] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            throw MTGCardServiceError.emptyQuery
        }

        return try await withCheckedThrowingContinuation { continuation in
            searchHandler(normalizedQuery) { result in
                continuation.resume(with: result)
            }
        }
    }

    private static func liveSearchHandler() -> SearchHandler {
        let magic = Magic()
        let configuration = MTGSearchConfiguration(pageSize: 20, pageTotal: 1)

        return { query, completion in
            let name = CardSearchParameter(parameterType: .name, value: query)

            magic.fetchCards([name], configuration: configuration) { result in
                Task { @MainActor in
                    switch result {
                    case .success(let cards):
                        completion(.success(cards.map(MTGCardSummary.init(card:))))
                    case .error(let error):
                        completion(.failure(MTGCardServiceError.sdk(String(describing: error))))
                    }
                }
            }
        }
    }
}

private extension MTGCardSummary {
    init(card: Card) {
        self = MTGCardSummary.make(
            id: card.id,
            name: card.name,
            manaCost: card.manaCost,
            type: card.type,
            setCode: card.set,
            rarity: card.rarity
        )
    }
}
