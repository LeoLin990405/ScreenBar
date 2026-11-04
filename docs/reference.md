# ScreenBar reference

Detailed reference for the CLI surface, the on-disk JSON files, the status rules, and the `doctor`
checks. Everything here is derived from the sources in [`../Sources/ScreenBar`](../Sources/ScreenBar);
the README keeps only the summary.

- [CLI behaviour](#cli-behaviour)
- [Device model and `devices.json`](#device-model-and-devicesjson)
- [Status rules](#status-rules)
- [Link classification](#link-classification)
- [`status.json`](#statusjson)
- [`doctor` checks](#doctor-checks)
- [Constants and paths](#constants-and-paths)
- [Troubleshooting](#troubleshooting)
- [Tests and CI](#tests-and-ci)

## CLI behaviour

Entry point: [`../Sources/ScreenBar/main.swift`](../Sources/ScreenBar/main.swift). The first argument is
matched against the command set in [`../Sources/ScreenBar/CLI/CLI.swift`](../Sources/ScreenBar/CLI/CLI.swift):

`status`, `list`, `connect`, `disconnect`, `view`, `unview`, `jump`, `wake`, `doctor`, `help`, `-h`,
`--help`.

A known first argument runs the CLI and exits with status `0`. Anything else — including no argument or
a device id — launches the menu-bar UI. There is no "wait" or "daemon" command: the CLI reads the device
file, performs one action, and returns.

| Command | Missing-argument behaviour | Notes |
|---|---|---|
| `status` | — | one line per device, refreshed live before printing |
| `list` | — | tab-separated `id`, `label`, `modes`, `host`, `note`; no network calls |
| `connect <id>` | prints `用法: screenbar connect <id>` | returns immediately after the SSH trigger; connection is not confirmed |
| `disconnect <id>` | prints usage | also disconnects the device's virtual screen |
| `view <id>` | prints usage | `open vnc://<host>` |
| `unview` | — | quits the Screen Sharing app, closing **all** view windows on this Mac |
| `jump <id>` | prints usage, or notes a missing `jumpID` | `open jump://connect?id=<jumpID>` |
| `wake <id>` | prints usage, or notes a missing MAC | no-op without a stored `macAddress` |
| `doctor` | — | environment checks plus per-device checks |
| `help` / `-h` / `--help` | — | usage text, also printed for an unknown subcommand |

Output formats written by the CLI:

```text
# status
  <id padded to 8> <label padded to 12> <state>[ · 可查看][ · <link label>]
# state is one of: 副屏中 / 查看中 / 在线 / 离线

# list (tab-separated)
<id>\t<label>\t<modes rawValue>\t<host>\t<note>

# doctor
ScreenBar 自检

环境:
  ✓ <check name> — <detail>
设备:
  ▸ <label>(<id>)
      ⚠ <check name> — <detail>
```

`doctor` levels are `✓` (ok), `⚠` (warn), and `✗` (fail).

## Device model and `devices.json`

The persisted type is `Device` in
[`../Sources/ScreenBar/Model/Device.swift`](../Sources/ScreenBar/Model/Device.swift); it is encoded as a
pretty-printed JSON array with sorted keys. Defaults shown are the values used when a field is omitted.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `id` | string | — | short identifier, e.g. `m2`; also used to name the virtual screen |
| `label` | string | — | name shown in the menu |
| `modes` | string | — | `screen` (peer becomes a second screen), `view` (view the peer here), `both` |
| `host` | string | — | Tailscale IP or LAN address used for reachability probes and `open vnc://` |
| `sshPort` | int | `22` | port probed by `nc -z` to decide "online" |
| `sshTarget` | string | `-` | SSH alias or `user@ip` for the default trigger; `-` disables it |
| `note` | string | empty | free-form note shown by `screenbar list` |
| `resolution` | string | `1440x900` | requested resolution for this device's virtual screen |
| `hiDPI` | bool | `false` | turns on `virtualScreenHiDPI` for the virtual screen |
| `autoConnect` | bool | `false` | attach as a second screen as soon as the device is online |
| `macAddress` | string? | `nil` | Wake-on-LAN target; back-filled over SSH when the device is online |
| `jumpID` | string? | `nil` | Jump Desktop computer UUID; when set, the view direction uses Fluid |
| `triggerOn` | string? | `nil` | full shell command replacing the default connect SSH command |
| `triggerOff` | string? | `nil` | full shell command replacing the default disconnect SSH command |

`virtualScreenName` is computed as `ScreenBar-<id>` and is never stored. A file with a single device
looks like this (values match the first-run seed shipped in `ConfigStore.seed`):

```json
[
  {
    "autoConnect" : false,
    "hiDPI" : false,
    "host" : "192.0.2.10",
    "id" : "mac1",
    "label" : "Example-Mac",
    "modes" : "both",
    "note" : "示例:副屏+查看",
    "resolution" : "1440x900",
    "sshPort" : 22,
    "sshTarget" : "example-host"
  }
]
```

The built-in seed contains three entries: `mac1` (`both`), `mini1` (`view`, headless example), and
`mac2` (`screen`, with `triggerOn` / `triggerOff` overrides). All three use RFC 5737 documentation
addresses and must be replaced. If the file is missing or fails to decode, `ConfigStore.load()` falls
back to the seed and writes it to `~/.config/screenbar/devices.json` immediately.

## Status rules

`DeviceStatus` (`../Sources/ScreenBar/Model/DeviceStatus.swift`) is recomputed on every refresh:

| Field | Rule |
|---|---|
| `online` | `nc -z -G5 <host> <sshPort>` succeeds |
| `viewable` | only when `online` **and** `modes.canView`, then `nc -z -G5 <host> 5900` succeeds |
| `active` | an `ESTABLISHED` `netstat` connection has a local address ending in `.5900` whose foreign address resolves to the device's `host` |
| `viewing` | an `ESTABLISHED` connection has a foreign address ending in `.5900` and the device's `host` as its peer |
| `link` | from `tailscale status --json`, and only when `online`; otherwise `unknown` |

The connection parser only looks at lines with six or more whitespace-separated fields where field 6 is
`ESTABLISHED`; `LISTEN` connections are ignored. Port `22` sessions never count as screen sharing.

## Link classification

`Tailscale.parse` maps each peer's primary IPv4 address to a `LinkType`:

| Peer state in `tailscale status --json` | Result |
|---|---|
| any `TailscaleIPs` entry without `:` and a non-empty `CurAddr` | `direct` |
| ... non-empty `Relay` but empty `CurAddr` | `relay` |
| peer not `Online`, or neither field set | `unknown` |

Only `direct` is treated as suitable for the second-screen direction; the UI marks `relay` in orange
with the label `中继·会卡` and suggests Jump Desktop for viewing.

The Tailscale CLI is resolved from the first executable path found among `/usr/local/bin/tailscale`,
`~/bin/tailscale`, `/opt/homebrew/bin/tailscale`, and the app bundle binary. Before calling it, all
proxy environment variables (`ALL_PROXY`, `HTTP_PROXY`, `HTTPS_PROXY`, and lowercase variants) are
stripped, because the Go CLI would otherwise try to reach the local daemon through the system proxy.

## `status.json`

Written by `AppModel.writeStatusDump()` on each refresh to `~/.config/screenbar/status.json`:

```json
{
  "devices" : [
    {
      "active" : false,
      "host" : "192.0.2.10",
      "id" : "mac1",
      "label" : "Example-Mac",
      "link" : "direct",
      "modes" : "both",
      "online" : true,
      "viewable" : true,
      "viewing" : false
    }
  ],
  "updated" : "2026-01-01T00:00:00Z"
}
```

`updated` is an ISO-8601 UTC timestamp; `link` is `direct`, `relay`, or `unknown`. On startup the app
reads the file back so the menu shows the previous state instead of an all-offline flash.

## `doctor` checks

`Diagnostics.run` returns two lists.

Environment:

| Check | Passes when | Otherwise |
|---|---|---|
| BetterDisplay CLI | `/opt/homebrew/bin/betterdisplaycli` is executable | fail — the second-screen direction is unavailable |
| Tailscale | `tailscale status --json` returns at least one peer | warn — check the CLI and proxy settings |
| Jump 查看端 | `Jump Desktop.app` exists in `~/Applications` or `/Applications` | warn — Jump path unavailable, VNC unaffected |
| M5 屏幕共享 | a `LISTEN` socket ends in `.5900` on this Mac | warn — peers cannot connect back as a second screen |

Per device, when the device is online:

| Check | Result |
|---|---|
| 在线 | ok when the SSH port answers, warn with "不可达" otherwise (the remaining per-device checks are skipped when offline) |
| 链路 | ok for `direct`, warn for `relay` or `unknown` |
| 当副屏就绪 | ok with a non-empty `triggerOn` or an `sshTarget` other than `-`, fail otherwise |
| 查看就绪 | ok with a `jumpID` (Jump) or an open `:5900` (VNC); warn when the peer has neither |

## Constants and paths

From [`../Sources/ScreenBar/Util/Constants.swift`](../Sources/ScreenBar/Util/Constants.swift):

| Constant | Value |
|---|---|
| config directory | `~/.config/screenbar` |
| device file | `~/.config/screenbar/devices.json` |
| status dump | `~/.config/screenbar/status.json` |
| peer dial-back address | `~/.config/screenbar/m5host`, placeholder when absent |
| poll interval | 12 s |
| BetterDisplay CLI | `/opt/homebrew/bin/betterdisplaycli` |
| `netstat` | `/usr/sbin/netstat` |
| bundle id / log subsystem | `com.leo.screenbar` |

Timeouts used by the services: `nc` probes `-G5` (5 s), SSH `ConnectTimeout=12` with `BatchMode=yes`,
connect/disconnect triggers 25–30 s, remote MAC fetch 12 s, remote sharing toggle 20 s.

## Troubleshooting

| Symptom | Likely cause | What to try |
|---|---|---|
| notification "18s 内未检测到连上" after connect | peer is sitting on the Screen Sharing login window, sharing is off, or the lid is closed | complete the login on the peer and tick Remember password; run `screenbar doctor` |
| no virtual screen appears | BetterDisplay is not running, or the CLI is not at `/opt/homebrew/bin` | start BetterDisplay, run `brew install waydabber/betterdisplay/betterdisplaycli`, then check `doctor` |
| `status` always shows `中继·会卡` | Tailscale could not hole-punch between the two networks | use the view direction, or configure a `jumpID` for Fluid |
| `doctor` warns that Tailscale has no peers | CLI missing, daemon not running, or a global proxy leaked into the environment | check `/usr/local/bin/tailscale status`, unset proxy variables |
| `开共享` fails on a device | the peer's `sudo` is not `NOPASSWD`, so `kickstart` cannot run | enable Screen Sharing manually on the peer |
| selecting High Quality blanks this Mac's display | macOS dedicates the main display in that mode | choose Standard on the peer instead |
| `view`/`unview` closes unrelated windows | `unview` quits the Screen Sharing app entirely | close individual windows from the app if that matters |

## Tests and CI

`Tests/ScreenBarTests` uses the Swift Testing framework (`@Suite` / `@Test`) and contains 17 test
functions:

| Suite | Tests | Covers |
|---|---|---|
| `ReachabilityTests` | 4 | inbound/outbound `:5900` parsing, ignoring non-`ESTABLISHED` lines, port stripping |
| `TailscaleTests` | 4 | direct / relay / offline classification, malformed JSON |
| `RemoteControlTests` | 3 | Wake-on-LAN packet length and layout, `-` separators, invalid MACs |
| `ConfigStoreTests` | 3 | seed shape, `Device` JSON round-trip, virtual screen naming |
| `CLITests` | 2 | known command set, unknown tokens falling back to the GUI |
| `SmokeTests` | 1 | `DeviceMode` capability flags |

CI (`../.github/workflows/ci.yml`) runs on `macos-15` for pushes to `main`, pull requests, and manual
dispatch: `swift --version`, `swift build`, `swift test`. It does not exercise a real peer, SSH, or
BetterDisplay.
