//
//  PersistenceLogging.swift
//  MyBanBoard
//
//  Created by Mylun Jackson on 3/2/26.
//

import OSLog
import SwiftData

private let persistenceLogger = Logger(subsystem: "MYJ.MyBanBoard", category: "Persistence")

extension ModelContext {
    func saveWithLogging(_ source: String) {
        guard hasChanges else {
            return
        }

        do {
            try save()
            persistenceLogger.info("Saved model context from \(source, privacy: .public)")
        } catch {
            persistenceLogger.error("Failed model save from \(source, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
