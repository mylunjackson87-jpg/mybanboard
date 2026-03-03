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
    @State private var isShowingDebug = false
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
            }
            .sheet(isPresented: $isShowingDebug) {
                NavigationStack {
                    DebugView()
                }
            }
        } detail: {
            if let board = filteredBoards.first {
                BoardDetailView(board: board)
            } else {
                ContentUnavailableView("Create a Board", systemImage: "rectangle.stack")
            }
        }
    }

    private var filteredBoards: [Board] {
        let query = boardSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return boards }
        return boards.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private func addBoard() {
        let board = Board(title: "Board \(boards.count + 1)")
        modelContext.insert(board)
        modelContext.saveWithLogging("ContentView.addBoard")
    }

    private func deleteBoards(offsets: IndexSet, from source: [Board]) {
        for index in offsets {
            modelContext.delete(source[index])
        }
        modelContext.saveWithLogging("ContentView.deleteBoards")
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
