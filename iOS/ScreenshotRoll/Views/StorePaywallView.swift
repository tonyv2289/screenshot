import SwiftUI
import StoreKit

struct StorePaywallView: View {
    @EnvironmentObject var store: StoreService
    @Environment(\.dismiss) private var dismiss

    let reason: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Upgrade Your Screenshot Brain")
                            .font(.title2.weight(.bold))
                        Text(reason.isEmpty ? "Unlock unlimited memory recall and advanced organization." : reason)
                            .foregroundStyle(.secondary)
                    }

                    featureRow(
                        icon: "infinity",
                        title: "Unlimited Memories",
                        subtitle: "Import without free-tier caps."
                    )
                    featureRow(
                        icon: "point.3.filled.connected.trianglepath.dotted",
                        title: "Full Brain Constellation",
                        subtitle: "See complete recall maps, not shortened previews."
                    )
                    featureRow(
                        icon: "brain.head.profile",
                        title: "Pro Recall Tools",
                        subtitle: "Get premium intelligence workflows as they ship."
                    )

                    VStack(spacing: 10) {
                        purchaseButton(
                            title: "Pro Yearly",
                            subtitle: yearlyPriceText,
                            action: { await store.purchaseYearly() }
                        )
                        purchaseButton(
                            title: "Lifetime",
                            subtitle: lifetimePriceText,
                            action: { await store.purchaseLifetime() }
                        )
                    }

                    Button("Restore Purchases") {
                        Task { await store.restorePurchases() }
                    }
                    .font(.footnote.weight(.semibold))

                    if let error = store.storeErrorMessage, !error.isEmpty {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Pro Plans")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: store.hasPremium) { hasPremium in
                if hasPremium {
                    dismiss()
                }
            }
            .task {
                await store.loadProducts()
                await store.refreshEntitlements()
            }
        }
    }

    private var yearlyPriceText: String {
        store.yearlyProduct?.displayPrice ?? "$35/year"
    }

    private var lifetimePriceText: String {
        store.lifetimeProduct?.displayPrice ?? "$60 one-time"
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 24)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func purchaseButton(title: String, subtitle: String, action: @escaping () async -> Bool) -> some View {
        Button {
            Task {
                _ = await action()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.isPurchasing {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(store.isPurchasing)
    }
}
