# Browser Traffic Control

Browser Traffic Control is a native macOS link router inspired by Arc Air Traffic Control. It receives external HTTP/HTTPS links, applies ordered URL rules, and opens the link directly in a selected Dia profile.

It does not replace or render a browser. macOS sends external links to the default browser first; Browser Traffic Control uses that handoff to apply rules, then forwards the link to Dia. Dia is the first supported browser adapter. The routing core is separated so additional adapters can be added later.

## Features

- Ordered first-match-wins URL rules with `*` and `**` patterns.
- Native Dia profile discovery and pickers.
- Default profile fallback and unavailable-profile preservation.
- HTTP/HTTPS default-browser validation and setup guidance.
- URL preview, visible edit/reorder/delete actions, and background URL handling.
- Safe AppleScript argument passing; URLs and profile names are never interpolated into script source.
- Cached URL-pattern compilation and serialized routing.

## Requirements

- macOS 13 or newer
- Dia installed (tested with Dia 1.48.0)
- Automation permission for Browser Traffic Control to control Dia

## Installation

Download a versioned ZIP from GitHub Releases, verify its SHA-256 checksum, unzip it, and drag `Browser Traffic Control.app` to `/Applications`. Public releases should be Developer ID signed and notarized before distribution; unsigned local builds may trigger macOS security warnings.

The repository includes reproducible packaging, but signed releases require maintainer Developer ID/notarization credentials.

## First run

1. Open Browser Traffic Control normally to edit settings.
2. Click **Make Default Browser**, or choose it in System Settings → Desktop & Dock → Default web browser.
3. Approve Automation access to Dia in System Settings → Privacy & Security → Automation.
4. Refresh Dia profiles and choose a default destination.
5. Add ordered rules. The first matching rule wins.

Keep one installed copy of the app, preferably `/Applications/Browser Traffic Control.app`. macOS LaunchServices can retain stale registrations for copies launched from a build or `dist` folder. If another app opens a link unexpectedly, quit or remove duplicate local copies, launch the `/Applications` copy, then use **Check Again** and confirm both HTTP and HTTPS show as configured.

The app checks both HTTP and HTTPS and distinguishes fully configured, partial, unavailable, and not-configured states. Missing saved profiles remain visible as unavailable instead of being silently replaced.

## Examples

```text
https://github.com/acme/**  → Dia / Work
https://*.atlassian.net/** → Dia / Work
https://mail.google.com/** → Dia / Personal
```

Use **Preview match** to inspect a rule decision without opening a tab.

## Troubleshooting

- **Profiles not loaded:** Click **Refresh**. Dia must be running with at least one window, and macOS Automation permission must allow Browser Traffic Control to control Dia.
- **A link did not route:** Check the default-browser status, confirm the profile still exists, and use **Preview match** to inspect the selected destination.
- **A CLI says it opened the default browser but Safari appears:** Verify that Browser Traffic Control is installed in `/Applications` and that there is not an older source/build copy registered under the same bundle ID. Re-open the installed copy, click **Check Again**, and test with a harmless link. Some tools may explicitly select Safari or another browser instead of using macOS LaunchServices; Browser Traffic Control cannot intercept those explicit launches.
- **macOS blocks the app:** Unsigned local builds may require opening the app from Finder and approving the macOS warning. Public releases should be signed and notarized by the maintainer before broad distribution.

## Privacy and security

Settings are stored locally in `~/Library/Application Support/BrowserTrafficControl/settings.json`. The app does not collect analytics or transmit browsing history. Diagnostics are opt-in and never log full URLs or profile names. Automation permission is used only to query Dia and create tabs. URLs are passed as arguments, not embedded in AppleScript source.

## Performance

Matcher-only benchmarking:

```sh
swift run -c release BrowserTrafficControlMatchBenchmark
```

Final external-routing benchmark on a MacBook Pro Mac15,6, Apple M3 Pro, macOS 26.6.2, Dia 1.48.0 build 86796:

| Path | Count | Min | Median | P95 | Max |
|---|---:|---:|---:|---:|---:|
| Router warm | 30 | 592.53 ms | 685.47 ms | 759.99 ms | 1333.51 ms |
| Router cold | 10 | 741.62 ms | 754.04 ms | 766.43 ms | 840.31 ms |
| Direct Dia baseline | 30 | 410.31 ms | 508.81 ms | 563.68 ms | 721.30 ms |

Timing stops when Dia acknowledges tab creation and excludes page load. Added overhead is an independent-median comparison: about 176.65 ms warm and 245.22 ms cold. Results vary by machine/session.

## Build and development

```sh
swift build -c release
swift test
swift run -c release BrowserTrafficControlValidation
./scripts/package-release.sh
```

The package script creates a ZIP and SHA-256 checksum. `VERSION` is the version source of truth; tags should match it, such as `v0.1.0`.

Opt-in stage diagnostics:

```sh
BROWSER_TRAFFIC_CONTROL_DIAGNOSTICS=1 open -a "Browser Traffic Control"
```

External routing benchmark:

```sh
swift run -c release BrowserTrafficControlBenchmark 30
```

## CI and releases

`.github/workflows/ci.yml` validates pull requests and pushes on macOS. Version-tag releases fail closed until signing/notarization is configured. Maintainers must provide encrypted Developer ID and notarization secrets (including `DEVELOPER_ID_CERTIFICATE_BASE64` and `MACOS_NOTARY_KEY_BASE64`) and complete the signing/upload steps before publishing artifacts.

No automatic updater is enabled. GitHub Releases is the current update path. Sparkle 2 or a maintained Homebrew Cask can be added after signed/notarized releases and private update keys are available; the app will not silently execute unsigned downloads.

## Screenshots

- [Dark appearance](Screenshots/browser-traffic-control-dark.png)
- [Light appearance](Screenshots/browser-traffic-control-light.png)

## Limitations and roadmap

- Dia’s profile AppleScript interface is undocumented and may change.
- This handles external links, not links clicked inside Dia.
- Public signed/notarized release automation is not configured yet.
- Future work may add browser adapters, Sparkle updates, and a maintained Homebrew Cask.

## License

MIT. See [LICENSE](LICENSE).
