import Foundation
import Testing
@testable import AutoPassCore

// MARK: Verification code

@Suite struct VerificationCodeTests {
    @Test func parsesSpacedCode() { #expect(VerificationCode.parse("474 311") == "474311") }
    @Test func parsesNarrowAndBidiSpaces() {
        #expect(VerificationCode.parse("\u{200E}474\u{2009}311\u{200F}") == "474311")
        #expect(VerificationCode.parse("474\u{00A0}311") == "474311")
    }
    @Test func rejectsWrongLength() {
        #expect(VerificationCode.parse("47431") == nil)
        #expect(VerificationCode.parse("4743111") == nil)
        #expect(VerificationCode.parse("") == nil)
    }
    @Test func rejectsNonDigits() {
        #expect(VerificationCode.parse("47A 311") == nil)
        #expect(VerificationCode.parse("٤٧٤ ٣١١") == nil)          // Arabic-Indic digits are not ASCII
        #expect(VerificationCode.parse("Enter code 474 311") == nil)
    }
}

// MARK: Extension identity

@Suite struct ICloudExtensionTests {
    let chrome = "pejdijmoenmkgeppbflobdenhhabjlaj"

    @Test func extensionIDFromHelperArgs() {
        #expect(ICloudExtension.extensionID(fromHelperArguments: ["chrome-extension://\(chrome)/"]) == chrome)
        #expect(ICloudExtension.extensionID(fromHelperArguments: ["--x", "chrome-extension://mfbcdcnpokpoajjciilocoachedjkima/"]) == "mfbcdcnpokpoajjciilocoachedjkima")
    }
    @Test func rejectsUnknownExtension() {
        #expect(ICloudExtension.extensionID(fromHelperArguments: ["chrome-extension://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/"]) == nil)
        #expect(ICloudExtension.extensionID(fromHelperArguments: []) == nil)
        #expect(ICloudExtension.extensionID(fromHelperArguments: ["https://\(chrome)/"]) == nil)
    }
    @Test func popupURLs() {
        #expect(ICloudExtension.isPopupURL("chrome-extension://\(chrome)/page_popup.html", extensionID: chrome))
        #expect(ICloudExtension.isPopupURL("chrome-extension://\(chrome)/page_popup.html?popupWindow=1", extensionID: chrome))
        #expect(!ICloudExtension.isPopupURL("chrome-extension://\(chrome)/page_popup.html?x=1", extensionID: chrome))
        #expect(!ICloudExtension.isPopupURL("chrome-extension://\(chrome)/completion_list.html", extensionID: chrome))
        #expect(!ICloudExtension.isPopupURL("chrome-extension://evil/page_popup.html", extensionID: chrome))
        #expect(!ICloudExtension.isPopupURL("https://\(chrome)/page_popup.html", extensionID: chrome))
        #expect(!ICloudExtension.isPopupURL("chrome-extension://\(chrome).evil.com/page_popup.html", extensionID: chrome))
        #expect(!ICloudExtension.isPopupURL("chrome-extension://\(chrome)/page_popup.html#x", extensionID: chrome))
        #expect(ICloudExtension.isOfficialPopupURL("chrome-extension://mfbcdcnpokpoajjciilocoachedjkima/page_popup.html"))
        #expect(!ICloudExtension.isOfficialPopupURL("chrome-extension://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/page_popup.html"))
    }
}

// MARK: Launch flags & trusted browsers

@Suite struct BrowserTests {
    @Test func flagsDetected() {
        #expect(LaunchFlags.findRisky(in: ["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"]).isEmpty)
        #expect(LaunchFlags.findRisky(in: ["chrome", "--remote-debugging-port=9222", "--user-data-dir=/tmp/x"]) == ["--remote-debugging-port", "--user-data-dir"])
        #expect(LaunchFlags.findRisky(in: ["chrome", "--headless=new"]) == ["--headless"])
        #expect(LaunchFlags.findRisky(in: ["chrome", "--load-extension=/x", "--load-extension=/y"]) == ["--load-extension"])
    }

