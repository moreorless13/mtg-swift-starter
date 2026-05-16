//
//  ContentView.swift
//  mtg-xproject-starter
//
//  Created by James Strande on 5/16/26.
//

import SwiftUI

struct ContentView: View {
    private let cardService: any MTGCardFetching
    private let cardIdentifier: any CardIdentifying

    @State private var query = "Black Lotus"
    @State private var cards: [MTGCardSummary] = []
    @State private var loadState = LoadState.idle
    @State private var resultNotice: String?
    @State private var isScannerPresented = false

    init(
        cardService: any MTGCardFetching = MTGCardService(),
        cardIdentifier: any CardIdentifying = ScryfallCardService()
    ) {
        self.cardService = cardService
        self.cardIdentifier = cardIdentifier
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if case .failed(let message) = loadState {
                    errorBanner(message)
                }

                if let resultNotice {
                    noticeBanner(resultNotice)
                }

                cardList
            }
            .navigationTitle("MTG Cards")
            .sheet(isPresented: $isScannerPresented) {
                CardScannerView(cardIdentifier: cardIdentifier) { result in
                    applyIdentificationResult(result)
                }
            }
            .task {
                guard cards.isEmpty, loadState == .idle else {
                    return
                }

                await fetchCards()
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            TextField("Card name", text: $query)
                .textInputAutocapitalization(.words)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.search)
                .onSubmit {
                    Task { await fetchCards() }
                }

            Button {
                Task { await fetchCards() }
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .disabled(loadState.isLoading)
            .accessibilityLabel("Fetch cards")

            Button {
                isScannerPresented = true
            } label: {
                Image(systemName: "camera.viewfinder")
            }
            .buttonStyle(.bordered)
            .disabled(loadState.isLoading)
            .accessibilityLabel("Scan a card")
        }
        .padding()
        .background(.background)
    }

    private var cardList: some View {
        List {
            if loadState.isLoading {
                HStack {
                    Spacer()
                    ProgressView("Fetching cards")
                    Spacer()
                }
            } else if cards.isEmpty {
                ContentUnavailableView(
                    "No Cards",
                    systemImage: "rectangle.stack.badge.questionmark",
                    description: Text("Search for a Magic card to fetch data from the MTG SDK.")
                )
            } else {
                ForEach(cards) { card in
                    CardSummaryRow(card: card)
                }
            }
        }
        .listStyle(.plain)
        .animation(.default, value: loadState)
        .animation(.default, value: cards)
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 8)
    }

    private func noticeBanner(_ message: String) -> some View {
        Label(message, systemImage: "checkmark.seal.fill")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 8)
    }

    private func fetchCards() async {
        loadState = .loading
        resultNotice = nil

        do {
            cards = try await cardService.fetchCards(named: query)
            loadState = .loaded
        } catch {
            cards = []
            loadState = .failed(error.userFacingMessage)
        }
    }

    private func applyIdentificationResult(_ result: CardIdentificationResult) {
        switch result {
        case .exact(let card):
            query = card.name
            cards = [card]
            resultNotice = "Scanned exact print."
            loadState = .loaded
        case .candidates(let candidates):
            query = candidates.first?.name ?? query
            cards = candidates
            resultNotice = "Scan found multiple printings. Choose the matching set and collector number."
            loadState = .loaded
        case .notFound(let query):
            cards = []
            resultNotice = nil
            loadState = .failed("No Scryfall match found for \(query).")
        }
    }
}

private struct CardSummaryRow: View {
    let card: MTGCardSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            cardThumbnail

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(card.name)
                        .font(.headline)

                    Spacer(minLength: 12)

                    Text(card.manaCost)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                Text(card.type)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                if let setName = card.setName {
                    Text(setName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    setCodeLabel

                    if let collectorNumber = card.collectorNumber {
                        Label("#\(collectorNumber)", systemImage: "number")
                    }

                    Label(card.rarity, systemImage: "sparkles")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var cardThumbnail: some View {
        AsyncImage(url: card.imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                Image(systemName: "rectangle.stack.badge.questionmark")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 52, height: 72)
        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityHidden(true)
    }

    private var setCodeLabel: some View {
        HStack(spacing: 4) {
            AsyncImage(url: card.setIconURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                default:
                    Image(systemName: "rectangle.stack")
                }
            }
            .frame(width: 16, height: 16)

            Text(card.setCode)
        }
    }
}

private enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)

    var isLoading: Bool {
        self == .loading
    }
}

extension Error {
    var userFacingMessage: String {
        if let localizedError = self as? LocalizedError, let errorDescription = localizedError.errorDescription {
            return errorDescription
        }

        return localizedDescription
    }
}

private struct PreviewCardService: MTGCardFetching {
    func fetchCards(named query: String) async throws -> [MTGCardSummary] {
        [
            MTGCardSummary.make(
                id: "preview-black-lotus",
                name: "Black Lotus",
                manaCost: "{0}",
                type: "Artifact",
                setCode: "LEA",
                rarity: "Rare"
            ),
            MTGCardSummary.make(
                id: "preview-lightning-bolt",
                name: "Lightning Bolt",
                manaCost: "{R}",
                type: "Instant",
                setCode: "M10",
                rarity: "Common"
            )
        ]
    }
}

#Preview {
    ContentView(cardService: PreviewCardService())
}
