# NoShorts

A minimal iOS YouTube tweak that removes Shorts and nothing else:

- removes the **Shorts tab** from the bottom bar
- removes **Shorts shelves** and **single Shorts** from Home, Subscriptions, search and channel pages

Filtering happens on YouTube's data before the page is laid out, so there are no
empty gaps. There is no settings menu. It also includes the usual sign-in/keychain
fixes needed for a re-signed (sideloaded) YouTube.

Tested with YouTube **21.45.4** on iOS 26. Earlier versions back to 21.20 probably
work too, since the tab bar uses a different code path there and both are hooked.

## Build

Requirements: macOS, Xcode, [Theos](https://theos.dev/docs/installation),
[theos-jailed](https://github.com/qnblackcat/theos-jailed), and GNU make
(`brew install make ldid dpkg`).

```sh
git clone --recursive https://github.com/MaxBittker/NoShorts.git
cd NoShorts
export PATH="$(brew --prefix make)/libexec/gnubin:$PATH"
make package IPA=/path/to/decrypted/YouTube.ipa
```

The patched IPA appears in `packages/`. Sign and install it with your own Apple ID
using a tool such as Sideloadly or AltStore. Running `make package` without `IPA=`
builds a `.deb` instead, which you can inject with tools like cyan or Sideloadly.

**This repository does not provide YouTube IPAs.** You need a decrypted YouTube IPA
that you obtained yourself. Don't share patched IPAs. They contain Google's app,
and they may contain your own account's license data.

On a free Apple ID, strip app extensions (theos-jailed does this, or use
`cyan -e`), because each extension uses up one of your limited App IDs.

## Debugging

Build with `NOSHORTS_DEBUG=1`, install the result, then launch it with a console
attached. Sideloaded apps are debuggable:

```sh
xcrun devicectl device process launch --device <UDID> --console \
  --terminate-existing com.google.ios.youtube
```

The log lines are prefixed `[NoShorts]`. They list each feed section, its ELM
component ids, and whether it was filtered. If Shorts reappear after a YouTube
update, these lines show which new identifier to match in `isShortsDescription()`.

## Credits

- Feed filtering and sideloading fixes adapted from
  [uYouEnhanced](https://github.com/arichornlover/uYouEnhanced) /
  [uYouPlus](https://github.com/qnblackcat/uYouPlus)
- Headers: [YouTubeHeader](https://github.com/PoomSmart/YouTubeHeader) by PoomSmart

For personal use only. Not affiliated with Google or YouTube.