    @Test func requirementBuiltOnlyFromWellFormedValues() {
        #expect(TrustedBrowser.chrome.codeRequirement == #"identifier "com.google.Chrome" and anchor apple generic and certificate leaf[subject.OU] = "EQHXZ8M8AV""#)
        let evil = TrustedBrowser(name: "x", bundleID: "a", signingID: #"a" or anchor apple or identifier "b"#, teamID: "EQHXZ8M8AV")
        #expect(evil.codeRequirement == nil)
        #expect(TrustedBrowser(name: "x", bundleID: "a.b", signingID: "a.b", teamID: "short").codeRequirement == nil)
        #expect(TrustedBrowser(name: "x", bundleID: "a.b", signingID: "a.b", teamID: "eqhxz8m8av").codeRequirement == nil)
    }

    @Test func parsesRunningChromeFlags() throws {
        // Real process-table read: this machine's Chrome (skipped when Chrome isn't running).
        let pipe = Pipe()
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep"); p.arguments = ["-x", "Google Chrome"]; p.standardOutput = pipe
        try p.run(); p.waitUntilExit()
        let text = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard let pid = text.split(separator: "\n").first.flatMap({ Int32($0) }) else { return }
        let args = ProcessInspector.arguments(of: pid)
        #expect(args.first?.hasSuffix("Google Chrome") == true)
        #expect(ProcessInspector.parentPID(of: pid) != nil)
    }
}

// MARK: Launch constraint reader

@Suite struct LaunchConstraintTests {
    @Test func parsesFixture() throws {
        let url = try #require(Bundle.module.url(forResource: "helper-parent-constraint", withExtension: "der", subdirectory: "Fixtures"))
        let groups = LaunchConstraintReader.groups(fromConstraintDER: try Data(contentsOf: url))
        func ids(_ team: String) -> [String] { groups.first { $0.teamID == team }?.signingIDs ?? [] }
        #expect(ids("EQHXZ8M8AV").contains("com.google.Chrome"))
        #expect(ids("EQHXZ8M8AV").contains("com.google.Chrome.canary"))
        #expect(ids("UBF8T346G9").contains("com.microsoft.edgemac"))
        #expect(ids("4XF3XNRN6Y").contains("com.vivaldi.Vivaldi"))
        #expect(ids("KL8N8XSYF4").contains("com.brave.Browser"))
        #expect(ids("S6N382Y83G").contains("company.thebrowser.Browser"))
        #expect(groups.count > 20)
    }

    @Test func readsLiveHelperBinary() throws {
        guard FileManager.default.fileExists(atPath: LaunchConstraintReader.helperBinaryPath) else { return }
        let groups = try #require(LaunchConstraintReader.allowedBrowsers())
        #expect(groups.contains { $0.teamID == "EQHXZ8M8AV" && $0.signingIDs.contains("com.google.Chrome") })
    }

    @Test func garbageIsRejectedNotCrashed() {
        #expect(LaunchConstraintReader.groups(fromConstraintDER: Data([0x30, 0x84, 0xFF, 0xFF, 0xFF, 0xFF])).isEmpty)
        #expect(LaunchConstraintReader.parentConstraintDER(inMachO: Data(repeating: 0xAB, count: 64)) == nil)
        #expect(LaunchConstraintReader.parentConstraintDER(inMachO: Data()) == nil)
    }
}

// MARK: Policy rules

@Suite struct PairingPolicyTests {
    static let chrome = "pejdijmoenmkgeppbflobdenhhabjlaj"

    /// Facts for a perfectly normal pairing; each test breaks exactly one thing.
    static func good() -> PairingFacts {
        var f = PairingFacts()
        f.helperIsAppleSigned = true
        f.helperExtensionID = chrome
        f.helperParentPID = 100
        f.codeWindowsForBrowser = 1
        f.code = "474 311"
        f.popupCount = 1
        f.popupOwnerPID = 100
        f.browserMatchesTrusted = true
        f.browserIsFrontmost = true
        f.popupURL = "chrome-extension://\(chrome)/page_popup.html"
        f.popupFieldCount = 6
        f.popupFieldsEmpty = true
        f.popupFirstFieldFocused = true
        f.userIdleSeconds = 5
        return f
    }
    let policy = SecurityPolicy()

