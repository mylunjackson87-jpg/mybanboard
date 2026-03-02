//
//  MyBanBoardApp.swift
//  MyBanBoard
//
//  Created by Mylun Jackson on 3/2/26.
//

import SwiftUI
import SwiftData
import OSLog

@main
struct MyBanBoardApp: App {
    private static let logger = Logger(subsystem: "MYJ.MyBanBoard", category: "Startup")

    private var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Board.self,
            Card.self,
            Column.self,
        ])
        let cloudKitConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        let localConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [cloudKitConfiguration])
        } catch {
            Self.logger.error("CloudKit model container init failed: \(error.localizedDescription, privacy: .public). Falling back to local store.")

            do {
                return try ModelContainer(for: schema, configurations: [localConfiguration])
            } catch {
                fatalError("Could not create local fallback ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
