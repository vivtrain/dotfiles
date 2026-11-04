#!/usr/bin/env bash
# Personal environment bootstrap: the stuff I like, by category. Idempotent: every step checks
# whether it's already done and skips it, so it's safe to re-run any time.
#
#   ~/.bootstrap.sh                  run every section
#   ~/.bootstrap.sh terminal editor  run only those sections
#   ~/.bootstrap.sh -n [section...]  dry run: print what would be done, change nothing
#   ~/.bootstrap.sh -l               list sections
#
# To log something new: add it to the right section's list (apt/snap/cargo), or for anything else
# write a step that checks first:  have foo || run "curl ... | sh"
# Config files themselves live in the dotfiles repo (~/.git); this only installs things.
set -euo pipefail

SECTIONS=(base cli git terminal editor desktop network)

# ── helpers ──────────────────────────────────────────────────────────────────────────────────────
DRY=0
c_head=$'\e[1;34m' c_do=$'\e[33m' c_ok=$'\e[2m' c_off=$'\e[0m'
section() { printf '\n%s== %s%s\n' "$c_head" "$1" "$c_off"; }
ok()      { printf '%s  ok  %s%s\n' "$c_ok" "$1" "$c_off"; }
run()     { printf '%s  ->  %s%s\n' "$c_do" "$1" "$c_off"; ((DRY)) || bash -c "$1"; }
have()    { command -v "$1" >/dev/null 2>&1; }