    @Test func allowsNormalPairing() { #expect(PairingPolicy.evaluate(Self.good(), policy: policy) == nil) }

    @Test func eachRuleBlocks() {
        func deny(_ edit: (inout PairingFacts) -> Void, _ policy: SecurityPolicy? = nil) -> Denial? {
            var f = Self.good(); edit(&f); return PairingPolicy.evaluate(f, policy: policy ?? self.policy)
        }
        #expect(deny { $0.helperIsAppleSigned = false } == .helperNotApple)
        #expect(deny { $0.helperExtensionID = nil } == .helperExtensionUnknown)
        #expect(deny { $0.codeWindowsForBrowser = 2 } == .ambiguousCodeWindows)
        #expect(deny { $0.popupOwnerPID = nil } == .popupNotFound)
        #expect(deny { $0.popupCount = 0 } == .popupNotFound)
        #expect(deny { $0.popupCount = 2 } == .ambiguousPopups)
        #expect(deny { $0.popupOwnerPID = 999 } == .parentMismatch)
        #expect(deny { $0.browserMatchesTrusted = false } == .browserNotTrusted)
        #expect(deny { $0.browserLaunchFlags = ["--remote-debugging-port"] } == .riskyFlags(["--remote-debugging-port"]))
        #expect(deny { $0.browserIsFrontmost = false } == .browserNotFrontmost)
        #expect(deny { $0.popupURL = "chrome-extension://aaaa/page_popup.html" } == .popupWrongPage)
        #expect(deny { $0.popupURL = nil } == .popupWrongPage)
        #expect(deny { $0.popupFieldCount = 1 } == .popupWrongShape(fields: 1))
        #expect(deny { $0.popupFieldsEmpty = false } == .popupNotEmpty)
        #expect(deny { $0.popupFirstFieldFocused = false } == .popupNotFocused)
        #expect(deny { $0.code = "12345" } == .codeMalformed)
        #expect(deny { $0.code = nil } == .codeMalformed)
        #expect(deny { $0.userIdleSeconds = 0.1 } == .userActive)
    }

    @Test func transientVersusHardDenials() {
        for d: Denial in [.popupNotFound, .popupWrongShape(fields: 0), .popupNotEmpty, .popupNotFocused, .userActive, .browserNotFrontmost] {
            #expect(d.isTransient)
        }
        for d: Denial in [.helperNotApple, .helperExtensionUnknown, .browserNotTrusted, .riskyFlags(["--x"]), .popupWrongPage, .ambiguousPopups, .ambiguousCodeWindows, .rateLimited, .parentMismatch, .codeMalformed] {
            #expect(!d.isTransient)
        }
    }

    @Test func policyTogglesRelaxOnlyTheirOwnRule() {
        var relaxed = SecurityPolicy(); relaxed.refuseDebugFlags = false
        var f = Self.good(); f.browserLaunchFlags = ["--user-data-dir"]
        #expect(PairingPolicy.evaluate(f, policy: relaxed) == nil)
        f.browserIsFrontmost = false              // never relaxable
        #expect(PairingPolicy.evaluate(f, policy: relaxed) == .browserNotFrontmost)
        f.browserIsFrontmost = true; f.browserMatchesTrusted = false
        #expect(PairingPolicy.evaluate(f, policy: relaxed) == .browserNotTrusted)
    }

    @Test func rateLimit() {
        #expect(PairingPolicy.evaluate(Self.good(), policy: policy, rateLimited: true) == .rateLimited)
        var l = AttemptLimiter(); let t0 = Date(timeIntervalSince1970: 1_000)
        l.record(at: t0); l.record(at: t0 + 1)
        #expect(!l.isLimited(max: 3, window: 600, now: t0 + 2))
        l.record(at: t0 + 2)
        #expect(l.isLimited(max: 3, window: 600, now: t0 + 3))
        #expect(!l.isLimited(max: 3, window: 600, now: t0 + 700))     // window slid past
    }
}

// MARK: Stored policy

@Suite struct SecurityPolicyTests {
    @Test func roundTripAndDefaults() throws {
        let p = SecurityPolicy()
        #expect(p.approval == .none && p.settingsAuth == .none && p.autoPair == .whenBrowsing)
        #expect(p.refuseDebugFlags)                                         // quiet, but the checks stay on
        let decoded = try JSONDecoder().decode(SecurityPolicy.self, from: JSONEncoder().encode(p))
        #expect(decoded == p)
    }

    @Test func missingKeysFallBackToSecureDefaults() throws {
        let old = #"{"approval":"none"}"#.data(using: .utf8)!
        let p = try JSONDecoder().decode(SecurityPolicy.self, from: old)
        #expect(p.approval == .none)
        #expect(p.schemaVersion == 1)                                       // no version key = v1
        #expect(p.refuseDebugFlags)
        #expect(p.settingsAuth == .none)
        #expect(p.trustedBrowsers == [.chrome])
    }

