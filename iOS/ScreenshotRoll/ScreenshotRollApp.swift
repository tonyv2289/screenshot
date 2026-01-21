import SwiftUI
import BackgroundTasks

@main
struct ScreenshotRollApp: App {
    @StateObject private var libraryViewModel = LibraryViewModel()
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false

    init() {
        BackgroundTaskService.registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(libraryViewModel)
                .onAppear {
                    BackgroundTaskService.scheduleIndexingIfNeeded()
                }
                .sheet(isPresented: Binding(
                    get: { !hasOnboarded },
                    set: { newValue in
                        if !newValue { hasOnboarded = true }
                    }
                )) {
                    OnboardingView()
                        .presentationDetents([.medium])
                }
        }
    }
}

