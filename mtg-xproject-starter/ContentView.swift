//
//  ContentView.swift
//  mtg-xproject-starter
//
//  Created by James Strande on 5/16/26.
//

import SwiftUI

struct ContentView: View {
    private let cardService: any MTGCardFetching

    @State private var query = "Black Lotus"
    @State private var cards: [MTGCardSummary] = []
    @State private var loadState = LoadState.idle

    init(cardService: any MTGCardFetching = MTGCardService()) {
        self.cardService = cardService
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if case .failed(let message) = loadState {
                    errorBanner(message)
                }

                cardList
            }
            .navigationTitle("MTG Cards")
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
                Label("Fetch", systemImage: "magnifyingglass")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            .disabled(loadState.isLoading)
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

    private func fetchCards() async {
        loadState = .loading

        do {
            cards = try await cardService.fetchCards(named: query)
            loadState = .loaded
        } catch {
            cards = []
            loadState = .failed(error.userFacingMessage)
        }
    }
}

private struct CardSummaryRow: View {
    let card: MTGCardSummary

    var body: some View {
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

            HStack {
                Label(card.setCode, systemImage: "rectangle.stack")
                Label(card.rarity, systemImage: "sparkles")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
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

private extension Error {
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