    @Test func v1PolicyMigratesToQuietDefaultsKeepingBrowsers() throws {
        let edge = TrustedBrowser(name: "Microsoft Edge", bundleID: "com.microsoft.edgemac", signingID: "com.microsoft.edgemac", teamID: "UBF8T346G9")
        let v1 = try JSONDecoder().decode(SecurityPolicy.self, from: JSONEncoder().encode(
            SecurityPolicy(schemaVersion: 1, trustedBrowsers: [.chrome, edge], approval: .deviceOwner, refuseDebugFlags: true, settingsAuth: .deviceOwner)))
        let m = v1.migrated()
        #expect(m.schemaVersion == SecurityPolicy.currentSchema)
        #expect(m.approval == .none && m.settingsAuth == .none)
        #expect(m.trustedBrowsers == [.chrome, edge] && m.refuseDebugFlags)
        // A v2 policy is never touched: someone who turns Touch ID on keeps it.
        let v2 = SecurityPolicy(approval: .biometricsOnly, settingsAuth: .biometricsOnly)
        #expect(v2.migrated() == v2)
        // Biometrics-only in v1 was a deliberate choice; keep it.
        #expect(SecurityPolicy(schemaVersion: 1, approval: .biometricsOnly).migrated().approval == .biometricsOnly)
    }

    @Test func settingsLockSurvivesRoundTripAndReadsTheOldSwitch() throws {
        let p = SecurityPolicy(settingsAuth: .biometricsOnly)
        #expect(try JSONDecoder().decode(SecurityPolicy.self, from: JSONEncoder().encode(p)).settingsAuth == .biometricsOnly)
        // A policy saved before the lock had its own options stored a plain switch.
        let on = try JSONDecoder().decode(SecurityPolicy.self, from: #"{"schemaVersion":2,"protectSettings":true}"#.data(using: .utf8)!)
        #expect(on.settingsAuth == .deviceOwner && on.isSettingsProtected)
        let off = try JSONDecoder().decode(SecurityPolicy.self, from: #"{"schemaVersion":2,"protectSettings":false}"#.data(using: .utf8)!)
        #expect(off.settingsAuth == .none && !off.isSettingsProtected)
    }

    @Test func sanitizeClampsAndDropsMalformedBrowsers() {
        var p = SecurityPolicy()
        p.approvalGraceSeconds = 99_999; p.minimumIdleSeconds = 0; p.maxAttempts = 500; p.attemptWindowMinutes = 0
        p.trustedBrowsers.append(TrustedBrowser(name: "bad", bundleID: "x", signingID: #"x" or true"#, teamID: "EQHXZ8M8AV"))
        let s = p.sanitized()
        #expect(s.approvalGraceSeconds == 900 && s.minimumIdleSeconds == 0.25 && s.maxAttempts == 10 && s.attemptWindowMinutes == 1)
        #expect(s.trustedBrowsers == [.chrome])
    }

    @Test func disabledBrowsersAreNotEnabled() {
        var p = SecurityPolicy(); p.trustedBrowsers[0].isEnabled = false
        #expect(p.enabledBrowsers.isEmpty)
    }
}

// MARK: Extension links

@Suite struct ExtensionLinksTests {
    @Test func edgeUsesItsOwnListingAndID() {
        #expect(ExtensionLinks.extensionID(forSigningID: "com.microsoft.edgemac.Canary") == "mfbcdcnpokpoajjciilocoachedjkima")
        #expect(ExtensionLinks.installURL(forSigningID: "com.microsoft.edgemac").absoluteString
                == "https://microsoftedge.microsoft.com/addons/detail/icloud-passwords/mfbcdcnpokpoajjciilocoachedjkima")
        #expect(ExtensionLinks.manageURL(forSigningID: "com.microsoft.edgemac.Canary").absoluteString
                == "edge://extensions/?id=mfbcdcnpokpoajjciilocoachedjkima")
    }

    @Test func otherChromiumBrowsersUseTheWebStore() {
        for id in ["com.google.Chrome", "com.vivaldi.Vivaldi", "com.brave.Browser", "company.thebrowser.Browser"] {
            #expect(ExtensionLinks.extensionID(forSigningID: id) == "pejdijmoenmkgeppbflobdenhhabjlaj")
            #expect(ExtensionLinks.installURL(forSigningID: id).absoluteString
                    == "https://chromewebstore.google.com/detail/icloud-passwords/pejdijmoenmkgeppbflobdenhhabjlaj")
        }
    }

    @Test func manageLinkUsesTheBrowsersOwnScheme() {
        #expect(ExtensionLinks.manageURL(forSigningID: "com.google.Chrome").scheme == "chrome")
        #expect(ExtensionLinks.manageURL(forSigningID: "com.vivaldi.Vivaldi").scheme == "vivaldi")
        #expect(ExtensionLinks.manageURL(forSigningID: "com.brave.Browser.beta").scheme == "brave")
        #expect(ExtensionLinks.manageURL(forSigningID: "company.thebrowser.Browser").scheme == "arc")
        #expect(ExtensionLinks.manageURL(forSigningID: "com.operasoftware.Opera").scheme == "opera")
        #expect(ExtensionLinks.manageURL(forSigningID: "org.unknown.Browser").scheme == "chrome")
    }
}

@Suite struct DenialCopyTests {
    @Test func messagesAreShortPlainSentences() {
        let all: [Denial] = [.helperNotApple, .helperExtensionUnknown, .ambiguousCodeWindows, .popupNotFound, .ambiguousPopups, .parentMismatch,
                             .browserNotTrusted, .riskyFlags(["--x"]), .browserNotFrontmost, .popupWrongPage, .popupWrongShape(fields: 2),
                             .popupNotEmpty, .popupNotFocused, .codeMalformed, .userActive, .rateLimited]
        for d in all {
            #expect(!d.message.contains(":"), "\(d.message)")
            #expect(!d.message.contains("--"), "\(d.message)")
            #expect(d.message.hasSuffix("."))
        }
    }
}

// MARK: Retrying after interruptions

@Suite struct RetryBackoffTests {
    @Test func growsThenLevelsOffAndNeverStops() {
        #expect(RetryBackoff.delay(afterInterruptions: 0) == 1.5)
        #expect(RetryBackoff.delay(afterInterruptions: 1) == 1.5)
        #expect(RetryBackoff.delay(afterInterruptions: 2) == 3)
        #expect(RetryBackoff.delay(afterInterruptions: 5) == 7.5)
        for n in [14, 50, 10_000] { #expect(RetryBackoff.delay(afterInterruptions: n) == 20) }    // capped, never infinite
    }
}

// MARK: Authentication availability

@Suite struct AuthAvailabilityTests {
    private let both = AuthAvailability(touchID: true, password: true)
    private let noTouchID = AuthAvailability(touchID: false, password: true)
    private let nothing = AuthAvailability(touchID: false, password: false)

