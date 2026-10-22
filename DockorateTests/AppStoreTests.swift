import XCTest
@testable import Dockorate

/// What the Mac App Store version changes: it's paid for on the App Store, so it never asks for a
/// license key, and both versions carry the privacy manifest Apple requires. (The App Store build itself,
/// sandboxed and without Sparkle, is checked by scripts/check-appstore-build.sh.)
final class AppStoreTests: XCTestCase {
    @MainActor func testAppStoreVersionIsActiveWithoutAKey() {
        let license = LicenseManager(appStore: true)
        XCTAssertTrue(license.isActive)
        XCTAssertTrue(license.isAppStore)
        XCTAssertNil(license.key, "it never reads the Keychain")
    }

    @MainActor func testAppStoreVersionIgnoresLicenseKeys() async {
        let license = LicenseManager(appStore: true)
        await license.activate("XXXXXXXX-XXXXXXXX-XXXXXXXX-XXXXXXXX")
        XCTAssertNil(license.key)
        XCTAssertNil(license.error)
        XCTAssertFalse(license.isActivating)
        XCTAssertTrue(license.isActive)
    }

    @MainActor func testWebsiteVersionStillUsesLicenseKeysAndSparkle() {
        XCTAssertFalse(AppEnvironment.isAppStore, "the tests run in the website version")
        XCTAssertFalse(LicenseManager(appStore: false).isAppStore)
        XCTAssertTrue(Updater.isAvailable)
    }

    func testPrivacyManifestIsIncluded() throws {
        let url = try XCTUnwrap(Bundle(for: AppModel.self).url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
                                "PrivacyInfo.xcprivacy is in the app")
        let manifest = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: Any])
        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.count, 0, "collects no data")
        let reasons = (manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []).reduce(into: [String: [String]]()) {
            $0[$1["NSPrivacyAccessedAPIType"] as? String ?? ""] = $1["NSPrivacyAccessedAPITypeReasons"] as? [String]
        }
        XCTAssertEqual(reasons["NSPrivacyAccessedAPICategoryUserDefaults"], ["CA92.1"])
        XCTAssertEqual(reasons["NSPrivacyAccessedAPICategorySystemBootTime"], ["35F9.1"])
    }
}
