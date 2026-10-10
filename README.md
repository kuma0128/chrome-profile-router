# Chrome Profile Router

A small macOS app that opens links from other apps in a configured Chrome profile and brings its window to the front. Open the app directly to manage settings and updates. URL launches exit after handing links to Chrome, unless an update check or update window is active.

## Install

Requires **macOS 13 or later** and **Google Chrome**. The download supports both Apple Silicon and Intel Macs. Xcode and Swift are not required.

1. Download `Chrome-Profile-Router-<version>-universal.zip` from [Releases](https://github.com/kuma0128/chrome-profile-router/releases/latest).
2. Extract it and move **Chrome Profile Router.app** to **Applications**.
3. Open the app to create your settings and display the management window. Choose **Open Settings File…** (**設定ファイルを開く…**) to configure your profiles.

The app uses ad-hoc signing and is not notarized by Apple. If macOS blocks the first launch, open **System Settings → Privacy & Security → Open Anyway** after attempting to open it, only if you trust the download. See [Apple's instructions](https://support.apple.com/en-us/102445).

Starting with **1.0.5**, the app checks for updates about once a day while in use. A new version shows a reminder without taking focus from Chrome. Choose **Check for Updates…** (**更新を確認…**) to download and install it, or close the reminder to leave it until later. Sparkle's update window also offers postponing or skipping a version. Settings are preserved.

Open the app directly to check for updates at any time or turn automatic checks off. The app does not run an always-on background service, and installs only after you choose to update. Failed automatic checks do not block links. Updates and their feed are verified with an Ed25519 signature.

**1.0.4 and earlier:** replace the app manually once to enable in-app updates. You can also keep updating manually using the ZIP downloads.

## Language

Starting with **1.0.7**, the app supports English and Japanese. macOS selects the supported language that best matches your preferred languages, falling back to English if none match. Region and keyboard settings do not choose the interface language.

To change only this app's language, use **System Settings → General → Language & Region → Applications**, add **Chrome Profile Router**, and choose English or Japanese. Restart the app to apply the change. Management, update dialogs, errors, and command-line help follow this setting. Configuration keys, profile names, and JSON output stay unchanged.

## Configure

Edit `~/.config/chrome-profile-router/config.json`, created on first launch. For example:

```json
{
  "defaultProfile": "personal",
  "profiles": {
    "personal": "Default",
    "work": "Profile 1"
  },
  "rules": [
    {
      "host": "work.example.com",
      "profile": "work",
      "includeSubdomains": true
    }
  ]
}
```

- Find each profile's directory name in **chrome://version → Profile Path**. Use an existing directory; an unknown name may cause Chrome to create a new profile.
- The first matching host rule wins. Other URLs use `defaultProfile`.
- Set `includeSubdomains` to `true` to include subdomains, or `false` for an exact host match.
- Changes take effect on the next link. Keep personal rules in the user config; the repository's `config.json` is a sample.

## Use

Select **Chrome Profile Router** in **System Settings → Desktop & Dock → Default web browser**. Links opened from other apps will now use your rules. Links clicked inside Chrome are unaffected.

To try it without changing your default browser:

```sh
open -a 'Chrome Profile Router' 'https://example.com/'
```

To check settings or preview routing without opening Chrome:

```sh
router='/Applications/Chrome Profile Router.app/Contents/MacOS/ChromeProfileRouter'
"$router" --check-config
"$router" --resolve 'https://work.example.com/'
```

Use `--open URL [URL ...]` to open links, or `--config PATH` to use another config file. HTTP, HTTPS, and local HTML files (`file:///path/page.html`) are supported.

## Build from source

Requires **Xcode Command Line Tools with Swift 6 or later** (`xcode-select --install`).

```sh
git clone https://github.com/kuma0128/chrome-profile-router.git
cd chrome-profile-router
./scripts/install.sh
```

This builds for your Mac and installs the app in `~/Applications`. Use that path instead of `/Applications` for the CLI commands above. Existing settings are preserved.

```sh
./scripts/build.sh    # Build dist/Chrome Profile Router.app for your Mac
./scripts/test.sh     # Run tests
./scripts/package.sh # Build a universal app and ZIP in dist/
```

To publish a release, update the version and build number in `Resources/Info.plist`, commit, and push a matching `v<version>` tag. GitHub Actions builds the ZIP, tests it on Apple Silicon and Intel, signs the update and `appcast.xml`, and publishes all files to Releases. The app reads the feed from the latest release.

Before tagging, download the ZIP from the successful main-branch workflow and test that exact build on a Mac. Open the management window, choose **設定ファイルを開く…**, and confirm both that TextEdit opens the settings and that the router stays running and responds to **更新を確認…** afterward. Also check a missing `--config` path: dismissing the error must leave the router usable. A local build alone is insufficient because the local and CI Swift toolchains can differ. After publishing, install through the updater and repeat the settings check on the released app.

Localizations live in `Resources/en.lproj/Localizable.strings` and `Resources/ja.lproj/Localizable.strings`. The existing build script copies them into the main app bundle; `String(localized:)` lets Foundation select the language. Keep keys and format placeholders in sync. The unpackaged Swift executable has English source fallbacks; use the built `.app` to test translations. Package checks exercise Japanese, English, regional variants, language priority, and unsupported-language fallback. For UI checks, launch the app binary with `-AppleLanguages '(en)'` or `-AppleLanguages '(ja)'` (Apple's standard per-launch overrides), check the management window and Sparkle dialogs for clipping and mixed languages, and verify the macOS per-app language setting. These launch arguments do not change persistent language preferences.

Release signing requires the repository Actions secret `SPARKLE_PRIVATE_KEY`, matching `SUPublicEDKey` in `Resources/Info.plist`. The maintainer's key is stored in macOS Keychain under service `https://sparkle-project.org`, account `chrome-profile-router`. Keep this key: ad-hoc signed apps cannot rotate it using an Apple Developer ID fallback. Never commit or print the private key. For local packaging, `./scripts/appcast.sh` uses the Keychain after `./scripts/package.sh`.

Sparkle is pinned in `Package.swift` and `Package.resolved`; the build embeds its framework and helper tools. The update signature is separate from Apple Developer ID signing and notarization, which this app does not currently use.

For an end-to-end update test, copy a built app to a separate directory, lower its `CFBundleVersion` and display version, and re-sign that test copy with `codesign --force --sign -`. Point only the test copy's `SUFeedURL` at a local test feed, generated and signed with Sparkle's `generate_appcast`. Test detection, postponing/skipping, installation, relaunch, preserved settings, and links opened during a check. Also verify that a modified feed is rejected. Do not publish test bundles or disable signature verification.

An unchanged 1.0.4 download cannot be installed by a Sparkle-enabled test host: it lacks `SUPublicEDKey`, and Sparkle rejects removing an existing update key. To test against 1.0.4's routing code, add the public-key metadata to a separate 1.0.4 fixture and re-sign it; verify the actual release archive separately. The published 1.0.4 archive stays unchanged.
