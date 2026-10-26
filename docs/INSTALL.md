# Install Mileage on your iPhone

The repository contains source code. It is not an installable website or signed iPhone build yet. You do not need a public App Store release to test it privately.

## Development install with a Mac

1. Clone/download this repository and open `Mileage.xcodeproj` in Xcode.
2. Under Mileage → Signing & Capabilities, select your Apple development team. Replace `com.stealthorange.mileage` with an available bundle ID owned by your team if necessary.
3. Connect and trust your iPhone, enable Developer Mode if Xcode requests it, select the phone, and Run.
4. Start a test trip. Grant location access with Precise Location enabled. A trip started in the foreground is configured to continue with the screen locked; iOS displays its location indicator.
5. Complete [the device checklist](DEVICE_TESTS.md) before relying on your records.

A free Personal Team can be used for development subject to Apple's signing and capability limits and periodic reinstallation. A paid Developer Program membership is the practical route to TestFlight. This project does not contain a signing team or certificates.

## Private beta through TestFlight

1. Enroll in the [Apple Developer Program](https://developer.apple.com/programs/enroll/). Apple's standard annual fee is USD $99, subject to local currency and eligibility terms.
2. Register your bundle ID and create an iOS app record named Mileage in App Store Connect. Match the project's bundle identifier. You must own a suitable name/identifier; the placeholder does not reserve either.
3. Select your signing team in Xcode. Verify Background Modes → Location updates remains enabled.
4. Select a generic iOS device, then Product → Archive. Validate and distribute the archive to App Store Connect from Xcode's Organizer.
5. After processing, complete export-compliance and beta information. Add yourself as an internal tester with the appropriate App Store Connect role and install using Apple's TestFlight app. If testing externally, Apple's beta review requirements apply.
6. Run the physical-device checklist. No public App Store launch is required.

TestFlight builds expire after **90 days**. Upload a new build (with a higher build number) before expiry to keep testing. TestFlight is a beta distribution method, not a permanent install with no maintenance.

The GitHub Actions workflow builds an **unsigned simulator app** and runs tests. It deliberately does not upload to TestFlight and cannot produce a usable iPhone install without signing configuration. For phone-only development, a separately configured macOS build/signing workflow is needed; this repository alone cannot install an app from Safari.

Do not share Apple passwords, private signing keys, certificates, or provisioning profiles in chat, issues, commits, or pull requests. Configure future automated signing through the build platform's private credential storage.

References: [Apple distribution overview](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases), [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/), [build expiry](https://testflight.apple.com/).
