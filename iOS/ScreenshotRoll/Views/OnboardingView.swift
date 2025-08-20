import SwiftUI

struct OnboardingView: View {
	@Environment(.dismiss) private var dismiss
	var body: some View {
		VStack(spacing: 20) {
			Text("Import only what you choose. Works offline.")
				.font(.title3)
				.multilineTextAlignment(.center)
				.padding()
			Image(systemName: "lock.square")
				.font(.system(size: 60))
				.foregroundStyle(.secondary)
			Text("No Photos permission requested. Use the Photo Picker or Share Extension.")
				.multilineTextAlignment(.center)
				.foregroundStyle(.secondary)
			Button("Get Started") { dismiss() }
				.buttonStyle(.borderedProminent)
		}
		.padding()
	}
}