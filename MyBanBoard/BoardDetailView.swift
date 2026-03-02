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
    @State private var surfaceMode: SurfaceMode = .canvas
    @State private var isDrawingMode = false

    var body: some View {
        Group {
            if surfaceMode == .canvas {
                CanvasView(board: board, isDrawingMode: isDrawingMode)
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
        let deletedSnapshots = offsets.map { CardSnapshot(card: cards[$0]) }
        for index in offsets {
            modelContext.delete(cards[index])
        }
        board.updatedAt = .now
        modelContext.saveWithLogging("BoardDetailView.deleteCards")
        for snapshot in deletedSnapshots {
            undoService?.registerCardDeleted(snapshot)
        }
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
