# Chrome Profile Router

A small macOS app that opens links from other apps in a configured Chrome profile and brings its window to the front. It exits after handing links to Chrome.

## Install

Requires **macOS 13 or later** and **Google Chrome**. The download supports both Apple Silicon and Intel Macs. Xcode and Swift are not required.

1. Download `Chrome-Profile-Router-<version>-universal.zip` from [Releases](https://github.com/kuma0128/chrome-profile-router/releases/latest).
2. Extract it and move **Chrome Profile Router.app** to **Applications**.
3. Open the app once to create your settings. It exits without showing a window.

The app uses ad-hoc signing and is not notarized by Apple. If macOS blocks the first launch, open **System Settings → Privacy & Security → Open Anyway** after attempting to open it, only if you trust the download. See [Apple's instructions](https://support.apple.com/en-us/102445).

To update, replace the app with the latest download. Your settings are preserved.

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

To publish a release, update the version and build number in `Resources/Info.plist`, commit, and push a matching `v<version>` tag. GitHub Actions builds the ZIP, tests it on Apple Silicon and Intel, and publishes it to Releases.
