# Chrome Profile Router

A small macOS app that opens links from other apps in a configured Chrome profile and brings its window to the front. It exits after handing links to Chrome.

## Requirements

- macOS 13 or later
- Xcode Command Line Tools with Swift 6 or later
- Google Chrome

## Build and install

```sh
git clone https://github.com/kuma0128/chrome-profile-router.git
cd chrome-profile-router
./scripts/install.sh
```

This builds and installs the app at `~/Applications/Chrome Profile Router.app`. Existing user settings are preserved.

To build without installing, or run the tests:

```sh
./scripts/build.sh  # Creates dist/Chrome Profile Router.app
./scripts/test.sh
```

## Configure

Edit `~/.config/chrome-profile-router/config.json`, created on first install. For example:

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
open -a "$HOME/Applications/Chrome Profile Router.app" 'https://example.com/'
```

To check settings or preview routing without opening Chrome:

```sh
router="$HOME/Applications/Chrome Profile Router.app/Contents/MacOS/ChromeProfileRouter"
"$router" --check-config
"$router" --resolve 'https://work.example.com/'
```

Use `--open URL [URL ...]` to open links, or `--config PATH` to use another config file. HTTP, HTTPS, and local HTML files (`file:///path/page.html`) are supported.