APT_UPDATED=0
apt_pkgs() {  # apt_pkgs pkg...: install whichever aren't installed yet
    local missing=() p
    for p in "$@"; do
        if dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'install ok installed'; then
            ok "apt $p"
        else
            missing+=("$p")
        fi
    done
    ((${#missing[@]})) || return 0
    if ((!APT_UPDATED)); then run "sudo apt-get update"; APT_UPDATED=1; fi
    run "sudo apt-get install -y ${missing[*]}"
}

apt_repo() {  # apt_repo name keyring_path key_url "deb line": add a third-party apt repo once
    local name=$1 keyring=$2 key_url=$3 line=$4
    if [[ -f /etc/apt/sources.list.d/$name.list ]]; then ok "apt repo $name"; return; fi
    [[ -f $keyring ]] || run "curl -fsSL '$key_url' | sudo gpg --dearmor -o '$keyring' && sudo chmod a+r '$keyring'"
    run "echo '$line' | sudo tee /etc/apt/sources.list.d/$name.list >/dev/null"
    APT_UPDATED=0  # new repo: next apt_pkgs must update
}

snap_pkg() {  # snap_pkg name [install flags...], e.g. snap_pkg nvim --classic
    local name=$1; shift
    if snap list "$name" >/dev/null 2>&1; then ok "snap $name"; return; fi
    run "sudo snap install $name $*"
}

cargo_pkg() {  # cargo_pkg crate [binary]
    local crate=$1 bin=${2:-$1}
    if have "$bin"; then ok "cargo $crate"; return; fi
    run "cargo install --locked $crate"
}

# ── sections ─────────────────────────────────────────────────────────────────────────────────────
sec_base() {
    apt_pkgs curl git python3-pip python3-venv python3-dev python-is-python3
    # uv: Python packages/venvs/tools (installs to ~/.local/bin)
    have uv && ok "uv" || run "curl -LsSf https://astral.sh/uv/install.sh | sh"
    # rustup: Rust toolchain for cargo installs (~/.cargo/env is sourced by .profile/.bashrc)
    have cargo && ok "rustup" ||
        run "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path"
}

sec_cli() {
    apt_pkgs tree fzf ripgrep jq xclip sshfs sshpass whois ncal net-tools nmap lz4 lbzip2 \
        wmctrl xdotool xmlstarlet \
        dict dictd dict-gcide dict-wn  # offline dictionary: dict <word>
    snap_pkg htop
    # rclone: upstream build (Ubuntu's is old); remote dm: is the company shared drive
    have rclone && ok "rclone" || run "curl -fsSL https://rclone.org/install.sh | sudo bash"
}

sec_git() {
    apt_repo github-cli /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        "deb [arch=amd64 signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main"
    apt_pkgs git-lfs gh
    cargo_pkg git-graph  # gg
}

sec_terminal() {
    # kitty 0.49+ from upstream into ~/.local/kitty.app (the default terminal); apt kitty is the fallback
    apt_pkgs kitty
    if [[ -x ~/.local/kitty.app/bin/kitty ]]; then ok "kitty.app"; else
        run "curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n"
    fi
    for b in kitty kitten; do
        [[ -L ~/.local/bin/$b ]] && ok "~/.local/bin/$b" || run "ln -sf ~/.local/kitty.app/bin/$b ~/.local/bin/$b"
    done
    for d in kitty kitty-open; do  # desktop entries pointing at kitty.app (skipped if already customized)
        [[ -f ~/.local/share/applications/$d.desktop ]] && ok "$d.desktop" || run "mkdir -p ~/.local/share/applications &&
            sed 's|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|; s|Exec=kitty|Exec=$HOME/.local/kitty.app/bin/kitty|' \
                ~/.local/kitty.app/share/applications/$d.desktop > ~/.local/share/applications/$d.desktop"
    done

    # tmux 3.7c from snap, held so it only changes on a deliberate upgrade
    snap_pkg tmux --classic
    if snap info tmux 2>/dev/null | grep -q '^hold:'; then ok "tmux held"; else run "sudo snap refresh --hold tmux"; fi

    # oh-my-posh prompt (.bashrc evals its init with ~/.think.omp.json)
    have oh-my-posh && ok "oh-my-posh" || run "curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin"

    # Fonts: JetBrainsMono Nerd Font (terminal + nerdfont glyphs), Noto Sans Symbols 2 (Claude's ⏵⏸⏺)
    local fonts=~/.local/share/fonts changed=0
    if compgen -G "$fonts/JetBrainsMonoNerdFont-*.ttf" >/dev/null; then ok "JetBrainsMono Nerd Font"; else
        run "mkdir -p $fonts && tmp=\$(mktemp -d) &&
            curl -fsSL -o \$tmp/f.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip &&
            unzip -oq \$tmp/f.zip -d $fonts && rm -rf \$tmp"
        changed=1
    fi
    if [[ -f $fonts/NotoSansSymbols2-Regular.ttf ]]; then ok "Noto Sans Symbols 2"; else
        run "mkdir -p $fonts && curl -fsSL -o $fonts/NotoSansSymbols2-Regular.ttf \
            https://github.com/notofonts/notofonts.github.io/raw/main/fonts/NotoSansSymbols2/hinted/ttf/NotoSansSymbols2-Regular.ttf"
        changed=1
    fi
    ((changed)) && run "fc-cache -f $fonts" || true
}

sec_editor() {
    snap_pkg nvim --classic
    snap_pkg pyright --classic       # Python LSP
    apt_pkgs vim clang clangd bear   # bear: compile_commands.json for clangd
    apt_pkgs retext                  # md: markdown preview
}

sec_desktop() {
    apt_pkgs gnome-tweaks gnome-shell-extensions gnome-shell-extension-manager \
        mpv ffmpeg imagemagick gimp flameshot

    # Nautilus: hjkl in list view (~/.local/share/nautilus-python/extensions/vimnav.py)
    apt_pkgs python3-nautilus
    # eog: h/l prev/next image (~/.local/share/eog/plugins/vimnav); plugin list lives in gsettings
    local plugins
    plugins=$(gsettings get org.gnome.eog.plugins active-plugins 2>/dev/null || echo "@as []")
    if [[ $plugins == *"'vimnav'"* ]]; then ok "eog vimnav plugin enabled"; else
        run "gsettings set org.gnome.eog.plugins active-plugins \"\$(python3 -c '
import ast, sys; s = sys.argv[1].removeprefix(\"@as \"); l = ast.literal_eval(s)
print(repr(l + [\"vimnav\"]))' \"$plugins\")\""
    fi
}

sec_network() {
    have tailscale && ok "tailscale" || run "curl -fsSL https://tailscale.com/install.sh | sh"
}

# ── main ─────────────────────────────────────────────────────────────────────────────────────────
while getopts "nlh" opt; do
    case $opt in
        n) DRY=1 ;;
        l) printf '%s\n' "${SECTIONS[@]}"; exit 0 ;;
        *) sed -n '2,12p' "$0"; exit 0 ;;
    esac
done
shift $((OPTIND - 1))

todo=("$@")
((${#todo[@]})) || todo=("${SECTIONS[@]}")
for s in "${todo[@]}"; do
    declare -F "sec_$s" >/dev/null || { echo "unknown section: $s (try -l)" >&2; exit 1; }
done
((DRY)) && echo "(dry run: nothing will be changed)"
for s in "${todo[@]}"; do section "$s"; "sec_$s"; done
echo
