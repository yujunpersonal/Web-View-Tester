import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var purchaseError: String?
    @State private var showCodeAlert = false
    @State private var unlockCode = ""
    @State private var unlockFailed = false
    @State private var showPurchaseSuccess = false

    var body: some View {
        NavigationStack {
            if showPurchaseSuccess {
                purchaseSuccessPage
            } else {
                mainContent
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 28) {
                // MARK: - Hero
                heroSection

                // MARK: - Benefits
                benefitsSection

                if subscriptionManager.isLifetimeVIP || subscriptionManager.isUnlockedByCode {
                    // Fully unlocked — show banner only
                    activeSubscriptionBanner
                } else if subscriptionManager.isPro && !subscriptionManager.isLifetimeVIP {
                    // Monthly subscriber — show banner + lifetime upgrade option
                    activeSubscriptionBanner

                    if subscriptionManager.isLoading {
                        ProgressView("Loading upgrade option...")
                            .padding()
                    } else if subscriptionManager.products.isEmpty {
                        // Products not loaded yet — let user retry
                        Button("Load Upgrade Option") {
                            Task { await subscriptionManager.loadProducts() }
                        }
                        .buttonStyle(.bordered)
                    } else {
                        lifetimeUpgradeSection
                    }
                } else if subscriptionManager.isLoading {
                    ProgressView("Loading plans...")
                        .padding()
                } else if subscriptionManager.products.isEmpty {
                    errorSection
                } else {
                    // No subscription — show all purchase options
                    purchaseOptionsSection
                }

                // Restore purchases — long press to reveal code entry
                Button("Restore Purchases") {
                    Task { await subscriptionManager.restorePurchases() }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 3)
                        .onEnded { _ in
                            showCodeAlert = true
                        }
                )

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Unlock Unlimited Usage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .alert("Enter Code", isPresented: $showCodeAlert) {
            TextField("Code", text: $unlockCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Redeem") {
                if subscriptionManager.tryUnlock(code: unlockCode) {
                    dismiss()
                } else {
                    unlockFailed = true
                    unlockCode = ""
                }
            }
            Button("Cancel", role: .cancel) {
                unlockCode = ""
            }
        } message: {
            if unlockFailed {
                Text("Invalid code. Please try again.")
            }
        }
    }

    // MARK: - Purchase Success Page

    @ViewBuilder
    private var purchaseSuccessPage: some View {
        ZStack {
            LinearGradient(
                colors: [Color.green.opacity(0.12), Color.yellow.opacity(0.1), Color.white],
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
                        .fill(Color.green.opacity(0.14))
                        .frame(width: 118, height: 118)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 74))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                Text("Purchase Successful")
                    .font(.system(.largeTitle, design: .rounded).bold())

                Text("Welcome to unlimited usage")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if let productName = subscriptionManager.lastPurchasedProductName {
                    Text("Unlocked: \(productName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                Text("You now have full access to every testing flow. Go celebrate with your next auth test.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Label("Start Testing", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
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

    // MARK: - Hero Section

    @ViewBuilder
    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 24)

            Text("Unlock Unlimited Usage")
                .font(.title.bold())

            Text("Get the most out of Great Web View Tester")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Benefits Section

    @ViewBuilder
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What you'll get")
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

    // MARK: - Purchase Options (for non-subscribers)

    @ViewBuilder
    private var purchaseOptionsSection: some View {
        VStack(spacing: 16) {
            Text("Choose your plan")
                .font(.headline)

            // Monthly subscription
            if let subscription = subscriptionManager.subscriptionProducts.first {
                purchaseOptionCard(
                    icon: "calendar",
                    iconColor: .blue,
                    title: "Monthly",
                    subtitle: "Billed monthly, cancel anytime",
                    price: subscription.displayPrice,
                    pricePeriod: "/ month",
                    buttonTitle: "Subscribe \(subscription.displayPrice) / month",
                    buttonColor: .blue,
                    product: subscription
                )
            }

            // Lifetime
            if let lifetime = subscriptionManager.lifetimeProduct {
                purchaseOptionCard(
                    icon: "crown.fill",
                    iconColor: .orange,
                    title: "Lifetime",
                    subtitle: "One-time purchase, yours forever",
                    price: lifetime.displayPrice,
                    pricePeriod: "one-time",
                    buttonTitle: "Buy Lifetime for \(lifetime.displayPrice)",
                    buttonColor: .orange,
                    product: lifetime,
                    highlight: true
                )
            }

            if let error = purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Lifetime Upgrade (for monthly subscribers)

    @ViewBuilder
    private var lifetimeUpgradeSection: some View {
        if let lifetime = subscriptionManager.lifetimeProduct {
            VStack(spacing: 16) {
                // Prominent upgrade banner
                VStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)

                    Text("Upgrade to Lifetime")
                        .font(.title2.bold())

                    Text("Pay once, use forever — no more monthly renewals!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // Price comparison
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("Monthly")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        if let sub = subscriptionManager.currentSubscription {
                            Text(sub.displayPrice)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .strikethrough()
                            Text("recurring")
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

                if let error = purchaseError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Error Section

    @ViewBuilder
    private var errorSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.orange)
            Text("Unable to load purchase options.")
                .font(.subheadline)
            Text("Please check your network connection and try again.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task { await subscriptionManager.loadProducts() }
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .padding()
    }

    // MARK: - Active Subscription Banner

    private var activeSubscriptionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                if subscriptionManager.isLifetimeVIP {
                    Text("Permanently Unlocked")
                        .font(.headline)
                    Text("Unlimited usage forever")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if subscriptionManager.isUnlockedByCode {
                    Text("Unlocked")
                        .font(.headline)
                    Text("Activated by code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("You're subscribed!")
                        .font(.headline)
                    if let expDate = subscriptionManager.subscriptionExpirationDate {
                        Text("Unlimited usage until \(expDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let product = subscriptionManager.currentSubscription {
                        Text(product.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Reusable Components

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

    private func purchaseOptionCard(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        price: String,
        pricePeriod: String,
        buttonTitle: String,
        buttonColor: Color,
        product: Product,
        highlight: Bool = false
    ) -> some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price)
                        .font(.title3.bold())
                    Text(pricePeriod)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task {
                    do {
                        let success = try await subscriptionManager.purchase(product)
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
                    Text(buttonTitle)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(buttonColor)
            .disabled(subscriptionManager.isPurchasing)
        }
        .padding()
        .background(highlight ? buttonColor.opacity(0.08) : Color(.systemGray6))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(highlight ? buttonColor : Color(.systemGray4), lineWidth: highlight ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func dividerWithText(_ text: String) -> some View {
        HStack {
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
            Text(text)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
        }
    }
}

// MARK: - Subscription Period Display

extension Product.SubscriptionPeriod {
    var displayUnit: String {
        switch unit {
        case .day: return value == 7 ? "week" : "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return "period"
        }
    }
}
