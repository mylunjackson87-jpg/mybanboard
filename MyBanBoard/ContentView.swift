//
//  ContentView.swift
//  MyBanBoard
//
//  Created by Mylun Jackson on 3/2/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Board.updatedAt, order: .reverse) private var boards: [Board]
    @Query(sort: \Card.deletedAt, order: .reverse) private var cards: [Card]
    @State private var isShowingDebug = false
    @State private var isShowingRecentlyDeleted = false
    @State private var boardSearchText = ""

    var body: some View {
        NavigationSplitView {
            List {
                if filteredBoards.isEmpty {
                    ContentUnavailableView("No Matching Boards", systemImage: "magnifyingglass")
                } else {
                    ForEach(filteredBoards) { board in
                        NavigationLink {
                            BoardDetailView(board: board)
                        } label: {
                            Text(board.title)
                        }
                    }
                    .onDelete { offsets in
                        deleteBoards(offsets: offsets, from: filteredBoards)
                    }
                }
            }
            .navigationTitle("Boards")
            .searchable(text: $boardSearchText, prompt: "Search Boards")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Boards")
                        .font(.headline)
                        .onTapGesture(count: 5) {
                            isShowingDebug = true
                        }
                }
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .toolbar {
                ToolbarItem {
                    Button(action: addBoard) {
                        Label("Add Board", systemImage: "plus")
                    }
                }

                ToolbarItem {
                    Button {
                        isShowingRecentlyDeleted = true
                    } label: {
                        Label("Recently Deleted", systemImage: "trash")
                    }
                }
            }
            .sheet(isPresented: $isShowingDebug) {
                NavigationStack {
                    DebugView()
                }
            }
            .sheet(isPresented: $isShowingRecentlyDeleted) {
                NavigationStack {
                    RecentlyDeletedView()
                }
            }
        } detail: {
            if let board = filteredBoards.first {
                BoardDetailView(board: board)
            } else {
                ContentUnavailableView("Create a Board", systemImage: "rectangle.stack")
            }
        }
        .onAppear {
            purgeExpiredDeletedItems(boards: boards, cards: cards, modelContext: modelContext)
        }
    }

    private var filteredBoards: [Board] {
        let query = boardSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let activeBoards = boards.filter { $0.deletedAt == nil }
        guard !query.isEmpty else { return activeBoards }
        return activeBoards.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private func addBoard() {
        let board = Board(title: "Board \(boards.count + 1)")
        modelContext.insert(board)
        modelContext.saveWithLogging("ContentView.addBoard")
    }

    private func deleteBoards(offsets: IndexSet, from source: [Board]) {
        let deletedAt = Date.now
        for index in offsets {
            source[index].deletedAt = deletedAt
            source[index].updatedAt = deletedAt
        }
        modelContext.saveWithLogging("ContentView.softDeleteBoards")
    }
}

private struct RecentlyDeletedView: View {
    private enum PermanentDeleteTarget: Identifiable {
        case board(UUID)
        case card(UUID)

        var id: String {
            switch self {
            case .board(let id): return "board-\(id.uuidString)"
            case .card(let id): return "card-\(id.uuidString)"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Board.deletedAt, order: .reverse) private var boards: [Board]
    @Query(sort: \Card.deletedAt, order: .reverse) private var cards: [Card]
    @State private var pendingPermanentDelete: PermanentDeleteTarget?

    var body: some View {
        List {
            Section("Boards") {
                if deletedBoards.isEmpty {
                    Text("No deleted boards")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(deletedBoards) { board in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(board.title)
                                    .font(.headline)
                                Text("Deleted \(deletedDateText(for: board.deletedAt))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 12)
                            Button("Restore") {
                                restoreBoard(board)
                            }
                            Button("Delete", role: .destructive) {
                                pendingPermanentDelete = .board(board.id)
                            }
                        }
                    }
                }
            }

            Section("Cards") {
                if deletedCards.isEmpty {
                    Text("No deleted cards")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(deletedCards) { card in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.title.isEmpty ? "Untitled Card" : card.title)
                                    .font(.headline)
                                Text("Board: \(card.board.title)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 12)
                            Button("Restore") {
                                restoreCard(card)
                            }
                            Button("Delete", role: .destructive) {
                                pendingPermanentDelete = .card(card.id)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Recently Deleted")
        .onAppear {
            purgeExpiredDeletedItems(boards: boards, cards: cards, modelContext: modelContext)
        }
        .alert("Delete Permanently?", isPresented: isShowingPermanentDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                applyPermanentDelete()
            }
            Button("Cancel", role: .cancel) {
                pendingPermanentDelete = nil
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var deletedBoards: [Board] {
        boards.filter { $0.deletedAt != nil }
    }

    private var deletedCards: [Card] {
        cards.filter { $0.deletedAt != nil && $0.board.deletedAt == nil }
    }

    private var isShowingPermanentDeleteConfirmation: Binding<Bool> {
        Binding(
            get: { pendingPermanentDelete != nil },
            set: { isPresented in
                if !isPresented {
                    pendingPermanentDelete = nil
                }
            }
        )
    }

    private func restoreBoard(_ board: Board) {
        board.deletedAt = nil
        board.updatedAt = .now
        modelContext.saveWithLogging("RecentlyDeletedView.restoreBoard")
    }

    private func restoreCard(_ card: Card) {
        card.deletedAt = nil
        card.board.updatedAt = .now
        modelContext.saveWithLogging("RecentlyDeletedView.restoreCard")
    }

    private func applyPermanentDelete() {
        guard let target = pendingPermanentDelete else { return }
        switch target {
        case .board(let boardID):
            guard let board = boards.first(where: { $0.id == boardID }) else { break }
            modelContext.delete(board)
        case .card(let cardID):
            guard let card = cards.first(where: { $0.id == cardID }) else { break }
            modelContext.delete(card)
        }

        pendingPermanentDelete = nil
        modelContext.saveWithLogging("RecentlyDeletedView.permanentDelete")
    }

    private func deletedDateText(for deletedAt: Date?) -> String {
        guard let deletedAt else { return "Unknown" }
        return deletedAt.formatted(date: .abbreviated, time: .shortened)
    }
}

private func purgeExpiredDeletedItems(boards: [Board], cards: [Card], modelContext: ModelContext) {
    guard let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) else { return }
    var didDelete = false

    for card in cards {
        guard let deletedAt = card.deletedAt, deletedAt < cutoff else { continue }
        modelContext.delete(card)
        didDelete = true
    }

    for board in boards {
        guard let deletedAt = board.deletedAt, deletedAt < cutoff else { continue }
        modelContext.delete(board)
        didDelete = true
    }

    if didDelete {
        modelContext.saveWithLogging("SoftDelete.autoPurge")
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
