import SwiftUI
import StoreKit

struct ProStatusView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var purchaseError: String?
    @State private var showPurchaseSuccess = false

    var body: some View {
        NavigationStack {
            if showPurchaseSuccess {
                purchaseSuccessPage
            } else if subscriptionManager.isLifetimeVIP || subscriptionManager.isUnlockedByCode {
                permanentThankYouPage
            } else {
                monthlyUpgradePage
            }
        }
    }

    // MARK: - Permanent / Code Unlock — Thank You Page

    @ViewBuilder
    private var permanentThankYouPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Crown hero
                Image(systemName: "crown.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.top, 40)

                Text("Thank You!")
                    .font(.largeTitle.bold())

                Text("You've unlocked unlimited usage permanently.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Benefits unlocked
                benefitsCard

                // Status badge
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        if subscriptionManager.isLifetimeVIP {
                            Text("Permanently Unlocked")
                                .font(.headline)
                            Text("Lifetime purchase — yours forever")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Unlocked by Code")
                                .font(.headline)
                            Text("Activated — unlimited access")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Pro Status")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    // MARK: - Monthly Subscriber — Upgrade Page

    @ViewBuilder
    private var monthlyUpgradePage: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Crown hero
                Image(systemName: "crown.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color(.systemGray3))
                    .padding(.top, 32)

                Text("Your Subscription")
                    .font(.title.bold())

                // Benefits unlocked
                benefitsCard

                // Current plan info
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monthly Plan Active")
                            .font(.headline)
                        if let expDate = subscriptionManager.subscriptionExpirationDate {
                            Text("Unlimited usage until \(expDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let product = subscriptionManager.currentSubscription {
                            Text("\(product.displayPrice) / month, auto-renews")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Upgrade section
                if subscriptionManager.isLoading {
                    ProgressView("Loading upgrade option...")
                        .padding()
                } else if let lifetime = subscriptionManager.lifetimeProduct {
                    upgradeSection(lifetime: lifetime)
                } else {
                    Button("Load Upgrade Option") {
                        Task { await subscriptionManager.loadProducts() }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Pro Status")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    // MARK: - Upgrade Section

    @ViewBuilder
    private func upgradeSection(lifetime: Product) -> some View {
        VStack(spacing: 16) {
            // Divider
            HStack {
                Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                Text("UPGRADE")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Rectangle().fill(Color(.systemGray4)).frame(height: 1)
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)

                Text("Go Lifetime")
                    .font(.title3.bold())

                Text("Pay once, keep it forever — no more renewals!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Price comparison
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Current")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    if let sub = subscriptionManager.currentSubscription {
                        Text(sub.displayPrice)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .strikethrough()
                        Text("/ month")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .font(.title3.bold())
                    .foregroundStyle(.orange)

                VStack(spacing: 4) {
                    Text("Lifetime")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    Text(lifetime.displayPrice)
                        .font(.title3.bold())
                        .foregroundStyle(.orange)
                    Text("one-time")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            // Purchase button
            Button {
                Task {
                    do {
                        let success = try await subscriptionManager.purchase(lifetime)
                        if success {
                            showPurchaseSuccess = true
                        }
                    } catch {
                        purchaseError = error.localizedDescription
                    }
                }
            } label: {
                if subscriptionManager.isPurchasing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("Upgrade to Lifetime for \(lifetime.displayPrice)")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
            .disabled(subscriptionManager.isPurchasing)
            .padding(.horizontal)

            if let error = purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Purchase Success Page

    @ViewBuilder
    private var purchaseSuccessPage: some View {
        ZStack {
            LinearGradient(
                colors: [Color.orange.opacity(0.12), Color.yellow.opacity(0.1), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                HStack(spacing: 22) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }

                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.16))
                        .frame(width: 118, height: 118)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 68))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                Text("Upgrade Successful")
                    .font(.system(.largeTitle, design: .rounded).bold())

                Text("You are now lifetime unlocked")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Unlimited access is now permanent. No renewals, no limits, just testing freedom.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Label("Celebrate", systemImage: "party.popper.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 34)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    // MARK: - Benefits Card (shared)

    @ViewBuilder
    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Benefits Unlocked")
                .font(.headline)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 14) {
                benefitRow(
                    icon: "globe.badge.chevron.backward",
                    color: .blue,
                    title: "Unlimited WKWebView Testing",
                    description: "Test any URL with WKWebView without limits"
                )
                benefitRow(
                    icon: "person.badge.key.fill",
                    color: .green,
                    title: "Unlimited ASWebAuthenticationSession",
                    description: "Test authentication flows for any URL"
                )
                benefitRow(
                    icon: "arrow.triangle.branch",
                    color: .orange,
                    title: "Unlimited Redirection Capture",
                    description: "Capture and inspect all redirections in WKWebView"
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }

    private func benefitRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
