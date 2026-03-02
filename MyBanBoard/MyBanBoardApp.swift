//
//  MyBanBoardApp.swift
//  MyBanBoard
//
//  Created by Mylun Jackson on 3/2/26.
//

import SwiftUI
import SwiftData

@main
struct MyBanBoardApp: App {
    private var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Board.self,
            Card.self,
            Column.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
