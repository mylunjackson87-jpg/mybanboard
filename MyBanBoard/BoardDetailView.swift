//
//  BoardDetailView.swift
//  MyBanBoard
//
//  Created by Mylun Jackson on 3/2/26.
//

import SwiftUI
import SwiftData

struct BoardDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var board: Board

    var body: some View {
        Form {
            Section("Board") {
                TextField("Board Title", text: $board.title)
            }

            Section("Cards") {
                ForEach(cards) { card in
                    CardRowView(card: card)
                }
                .onDelete(perform: deleteCards)

                Button("Add Card", action: addCard)
            }

            Section("Columns") {
                ForEach(columns) { column in
                    ColumnRowView(column: column)
                }
                .onDelete(perform: deleteColumns)

                Button("Add Column", action: addColumn)
            }
        }
        .navigationTitle(board.title)
        .onChange(of: board.title) {
            board.updatedAt = .now
        }
    }

    private var cards: [Card] {
        board.cards.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }

    private var columns: [Column] {
        board.columns.sorted { $0.order < $1.order }
    }

    private func addCard() {
        let card = Card(board: board, title: "Card \(board.cards.count + 1)")
        modelContext.insert(card)
        board.updatedAt = .now
    }

    private func deleteCards(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(cards[index])
        }
        board.updatedAt = .now
    }

    private func addColumn() {
        let column = Column(board: board, title: "Column \(board.columns.count + 1)", order: board.columns.count)
        modelContext.insert(column)
        board.updatedAt = .now
    }

    private func deleteColumns(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(columns[index])
        }
        board.updatedAt = .now
    }
}

private struct CardRowView: View {
    @Bindable var card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: $card.title)
            TextField("Content", text: $card.content, axis: .vertical)
                .lineLimit(2 ... 4)
        }
    }
}

private struct ColumnRowView: View {
    @Bindable var column: Column

    var body: some View {
        TextField("Title", text: $column.title)
    }
}

#Preview {
    if let board = PreviewSampleData.sampleBoard() {
        BoardDetailView(board: board)
            .modelContainer(PreviewSampleData.container)
    }
}
