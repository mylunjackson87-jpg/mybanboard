//
//  BoardDetailView.swift
//  MyBanBoard
//
//  Created by Mylun Jackson on 3/2/26.
//

import SwiftUI
import SwiftData

struct BoardDetailView: View {
    private enum SurfaceMode: String, CaseIterable, Identifiable {
        case canvas = "Canvas"
        case kanban = "Kanban"

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Bindable var board: Board
    @State private var isShowingManageSheet = false
    @State private var isShowingCardSearch = false
    @State private var surfaceMode: SurfaceMode = .canvas
    @State private var isDrawingMode = false
    @State private var isSnapEnabled = false
    @State private var cardSearchText = ""
    @State private var jumpToCardID: UUID?

    var body: some View {
        Group {
            if surfaceMode == .canvas {
                CanvasView(
                    board: board,
                    isDrawingMode: isDrawingMode,
                    isSnapEnabled: isSnapEnabled,
                    jumpToCardID: $jumpToCardID
                )
            } else {
                KanbanView(board: board)
            }
        }
        .navigationTitle(board.title)
        .toolbar {
            ToolbarItem {
                Picker("Mode", selection: $surfaceMode) {
                    ForEach(SurfaceMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            ToolbarItem {
                if surfaceMode == .canvas {
                    Button {
                        addCardAtViewportCenter()
                    } label: {
                        Label("Add Card", systemImage: "plus")
                    }
                }
            }

            ToolbarItem {
                if surfaceMode == .canvas {
                    Button {
                        isSnapEnabled.toggle()
                    } label: {
                        Label("Snap", systemImage: isSnapEnabled ? "square.grid.3x3.fill" : "square.grid.3x3")
                    }
                }
            }

            ToolbarItem {
                if surfaceMode == .canvas {
                    Button {
                        isDrawingMode.toggle()
                    } label: {
                        Label(
                            isDrawingMode ? "Disable Drawing" : "Enable Drawing",
                            systemImage: isDrawingMode ? "pencil.slash" : "pencil.tip"
                        )
                    }
                }
            }

            ToolbarItem {
                Button("Manage") {
                    isShowingManageSheet = true
                }
            }

            ToolbarItem {
                Button {
                    isShowingCardSearch = true
                } label: {
                    Label("Search Cards", systemImage: "magnifyingglass")
                }
            }

            ToolbarItemGroup {
                Button {
                    undoManager?.undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(!(undoManager?.canUndo ?? false))

                Button {
                    undoManager?.redo()
                } label: {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                }
                .disabled(!(undoManager?.canRedo ?? false))
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
        .sheet(isPresented: $isShowingCardSearch) {
            NavigationStack {
                BoardCardSearchView(
                    cards: cards,
                    searchText: $cardSearchText,
                    onSelect: handleCardSearchSelection
                )
            }
        }
        .onChange(of: board.title) {
            board.updatedAt = .now
            modelContext.saveWithLogging("BoardDetailView.titleChange")
        }
    }

    private var cards: [Card] {
        board.cards
            .filter { $0.deletedAt == nil }
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }

    private var columns: [Column] {
        board.columns.sorted { $0.order < $1.order }
    }

    private var undoService: UndoService? {
        guard let undoManager else { return nil }
        return UndoService(modelContext: modelContext, undoManager: undoManager)
    }

    private func addCard() {
        let card = Card(board: board, title: "Card \(board.cards.count + 1)")
        modelContext.insert(card)
        board.updatedAt = .now
        modelContext.saveWithLogging("BoardDetailView.addCard")
        undoService?.registerCardCreated(CardSnapshot(card: card))
    }

    private func addCardAtViewportCenter() {
        let scale = max(0.5, board.viewportScale)
        let centerX = -board.viewportOffsetX / scale
        let centerY = -board.viewportOffsetY / scale

        let card = Card(
            board: board,
            title: "Card \(board.cards.count + 1)",
            x: centerX,
            y: centerY
        )
        modelContext.insert(card)
        board.updatedAt = .now
        modelContext.saveWithLogging("BoardDetailView.addCardAtViewportCenter")
        undoService?.registerCardCreated(CardSnapshot(card: card))
    }

    private func deleteCards(offsets: IndexSet) {
        let targetCards = offsets.map { cards[$0] }
        let affectedColumnIDs = Set(targetCards.compactMap { $0.kanbanColumn?.id })
        let deletedAt = Date.now

        for card in targetCards {
            card.deletedAt = deletedAt
        }

        for columnID in affectedColumnIDs {
            normalizeKanbanOrder(columnID: columnID)
        }

        board.updatedAt = deletedAt
        modelContext.saveWithLogging("BoardDetailView.softDeleteCards")
    }

    private func addColumn() {
        let column = Column(board: board, title: "Column \(board.columns.count + 1)", order: board.columns.count)
        modelContext.insert(column)
        board.updatedAt = .now
        modelContext.saveWithLogging("BoardDetailView.addColumn")
        undoService?.registerColumnCreated(ColumnSnapshot(column: column))
    }

    private func deleteColumns(offsets: IndexSet) {
        let deletedColumns = offsets.map { columns[$0] }
        let deletedColumnSnapshots = deletedColumns.map(ColumnSnapshot.init(column:))
        let deletedCardSnapshots = deletedColumns.map { column in
            board.cards
                .filter { $0.kanbanColumn?.id == column.id }
                .map(CardSnapshot.init(card:))
        }

        for index in offsets {
            modelContext.delete(columns[index])
        }
        board.updatedAt = .now
        modelContext.saveWithLogging("BoardDetailView.deleteColumns")

        for (columnSnapshot, cardsSnapshot) in zip(deletedColumnSnapshots, deletedCardSnapshots) {
            undoService?.registerColumnDeleted(column: columnSnapshot, affectedCards: cardsSnapshot)
        }
    }

    private func handleCardSearchSelection(_ card: Card) {
        isShowingCardSearch = false

        if card.kanbanColumn != nil {
            surfaceMode = .kanban
            return
        }

        let scale = max(0.5, min(2.5, board.viewportScale))
        board.viewportOffsetX = -card.x * scale
        board.viewportOffsetY = -card.y * scale
        board.updatedAt = .now
        modelContext.saveWithLogging("BoardDetailView.jumpToCard")

        surfaceMode = .canvas
        jumpToCardID = nil
        DispatchQueue.main.async {
            jumpToCardID = card.id
        }
    }

    private func normalizeKanbanOrder(columnID: UUID) {
        let columnCards = board.cards
            .filter { $0.deletedAt == nil && $0.kanbanColumn?.id == columnID }
            .sorted { $0.orderInColumn < $1.orderInColumn }

        for (index, card) in columnCards.enumerated() {
            card.orderInColumn = index
        }
    }
}

private struct BoardCardSearchView: View {
    @Environment(\.dismiss) private var dismiss
    let cards: [Card]
    @Binding var searchText: String
    let onSelect: (Card) -> Void

    var body: some View {
        List(filteredCards) { card in
            Button {
                onSelect(card)
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(card.title.isEmpty ? "Untitled Card" : card.title)
                            .font(.headline)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(card.kanbanColumn == nil ? "Canvas" : "Kanban")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !card.content.isEmpty {
                        Text(card.content)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Find Card")
        .searchable(text: $searchText, prompt: "Title or content")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private var filteredCards: [Card] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return cards }

        let needle = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return cards.filter { card in
            let title = card.title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let content = card.content.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return title.contains(needle) || content.contains(needle)
        }
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
