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
    @State private var isShowingManageSheet = false

    var body: some View {
        CanvasView(board: board)
        .navigationTitle(board.title)
        .toolbar {
            ToolbarItem {
                Button("Manage") {
                    isShowingManageSheet = true
                }
            }
        }
        .sheet(isPresented: $isShowingManageSheet) {
            NavigationStack {
                BoardManageView(
                    board: board,
                    cards: cards,
                    columns: columns,
                    addCard: addCard,
                    deleteCards: deleteCards,
                    addColumn: addColumn,
                    deleteColumns: deleteColumns
                )
            }
        }
        .onChange(of: board.title) {
            board.updatedAt = .now
            modelContext.saveWithLogging("BoardDetailView.titleChange")
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
        modelContext.saveWithLogging("BoardDetailView.addCard")
    }

    private func deleteCards(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(cards[index])
        }
        board.updatedAt = .now
        modelContext.saveWithLogging("BoardDetailView.deleteCards")
    }

    private func addColumn() {
        let column = Column(board: board, title: "Column \(board.columns.count + 1)", order: board.columns.count)
        modelContext.insert(column)
        board.updatedAt = .now
        modelContext.saveWithLogging("BoardDetailView.addColumn")
    }

    private func deleteColumns(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(columns[index])
        }
        board.updatedAt = .now
        modelContext.saveWithLogging("BoardDetailView.deleteColumns")
    }
}

private struct BoardManageView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var board: Board
    let cards: [Card]
    let columns: [Column]
    let addCard: () -> Void
    let deleteCards: (IndexSet) -> Void
    let addColumn: () -> Void
    let deleteColumns: (IndexSet) -> Void

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
        .navigationTitle("Manage Board")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private struct CardRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: $card.title)
            TextField("Content", text: $card.content, axis: .vertical)
                .lineLimit(2 ... 4)
        }
        .onChange(of: card.title) {
            modelContext.saveWithLogging("CardRowView.titleChange")
        }
        .onChange(of: card.content) {
            modelContext.saveWithLogging("CardRowView.contentChange")
        }
    }
}

private struct ColumnRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var column: Column

    var body: some View {
        TextField("Title", text: $column.title)
            .onChange(of: column.title) {
                modelContext.saveWithLogging("ColumnRowView.titleChange")
            }
    }
}

#Preview {
    if let board = PreviewSampleData.sampleBoard() {
        BoardDetailView(board: board)
            .modelContainer(PreviewSampleData.container)
    }
}
