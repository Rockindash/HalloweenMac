import AppKit
import Security
import SwiftUI

/// Dockorate is sold on Gumroad. A license key is checked with Gumroad once, when it's entered, and kept
/// in the Keychain; after that the app works offline. Every week or so, when the Mac is online, the key is
/// quietly checked again, and only a definite answer from Gumroad (no such key, or a refund) takes it away.
@MainActor
final class LicenseManager: ObservableObject {
    static let gumroadProductID = "4r29ikg9IO75pyaJF9miEw=="
    static let buyURL = URL(string: "https://rockindash.gumroad.com/l/dockorate")!

    private static let verifyURL = URL(string: "https://api.gumroad.com/v2/licenses/verify")!
    private static let recheckInterval: TimeInterval = 7 * 24 * 60 * 60
    private static let lastVerifiedKey = "licenseLastVerified"
    #if DEBUG
    /// Accepted without asking Gumroad, in Debug builds only, for testing.
    private static let developmentKey = "DOCKORATE-DEV"
    #endif

    /// The activated key, or nil when Dockorate isn't activated on this Mac.
    @Published private(set) var key: String?
    @Published private(set) var isActivating = false
    /// Why the last activation didn't work.
    @Published var error: String?

    private var recheckTimer: Timer?

    var isActive: Bool { key != nil }

    /// The key with all but its last four characters hidden.
    var maskedKey: String {
        guard let key else { return "" }
        return "•••• •••• " + key.suffix(4)
    }

    init() {
        key = Keychain.read()
    }

    func start() {
        Task { await recheckIfDue() }
        recheckTimer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.recheckIfDue() }
        }
    }

    /// Checks a newly entered key with Gumroad and, if it's good, keeps it.
    func activate(_ entered: String) async {
        let candidate = entered.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, !isActivating else { return }
        error = nil
        #if DEBUG
        if candidate == Self.developmentKey {
            store(candidate)
            return
        }
        #endif
        isActivating = true
        defer { isActivating = false }
        switch await Self.verify(candidate, countActivation: true) {
        case .valid:
            store(candidate)
        case .invalid(let message):
            error = message
        case .unreachable:
            error = "Can't reach Gumroad. Check your internet connection and try again."
        }
    }

    /// Takes the license off this Mac, say to move it to another one.
    func remove() {
        Keychain.delete()
        UserDefaults.standard.removeObject(forKey: Self.lastVerifiedKey)
        key = nil
        error = nil
    }

    /// Asks Gumroad about the key again if it's been a week. Only a definite "no" removes it;
    /// being offline or Gumroad having trouble never does.
    func recheckIfDue() async {
        guard let key else { return }
        #if DEBUG
        if key == Self.developmentKey { return }
        #endif
        let last = UserDefaults.standard.object(forKey: Self.lastVerifiedKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= Self.recheckInterval else { return }
        switch await Self.verify(key, countActivation: false) {
        case .valid:
            UserDefaults.standard.set(Date(), forKey: Self.lastVerifiedKey)
        case .invalid:
            if self.key == key { remove() }
        case .unreachable:
            break
        }
    }

    private func store(_ newKey: String) {
        Keychain.save(newKey)
        UserDefaults.standard.set(Date(), forKey: Self.lastVerifiedKey)
        key = newKey
    }

    // MARK: Gumroad

    private enum Verdict {
        case valid
        case invalid(String)
        /// Offline, timed out, or Gumroad didn't give a clear answer.
        case unreachable
    }

    private struct Response: Decodable {
        struct Purchase: Decodable {
            var refunded: Bool?
            var disputed: Bool?
            var chargebacked: Bool?
        }
        var success: Bool
        var message: String?
        var purchase: Purchase?
    }

    private static func verify(_ key: String, countActivation: Bool) async -> Verdict {
        var request = URLRequest(url: verifyURL, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let fields = ["product_id": gumroadProductID, "license_key": key,
                      "increment_uses_count": countActivation ? "true" : "false"]
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        request.httpBody = fields
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode else { return .unreachable }
        // Gumroad answers an unknown key with a 404 and success false; a server error isn't an answer.
        guard status < 500, let body = try? JSONDecoder().decode(Response.self, from: data) else { return .unreachable }
        guard body.success else {
            return .invalid(body.message ?? "That license key isn't valid.")
        }
        let purchase = body.purchase
        if purchase?.refunded == true { return .invalid("This purchase was refunded, so its license key no longer works.") }
        if purchase?.disputed == true || purchase?.chargebacked == true {
            return .invalid("This purchase was disputed, so its license key no longer works.")
        }
        return .valid
    }
}

/// The license key, kept in the login Keychain.
private enum Keychain {
    private static let service = "com.amol.dockorate.license"
    private static let account = "license"

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func read() -> String? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ key: String) {
        delete()
        var item = query
        item[kSecValueData as String] = Data(key.utf8)
        SecItemAdd(item as CFDictionary, nil)
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Views

/// "Enter your license key": shown in the welcome window and the app window until Dockorate is activated.
struct LicenseCard: View {
    @ObservedObject var license: LicenseManager
    @State private var entered = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Badge(symbol: "key.fill", color: .pumpkin)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enter your license key").font(.headline)
                    Text("You'll find it in your Gumroad receipt. The harvest appears on your Dock once Dockorate is activated.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 8) {
                TextField("XXXXXXXX-XXXXXXXX-XXXXXXXX-XXXXXXXX", text: $entered)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .disableAutocorrection(true)
                    .onSubmit(activate)
                    .disabled(license.isActivating)
                if license.isActivating {
                    ProgressView().controlSize(.small).frame(width: 20)
                }
                Button("Activate", action: activate)
                    .buttonStyle(.borderedProminent)
                    .tint(.pumpkin)
                    .disabled(entered.trimmingCharacters(in: .whitespaces).isEmpty || license.isActivating)
            }
            if let error = license.error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 4) {
                Text("Don't have one yet?").foregroundStyle(.secondary)
                Link("Buy Dockorate", destination: LicenseManager.buyURL)
            }
            .font(.callout)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.cardFill))
    }

    private func activate() {
        Task { await license.activate(entered) }
    }
}

/// The app window's Home and Customize pages until Dockorate is activated.
struct LicensePage: View {
    @ObservedObject var license: LicenseManager

    var body: some View {
        PageLayout(title: "Activate Dockorate") {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Decorate your Dock for every season.")
                        .font(.title3.weight(.semibold))
                    Text("Enter the license key from your purchase to grow the harvest on your Dock.")
                        .foregroundStyle(.secondary)
                }
            }
            LicenseCard(license: license)
        }
    }
}
