# omarchy-shieldbattery

Run [ShieldBattery](https://shieldbattery.net) — the community StarCraft: Brood
War client — on Omarchy, on top of the Battle.net Proton prefix Omarchy already
knows how to build.

ShieldBattery ships a Windows-only Electron app (upstream `electron-builder` only
targets `--win --x64`; `/published_artifacts/linux/*` doesn't exist). There is no
native Linux build to install. But the Windows client runs fine under
`umu-launcher` + GE-Proton, and it can drive StarCraft through Wine's DLL
injection, so matches and replays actually work.

## What is verified working

Verified on Omarchy 4.5.0, ShieldBattery client `12.3.6`, GE-Proton `11-12`:

- The client launches, renders, logs in, and talks to `shieldbattery.net`.
- It auto-detects the StarCraft install from Battle.net's `product.db`
  (`C:/Program Files (x86)/StarCraft`) — no manual path to set.
- Playing a replay launches `StarCraft.exe` with ShieldBattery's `sb_init.dll` /
  `shieldbattery.dll` injected, and the game runs. That is the same code path a
  ladder game uses, so online play should work too.

## Why share the Battle.net prefix

ShieldBattery is a *client*, not a game: it needs the StarCraft: Brood War files
and it finds them by reading `C:\ProgramData\Battle.net\Agent\product.db` (then
falling back to Blizzard registry keys). Installing it into
`~/Games/battlenet` means it finds StarCraft on first launch with zero
configuration, and both launchers share one Proton prefix, one GPU setup, one
set of Wine settings.

The installer is still a normal per-user NSIS install, so it lands in
`C:\users\steamuser\AppData\Local\Programs\shieldbattery-app`, not in
`Program Files`.

## Layout

| Path | Installs to | What it does |
|---|---|---|
| `bin/omarchy-install-shieldbattery` | `~/.local/bin/` | Downloads the latest Windows installer and installs it into the Battle.net prefix (checks for StarCraft, then `/S` silent install) |
| `bin/omarchy-launch-shieldbattery` | `~/.local/bin/` | Launches the client with `umu-run`, matching Wine DPI to the focused monitor, optional `--with-mangohud` |
| `bin/omarchy-remove-shieldbattery` | `~/.local/bin/` | Removes the client, updater, settings and replays; keeps Battle.net + StarCraft |
| `share/applications/shieldbattery.desktop` | `~/.local/share/applications/` | App-launcher entry (`StartupWMClass=steam_app_shieldbattery`) |
| `share/icons/hicolor/256x256/apps/shieldbattery.png` | `~/.local/share/icons/hicolor/...` | Menu icon |
| `install.sh` | – | Idempotent symlink installer with backups (run this first) |

Everything is user-layer: `~/.local/bin`, `~/.local/share`, and the existing
`~/Games/battlenet` prefix. Nothing in `/usr/share/omarchy/` is touched, so
`omarchy update` can't eat it.

## Install

**1. Prerequisite: Battle.net + StarCraft.** This repo does not install
Battle.net. Use Omarchy's own installer — it also sets up `umu-launcher`,
GE-Proton and the lib32 graphics drivers — then install StarCraft: Remastered
inside Battle.net:

```bash
omarchy install gaming battlenet
```

Check it worked — this directory must exist:

```bash
ls ~/Games/battlenet/drive_c/Program\ Files\ \(x86\)/StarCraft
```

**2. Link this repo into place.** Run `install.sh` from the repo:

```bash
cd ~/Develop/omarchy-shieldbattery
./install.sh --dry-run   # optional: see what it would touch
./install.sh             # link scripts, desktop entry and icon
./install.sh status      # what is linked, what is installed
```

**3. Install the client** into the Battle.net prefix:

```bash
omarchy-install-shieldbattery
```

**4. Launch it.** `SUPER + SPACE` → **ShieldBattery**, or:

```bash
omarchy-launch-shieldbattery
```

Optional menu row — append to your menu extensions file
(`~/.config/omarchy/extensions/omarchy-menu.jsonc`, symlinked from
`~/Develop/oma-malleations`):

```jsonc
"apps.shieldbattery": {
  "icon": "",
  "label": "ShieldBattery",
  "description": "StarCraft: Brood War · GE-Proton",
  "action": "omarchy-launch-shieldbattery"
}
```

(`SUPER + SPACE` → `omarchy menu refresh` to reload it.)

## Usage notes

- **Updates are self-managed.** ShieldBattery's own updater runs from inside the
  prefix and updates the client in place. Don't re-download on every release;
  `omarchy-install-shieldbattery --reinstall` is only for a broken install.
- **First launch may take a while** (Proton prefix warm-up, shader cache).
- **DPI**: Wine reads `LogPixels` once at startup, so the launcher rewrites it in
  `user.reg` from the focused monitor's Hyprland scale before each launch (the
  same trick `omarchy-launch-battlenet` uses). Skipped if the prefix is running.
- **MangoHud**: `omarchy-launch-shieldbattery --with-mangohud`, then
  `Shift_L+F2` in game; CSV logs go to `~/mangohud/`.
- **Replays** live in
  `~/Games/battlenet/drive_c/users/steamuser/AppData/Roaming/ShieldBattery/replays`.

## Uninstall

```bash
omarchy-remove-shieldbattery          # client, updater, settings, replays
omarchy-remove-shieldbattery --keep-settings
```

Battle.net, StarCraft, `umu-launcher` and GE-Proton are left alone on purpose —
Battle.net uses them. Removing the linked files is `rm` on the five symlinks
listed by `./install.sh status`.

## Troubleshooting

Logs (the interesting one is the Electron main process):

```
~/Games/battlenet/drive_c/users/steamuser/AppData/Roaming/ShieldBattery/logs/app.0.log
```

- `Failed to determine elevation status ... whoami.exe /groups` — harmless, Wine
  has no Windows elevation model. Upgrade prompts just won't appear.
- `WSALookupServiceBegin failed with: 8` — harmless Chromium network-change
  notifier noise under Wine.
- `Unable to read VR Path Registry ...` — harmless, no SteamVR installed.
- Game window never appears after pressing Play: look for `[Inject]` lines in the
  log. If injection fails, try a different Proton (`PROTONPATH=GE-Proton10-…`).
  Bump the GE-Proton version first: the client needs a reasonably new
  `d3dcompiler_47` for its overlay.
- Client window too small/large: check the launcher's DPI step actually ran
  (`LogPixels` in `~/Games/battlenet/user.reg`).

## How this is installed the Omarchy way

Omarchy's own installers are single scripts on `PATH` named
`omarchy-install-<group>-<name>` with a metadata header the `omarchy` CLI reads.
That's what makes `omarchy install gaming battlenet` and the menu rows work.
The shape, and what this repo copies:

```bash
#!/bin/bash

# omarchy:summary=One line shown in `omarchy commands` and the menu
# omarchy:args=[--flags]
# omarchy:examples=omarchy-install-foo
# omarchy:requires-sudo=true      # only if it needs pacman

set -euo pipefail

# Fail with a pointer instead of installing someone else's dependency:
[[ -d $HOME/Games/battlenet/drive_c/Program\ Files\ \(x86\)/StarCraft ]] || {
  echo "run: omarchy install gaming battlenet" >&2
  exit 1
}

omarchy-pkg-add umu-launcher   # sudo only when the package is missing
curl --fail --location --retry 3 "$URL" --output "$installer"
umu-run "$installer" /S        # NSIS silent install, log to /tmp
```

The two things this repo does differently: the dependency (Battle.net) is
checked and reported, never installed here — `omarchy install gaming battlenet`
owns that — and the desktop entry/icon come from `install.sh` symlinks instead
of `$OMARCHY_PATH/default/applications/`, because nothing here is packaged.

Two constraints matter for a personal repo:

1. `omarchy` only routes scripts that live in `/usr/share/omarchy/bin`, so
   `omarchy install shieldbattery` won't find a script in `~/.local/bin`. Writing
   there is an upstream contribution, not a user customization. Keep the header
   anyway — it keeps the script consistent, self-documenting, and a drop-in
   upstream patch if ShieldBattery ever gets a Linux build.
2. Pair every `omarchy-install-x` with an `omarchy-remove-x`, and never edit
   `/usr/share/omarchy/`. `install.sh` follows the symlink-farm pattern from
   `oma-malleations`: the repo mirrors `$HOME`, `install.sh` links each file into
   place, real files in the way are backed up to
   `~/.local/state/omarchy-shieldbattery/backups/<timestamp>/`.

Full upstream reference: `omarchy-install-gaming-battlenet`,
`omarchy-remove-gaming-battlenet`, and `omarchy <group> --help`.

## Credits

ShieldBattery is [open source](https://github.com/ShieldBattery/ShieldBattery)
(MIT). This repo is only a Linux/Omarchy packaging wrapper; the logo is
ShieldBattery's own artwork.
