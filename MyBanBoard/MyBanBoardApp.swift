//
//  MyBanBoardApp.swift
//  MyBanBoard
//
//  Created by Mylun Jackson on 3/2/26.
//

import SwiftUI
import SwiftData
import OSLog
#if os(macOS)
import AppKit
#endif

@main
struct MyBanBoardApp: App {
    private static let logger = Logger(subsystem: "MYJ.MyBanBoard", category: "Startup")

    private var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Board.self,
            Card.self,
            Column.self,
        ])
        let localConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [localConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
#if os(macOS)
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    NSApp.keyWindow?.undoManager?.undo()
                }
                .keyboardShortcut("z", modifiers: .command)

                Button("Redo") {
                    NSApp.keyWindow?.undoManager?.redo()
                }
                .keyboardShortcut("Z", modifiers: [.command, .shift])
            }
        }
#endif
    }
}