    @Test func offStaysOffAndNeverNeedsAnything() {
        for a in [both, noTouchID, nothing] { #expect(a.effective(.none) == ApprovalMode.none) }
    }

    @Test func whatYouChooseIsWhatYouGetWhenItCanBeShown() {
        #expect(both.effective(.biometricsOnly) == .biometricsOnly)
        #expect(both.effective(.deviceOwner) == .deviceOwner)
        #expect(!both.usesFallback(for: .biometricsOnly) && !both.usesFallback(for: .deviceOwner))
    }

    @Test func touchIDFallsBackToThePasswordPromptOnAMacWithoutIt() {
        #expect(noTouchID.effective(.biometricsOnly) == .deviceOwner)
        #expect(noTouchID.usesFallback(for: .biometricsOnly))
        #expect(noTouchID.effective(.deviceOwner) == .deviceOwner)
    }

    @Test func nothingAvailableMeansNoPromptAndNeverSkipsTheCheck() {
        #expect(nothing.effective(.biometricsOnly) == nil)
        #expect(nothing.effective(.deviceOwner) == nil)
        #expect(!nothing.usesFallback(for: .biometricsOnly))
    }
}

// MARK: Localization

@Suite struct LocalizerTests {
    private let french = Localizer(table: [
        "Paired": "Associé",
        "Paired with %@": "Associé à %@",
        "The browser isn't in front.": "Le navigateur n'est pas au premier plan.",
        "AutoPass didn't type the code. %@": "AutoPass n'a pas saisi le code. %@",
        "AutoPass paused because %@. It will try again.": "AutoPass a fait une pause car %@. Il réessaiera.",
        "AutoPass paused because you were busy in %@. It will try again.": "AutoPass a fait une pause car vous étiez occupé dans %@. Il réessaiera.",
        "you switched away from the browser": "vous avez changé de fenêtre",
        "%@ per %@ min": "%2$@ min : %1$@ max",
    ])

