import Foundation

enum StoreKitConstants {
    static let proMontly = "cn.buddy.web_view_tester.pro_monthly"
    static let proPermanently = "cn.buddy.web_view_tester.pro_lifetime"

    static let subscriptionProductIDs: Set<String> = [
        proMontly
    ]

    static let nonConsumableProductIDs: Set<String> = [
        proPermanently
    ]

    static let allProductIDs: Set<String> = subscriptionProductIDs.union(nonConsumableProductIDs)
}
