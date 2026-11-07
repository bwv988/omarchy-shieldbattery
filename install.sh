#!/usr/bin/env bash
# install.sh - link omarchy-shieldbattery into the live system
#
#   ./install.sh            link scripts, desktop entry and icon
#   ./install.sh --dry-run  show what would happen
#   ./install.sh status     show link state and install state
#
# Repo layout mirrors the home directory:
#   bin/<name>    ->  ~/.local/bin/<name>
#   share/<path>  ->  ~/.local/share/<path>
#
# Real files that are in the way are moved to
#   ~/.local/state/omarchy-shieldbattery/backups/<timestamp>/
# so nothing is ever lost. Re-running is safe.

set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
state="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-shieldbattery"
backup="$state/backups/$(date +%Y%m%d-%H%M%S)"
prefix="$HOME/Games/battlenet"
app="$prefix/drive_c/users/steamuser/AppData/Local/Programs/shieldbattery-app/ShieldBattery.exe"
dry_run=0
mode=install

case "${1:-}" in
  --dry-run | -n) dry_run=1 ;;
  status | --status) mode=status ;;
  -h | --help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "")
    ;;
  *)
    printf 'install.sh: unknown argument %q\n' "$1" >&2
    exit 2
    ;;
esac

run() {
  if ((dry_run)); then
    printf 'would: %s\n' "$*"
  else
    "$@"
  fi
}

# link <target-in-repo> <destination>
link() {
  local src="$repo/$1" dest="$2" current

  if [[ ! -e $src ]]; then
    printf 'missing in repo: %s\n' "$1" >&2
    return 1
  fi

  if [[ -L $dest ]]; then
    current=$(readlink -f "$dest")
    if [[ $current == "$(readlink -f "$src")" ]]; then
      printf 'linked  %s\n' "$dest"
      return 0
    fi
  fi

  if [[ -e $dest || -L $dest ]]; then
    run mkdir -p "$backup/$(dirname "${dest#"$HOME"/}")"
    run mv "$dest" "$backup/${dest#"$HOME"/}"
    printf 'backup  %s -> %s\n' "$dest" "$backup/${dest#"$HOME"/}"
  fi

  run mkdir -p "$(dirname "$dest")"
  run ln -sfn "$src" "$dest"
  printf 'new     %s -> %s\n' "$dest" "$src"
}

show_status() {
  local dest
  for dest in "$HOME/.local/bin/omarchy-launch-shieldbattery" \
    "$HOME/.local/bin/omarchy-install-shieldbattery" \
    "$HOME/.local/bin/omarchy-remove-shieldbattery" \
    "$HOME/.local/share/applications/shieldbattery.desktop" \
    "$HOME/.local/share/icons/hicolor/256x256/apps/shieldbattery.png"; do
    if [[ -L $dest ]]; then
      printf '%-70s -> %s\n' "$dest" "$(readlink "$dest")"
    elif [[ -e $dest ]]; then
      printf '%-70s (real file, not linked)\n' "$dest"
    else
      printf '%-70s (missing)\n' "$dest"
    fi
  done

  printf '\n'
  if [[ -d "$prefix/drive_c/Program Files (x86)/StarCraft" ]]; then
    printf 'starcraft  installed in %s\n' "$prefix"
  else
    printf 'starcraft  missing (run: omarchy install gaming battlenet)\n'
  fi
  if [[ -f $app ]]; then
    printf 'client     installed (launch: omarchy-launch-shieldbattery)\n'
  else
    printf 'client     missing (install: omarchy-install-shieldbattery)\n'
  fi
  if [[ -d ${state}/backups ]]; then
    printf '\nbackups in %s:\n' "$state/backups"
    ls -1 "$state/backups"
  fi
}

if [[ $mode == status ]]; then
  show_status
  exit 0
fi

link "bin/omarchy-launch-shieldbattery" "$HOME/.local/bin/omarchy-launch-shieldbattery"
link "bin/omarchy-install-shieldbattery" "$HOME/.local/bin/omarchy-install-shieldbattery"
link "bin/omarchy-remove-shieldbattery" "$HOME/.local/bin/omarchy-remove-shieldbattery"
link "share/applications/shieldbattery.desktop" \
  "$HOME/.local/share/applications/shieldbattery.desktop"
link "share/icons/hicolor/256x256/apps/shieldbattery.png" \
  "$HOME/.local/share/icons/hicolor/256x256/apps/shieldbattery.png"

if ((!dry_run)); then
  chmod +x "$repo"/bin/omarchy-*
  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
  gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
fi

if [[ -f $app ]]; then
  printf '\nReady. Launch ShieldBattery with: omarchy-launch-shieldbattery\n'
else
  printf '\nLinked. Next, install the client: omarchy-install-shieldbattery\n'
fi