    @Test func englishIsLeftAlone() {
        let english = Localizer(table: [:])
        #expect(english.isEnglish)
        #expect(english.translate("Paired with Google Chrome") == "Paired with Google Chrome")
        #expect(english.string("Paired") == "Paired")
        #expect(english.format("Paired with %@", ["Edge"]) == "Paired with %@".replacingOccurrences(of: "%@", with: "Edge"))
    }

    @Test func fixedStringsAndUnknownOnes() {
        #expect(french.string("Paired") == "Associé")
        #expect(french.string("Something new") == "Something new")      // a missing translation shows the English
    }

    @Test func formatFillsPlaceholdersAndAllowsReordering() {
        #expect(french.format("Paired with %@", ["Chrome"]) == "Associé à Chrome")
        #expect(french.format("%@ per %@ min", ["3", "10"]) == "10 min : 3 max")
    }

    @Test func composedSentencesAreMatchedAgainstTemplates() {
        #expect(french.translate("Paired with Google Chrome") == "Associé à Google Chrome")
        // The name can contain anything, including punctuation.
        #expect(french.translate("Paired with Brave (Beta) 1.2") == "Associé à Brave (Beta) 1.2")
    }

    @Test func piecesAreTranslatedToo() {
        #expect(french.translate("AutoPass didn't type the code. The browser isn't in front.")
                == "AutoPass n'a pas saisi le code. Le navigateur n'est pas au premier plan.")
        #expect(french.translate("AutoPass paused because you switched away from the browser. It will try again.")
                == "AutoPass a fait une pause car vous avez changé de fenêtre. Il réessaiera.")
    }

    @Test func theMostSpecificTemplateWins() {
        #expect(french.translate("AutoPass paused because you were busy in Vivaldi. It will try again.")
                == "AutoPass a fait une pause car vous étiez occupé dans Vivaldi. Il réessaiera.")
    }

    @Test func unknownSentencesComeBackUnchanged() {
        #expect(french.translate("Totally different sentence") == "Totally different sentence")
    }
}

// MARK: Translation files

/// The `Localizable.strings` files in Resources: one per language, keyed by the English text.
@Suite struct TranslationFileTests {
    private static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources")

    private static func table(_ code: String) throws -> [String: String] {
        let url = resources.appendingPathComponent("\(code).lproj/Localizable.strings")
        let strings = NSDictionary(contentsOf: url) as? [String: String]
        return try #require(strings, "\(code) couldn't be read")
    }

    private static let codes = ["zh-Hans", "zh-Hant", "es", "fr", "de", "ja", "ko", "pt-BR", "ru", "it"]

    private static func placeholders(_ s: String) -> Int {
        (try? NSRegularExpression(pattern: "%(?:[0-9]+\\$)?@"))?.numberOfMatches(in: s, range: NSRange(s.startIndex..., in: s)) ?? 0
    }

    @Test func englishIsTheTemplate() throws {
        let english = try Self.table("en")
        #expect(english.count > 150)
        for (key, value) in english { #expect(key == value, "en: \(key)") }
    }

    @Test func everyLanguageTranslatesEveryString() throws {
        let english = try Self.table("en")
        for code in Self.codes {
            let table = try Self.table(code)
            #expect(Set(table.keys) == Set(english.keys), "\(code) has different keys than English")
            for (key, value) in table { #expect(!value.trimmingCharacters(in: .whitespaces).isEmpty, "\(code): empty for \(key)") }
        }
    }

    @Test func translationsKeepTheirPlaceholders() throws {
        let english = try Self.table("en")
        for code in Self.codes {
            let table = try Self.table(code)
            for key in english.keys {
                #expect(Self.placeholders(table[key] ?? "") == Self.placeholders(key), "\(code): placeholders differ in \(key)")
            }
        }
    }

    @Test func aTranslatedActivityMessageIsRecognised() throws {
        let localizer = Localizer(table: try Self.table("de"))
        #expect(localizer.translate("Paired with Google Chrome") == "Mit Google Chrome gekoppelt")
        #expect(localizer.translate("AutoPass didn't type the code. The browser isn't in front.")
                == "AutoPass hat den Code nicht eingetippt. Der Browser ist nicht im Vordergrund.")
    }
}
