//
//  ArchiveViewModel+ProgressTasks.swift
//  Arkyve
//
//  Created by Chris Jones on 17/07/2025.
//

extension ArchiveViewModel {
    func withProgressTask(_ task: @escaping () async -> Void) {
        disableUI = true

        progressTask = Task {
            await task()

            disableUI = false
            progressTask = nil
            isCancelling = false
        }
    }

    func waitForArchiveProgressTask() async throws {
        NSLog("waitForArchiveProgressTask(): Sleeping until archive is loaded...")
        var sleepIndex = 0
        var timeoutIndex = 0
        while progressTask != nil {
            try await Task.sleep(for: .seconds(0.5))
            sleepIndex += 1
            if sleepIndex > 20 {
                NSLog("waitForArchiveProgressTask(): Still sleeping...")
                sleepIndex = 0
                timeoutIndex += 1
            }
            if timeoutIndex > 30 {
                NSLog("waitForArchiveProgressTask(): Giving up sleep after 5 minutes...")
                throw ArkyveError(.extract, msg: "Timed out waiting for task to complete")
            }
        }
        NSLog("waitForArchiveProgressTask(): Waking up after task completed.")
        if let error = errors.error {
            throw error
        }
    }
}
