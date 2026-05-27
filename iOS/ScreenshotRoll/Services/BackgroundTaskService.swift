import Foundation
import BackgroundTasks

enum BackgroundTaskService {
    private static let taskIdInfoKey = "BGTaskIdentifier"
    private static let fallbackTaskId = "com.tonyv2289.screenshotroll.indexing"

    static var indexingIdentifier: String {
        let configuredId = Bundle.main.object(forInfoDictionaryKey: taskIdInfoKey) as? String
        let trimmed = configuredId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallbackTaskId : trimmed
    }

    static func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: indexingIdentifier, using: nil) { task in
            guard let task = task as? BGProcessingTask else { return }
            handleIndexing(task: task)
        }
    }

    static func scheduleIndexingIfNeeded() {
        let request = BGProcessingTaskRequest(identifier: indexingIdentifier)
        request.requiresExternalPower = false
        request.requiresNetworkConnectivity = false
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handleIndexing(task: BGProcessingTask) {
        let workTask = Task {
            await ShareInboxProcessor.processPending()
            if !Task.isCancelled {
                task.setTaskCompleted(success: true)
            }
        }

        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
