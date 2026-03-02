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

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(boards) { board in
                    NavigationLink {
                        BoardDetailView(board: board)
                    } label: {
                        Text(board.title)
                    }
                }
                .onDelete(perform: deleteBoards)
            }
            .navigationTitle("Boards")
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .toolbar {
                ToolbarItem {
                    Button(action: addBoard) {
                        Label("Add Board", systemImage: "plus")
                    }
                }
            }
        } detail: {
            if let board = boards.first {
                BoardDetailView(board: board)
            } else {
                ContentUnavailableView("Create a Board", systemImage: "rectangle.stack")
            }
        }
    }

    private func addBoard() {
        let board = Board(title: "Board \(boards.count + 1)")
        modelContext.insert(board)
    }

    private func deleteBoards(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(boards[index])
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
