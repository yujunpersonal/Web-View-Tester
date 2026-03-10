import Foundation

enum StoreKitConstants {
    static let proMontly = "great_web_view_tester_advanced"
    static let proPermanently = "cn.buddy.webviewtester.lifetimevip"

    static let subscriptionProductIDs: Set<String> = [
        proMontly
    ]

    static let nonConsumableProductIDs: Set<String> = [
        proPermanently
    ]

    static let allProductIDs: Set<String> = subscriptionProductIDs.union(nonConsumableProductIDs)
}
