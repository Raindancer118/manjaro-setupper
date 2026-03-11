#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
#  Manjaro Setup — Interaktiver Onboarding-Installer
#  Usage: bash setup.sh
#  Remote: bash <(curl -fsSL https://raw.githubusercontent.com/Raindancer118/manjaro-setupper/main/setup.sh)
# ──────────────────────────────────────────────────────────────

REPO_URL="https://github.com/Raindancer118/manjaro-setupper.git"

# ── Remote-Erkennung & Self-Bootstrap ────────────────────────
_detect_script_dir() {
    local src="${BASH_SOURCE[0]}"
    if [[ "${src}" == /dev/fd/* || "${src}" == /proc/* || ! -f "${src}" ]]; then
        echo ""
        return
    fi
    cd "$(dirname "${src}")" && pwd
}

SCRIPT_DIR="$(_detect_script_dir)"
MODULES_DIR="${SCRIPT_DIR}/modules"

if [[ -z "${SCRIPT_DIR}" || ! -d "${MODULES_DIR}" ]]; then
    TMPDIR_REPO="$(mktemp -d)"
    echo -e "\n\033[38;2;96;165;250m  ·\033[0m Lade Manjaro Setup herunter ..."
    if ! command -v git &>/dev/null; then
        sudo pacman -Sy --noconfirm --needed git &>/dev/null
    fi
    git clone --depth=1 "${REPO_URL}" "${TMPDIR_REPO}/repo" &>/dev/null
    echo -e "  \033[38;2;74;222;128m✓\033[0m Download abgeschlossen. Starte Setup ..."
    exec bash "${TMPDIR_REPO}/repo/setup.sh" "$@"
fi

# ── ANSI-Farben (für Terminal-Ausgabe während Installation) ──
ANSI_BLUE='\033[38;2;96;165;250m'
ANSI_DIM='\033[38;2;71;85;105m'
ANSI_GREEN='\033[38;2;74;222;128m'
ANSI_YELLOW='\033[38;2;250;204;21m'
ANSI_RED='\033[38;2;239;68;68m'
ANSI_BOLD='\033[1m'
ANSI_RESET='\033[0m'

# Kompatibilitäts-Aliase für Module
BLUE="${ANSI_BLUE}" DIM="${ANSI_DIM}" GREEN="${ANSI_GREEN}"
YELLOW="${ANSI_YELLOW}" RED="${ANSI_RED}" RESET="${ANSI_RESET}"

# Hex-Farben für gum
GUM_BLUE="#60a5fa"
GUM_GREEN="#4ade80"
GUM_YELLOW="#facc15"
GUM_RED="#ef4444"
GUM_DIM="#475569"

# ── Log-Funktionen ────────────────────────────────────────────
info()    { echo -e "  ${ANSI_BLUE}·${ANSI_RESET} $*"; }
success() { echo -e "  ${ANSI_GREEN}✓${ANSI_RESET} $*"; }
warn()    { echo -e "  ${ANSI_YELLOW}△${ANSI_RESET} $*"; }
error()   { echo -e "  ${ANSI_RED}✗${ANSI_RESET} $*" >&2; }
skip()    { echo -e "  ${ANSI_DIM}· $* — übersprungen${ANSI_RESET}"; }

header() {
    clear
    gum style \
        --border=rounded \
        --border-foreground="${GUM_BLUE}" \
        --padding="1 4" \
        --margin="1 2" \
        "$(gum style --foreground="${GUM_BLUE}" 'M A N J A R O   S E T U P')" \
        "" \
        "$(gum style --foreground="${GUM_DIM}" "$*")"
}

section() {
    echo ""
    gum style --foreground="${GUM_BLUE}" --margin="0 2" "▸  $*"
    gum style --foreground="${GUM_DIM}"  --margin="0 2" "────────────────────────────────────────"
}

# ── Paket-Management ──────────────────────────────────────────
pkg_installed() { pacman -Qi "$1" &>/dev/null; }

# sudo_refresh: Sudo-Ticket erneuern (lautlos wenn bereits authentifiziert).
# Nötig weil gum spin stdin umleitet und sudo kein Passwort lesen kann.
sudo_refresh() { sudo -v 2>/dev/tty; }

install_pkg() {
    for pkg in "$@"; do
        if pkg_installed "$pkg"; then
            skip "$pkg bereits installiert"
        else
            sudo_refresh
            if gum spin \
                --spinner=dot \
                --spinner.foreground="${GUM_BLUE}" \
                --title="  Installiere ${pkg} ..." \
                -- sudo -n pacman -S --noconfirm --needed "$pkg"; then
                success "$pkg installiert"
            else
                error "Fehler bei der Installation von ${pkg}"
                MODULE_STATUS["${CURRENT_MODULE:-}"]=error
                MODULE_NOTES["${CURRENT_MODULE:-}"]="${MODULE_NOTES["${CURRENT_MODULE:-}"]:-} Fehler bei ${pkg}"
            fi
        fi
    done
}

install_aur() {
    if ! command -v yay &>/dev/null; then
        error "yay ist nicht installiert. Bitte zuerst Modul 01 (Pamac/AUR) ausführen."
        return 1
    fi
    for pkg in "$@"; do
        if pkg_installed "$pkg"; then
            skip "$pkg bereits installiert"
        else
            if gum spin \
                --spinner=dot \
                --spinner.foreground="${GUM_BLUE}" \
                --title="  Installiere ${pkg} (AUR) ..." \
                -- yay -S --noconfirm --needed "$pkg"; then
                success "$pkg (AUR) installiert"
            else
                error "Fehler bei der Installation von ${pkg} (AUR)"
                MODULE_STATUS["${CURRENT_MODULE:-}"]=error
                MODULE_NOTES["${CURRENT_MODULE:-}"]="${MODULE_NOTES["${CURRENT_MODULE:-}"]:-} Fehler bei ${pkg}"
            fi
        fi
    done
}

# ── Interaktive UI: reines Bash (kein gum choose/input) ───────
#
# gum choose funktioniert nicht zuverlässig in $()-Subshells weil
# gum's TTY-Erkennung unter diesen Bedingungen versagt.
# Lösung: eigenes Bash-TUI mit stty raw + read + tput.
# gum bleibt für: gum spin, gum style, gum confirm (dort kein Problem).

# checklist title text tag label default [tag label default ...]
# Gibt gewählte Tags space-separated aus (gecapturt mit $())
checklist() {
    local title="$1" text="$2"
    shift 2

    local -a tags=() labels=() states=()
    while [[ $# -ge 3 ]]; do
        tags+=("$1"); labels+=("$2")
        [[ "$3" == "on" ]] && states+=(1) || states+=(0)
        shift 3
    done
    local n=${#tags[@]}
    local cursor=0 scroll=0
    local max_vis=18
    (( n < max_vis )) && max_vis=$n

    # Terminal-Einstellungen sichern
    local old_stty
    old_stty=$(stty -g 2>/dev/null || echo "")

    _cl_cleanup() {
        tput cnorm >/dev/tty 2>/dev/null || true
        [[ -n "${old_stty:-}" ]] && stty "${old_stty}" 2>/dev/null || true
    }
    trap '_cl_cleanup' RETURN

    _cl_render() {
        # Scroll-Fenster anpassen
        (( cursor < scroll )) && scroll=$cursor
        (( cursor >= scroll + max_vis )) && scroll=$(( cursor - max_vis + 1 ))

        tput home >/dev/tty 2>/dev/null
        printf "\n  \033[38;2;96;165;250m◆  %s\033[0m\033[K\n" "${title}" >/dev/tty
        [[ -n "${text}" ]] && printf "  \033[38;2;71;85;105m%s\033[0m\033[K\n" "${text}" >/dev/tty
        printf "\033[K\n" >/dev/tty

        local end=$(( scroll + max_vis ))
        (( end > n )) && end=$n

        for (( i=scroll; i<end; i++ )); do
            local marker="○" mc="\033[38;2;71;85;105m"
            (( states[i] )) && marker="◉" && mc="\033[38;2;74;222;128m"
            if (( i == cursor )); then
                printf "  \033[38;2;96;165;250m▶\033[0m ${mc}${marker}  %s\033[0m\033[K\n" "${labels[$i]}" >/dev/tty
            else
                printf "    ${mc}${marker}  %s\033[0m\033[K\n" "${labels[$i]}" >/dev/tty
            fi
        done
        # Leerzeilen für feste Höhe
        for (( i=end-scroll; i<max_vis; i++ )); do printf "\033[K\n" >/dev/tty; done
        printf "\n  \033[38;2;71;85;105m[↑↓] Bewegen  [Space] Toggle  [Enter] Bestätigen\033[0m\033[K\n" >/dev/tty
    }

    clear >/dev/tty
    tput civis >/dev/tty 2>/dev/null || true
    stty -icanon -echo min 1 time 0 2>/dev/null || true
    _cl_render

    local key k2 k3
    while true; do
        IFS= read -rsn1 key </dev/tty 2>/dev/null
        case "${key}" in
            $'\x1b')
                IFS= read -rsn1 -t0.1 k2 </dev/tty 2>/dev/null || true
                IFS= read -rsn1 -t0.1 k3 </dev/tty 2>/dev/null || true
                if [[ "${k2}${k3}" == "[A" ]]; then  # Pfeil hoch
                    (( cursor > 0 )) && (( cursor-- )) || true
                elif [[ "${k2}${k3}" == "[B" ]]; then  # Pfeil runter
                    (( cursor < n-1 )) && (( cursor++ )) || true
                fi
                ;;
            " ")  # Space: Toggle
                (( states[cursor] )) && states[$cursor]=0 || states[$cursor]=1
                ;;
            "" | $'\n' | $'\r')  # Enter: Bestätigen
                break
                ;;
        esac
        _cl_render
    done

    clear >/dev/tty

    # Gewählte Tags zurückgeben
    for (( i=0; i<n; i++ )); do
        (( states[i] )) && echo "${tags[$i]}"
    done
}

# inputbox title placeholder [default]
# Gibt eingegebenen Text aus (gecapturt mit $())
inputbox() {
    local title="$1" text="${2:-}" default="${3:-}"
    # Direkt auf /dev/tty ausgeben damit es bei $()-Capture sichtbar bleibt
    printf "\n  \033[38;2;96;165;250m◆  %s\033[0m\n" "${title}" >/dev/tty
    [[ -n "${text}" ]] && printf "  \033[38;2;71;85;105m%s\033[0m\n" "${text}" >/dev/tty
    printf "  \033[38;2;96;165;250m›\033[0m " >/dev/tty
    # read -e: Readline-Editing; -i: Vorausfüllung; stdin = Terminal
    local result
    IFS= read -r -e -i "${default}" result </dev/tty
    printf "%s" "${result}"
}

yesno() {
    local title="$1"
    local text="$2"
    echo ""
    gum style --foreground="${GUM_BLUE}" --margin="0 2" "◆  ${title}"
    [[ -n "${text}" ]] && \
        gum style --foreground="${GUM_DIM}" --margin="0 4" "${text}"
    echo ""
    gum confirm \
        --prompt.foreground="${GUM_BLUE}" \
        --selected.background="${GUM_BLUE}" \
        --selected.foreground="#000000" \
        --unselected.foreground="${GUM_DIM}" \
        "Fortfahren?" \
        2>/dev/null
}

msgbox() {
    local title="$1"
    local text="$2"
    echo ""
    gum style \
        --border=rounded \
        --border-foreground="${GUM_BLUE}" \
        --padding="1 3" \
        --margin="0 2" \
        "${title}" \
        "" \
        "${text}"
    echo ""
    gum input --placeholder="[Enter] zum Schließen" --prompt="" --width=30 &>/dev/null || true
}

# ── Exports für Module ────────────────────────────────────────
export SCRIPT_DIR MODULES_DIR
export ANSI_BLUE ANSI_DIM ANSI_GREEN ANSI_YELLOW ANSI_RED ANSI_BOLD ANSI_RESET
export BLUE DIM GREEN YELLOW RED RESET
export GUM_BLUE GUM_GREEN GUM_YELLOW GUM_RED GUM_DIM
export -f info success warn error skip header section
export -f pkg_installed install_pkg install_aur sudo_refresh
export -f checklist inputbox yesno msgbox

# ── Zusammenfassungs-Tracking ─────────────────────────────────
declare -A MODULE_STATUS=()
declare -A MODULE_NOTES=()

# ── Abbruch-Handler ───────────────────────────────────────────
trap 'clear
echo ""
gum style \
    --border=rounded \
    --border-foreground="${GUM_YELLOW}" \
    --padding="1 3" \
    --margin="1 2" \
    "△  Setup abgebrochen" \
    "" \
    "Bisher installiertes bleibt erhalten."
echo ""
exit 130' INT TERM

# ══════════════════════════════════════════════════════════════
#  PHASE 1: BOOTSTRAP
# ══════════════════════════════════════════════════════════════

bootstrap() {
    clear
    echo -e "\n${ANSI_BOLD}${ANSI_BLUE}  M A N J A R O   S E T U P${ANSI_RESET}"
    echo -e "  ${ANSI_DIM}──────────────────────────────────${ANSI_RESET}"
    echo -e "  Bootstrap wird vorbereitet ...\n"

    if [[ ! -f /etc/os-release ]]; then
        error "/etc/os-release nicht gefunden. Nur Manjaro/Arch wird unterstützt."
        exit 1
    fi
    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ "${ID}" != "manjaro" && "${ID_LIKE:-}" != *"arch"* && "${ID}" != "arch" ]]; then
        error "Erkanntes OS: ${ID} — nur Manjaro/Arch wird unterstützt."
        exit 1
    fi
    success "OS erkannt: ${PRETTY_NAME}"

    if [[ "${EUID}" -eq 0 ]]; then
        warn "Du läufst als root. Normaler User mit sudo-Rechten empfohlen."
    fi

    info "Sudo-Berechtigung wird gesichert ..."
    sudo -v
    success "Sudo OK."

    info "Bootstrap-Pakete werden installiert (git, curl, base-devel, wget, gum) ..."
    sudo pacman -Sy --noconfirm --needed git curl base-devel wget gum 2>&1 \
        | grep -v "^warning:" || true
    success "Bootstrap abgeschlossen."
    sleep 1
}

# ══════════════════════════════════════════════════════════════
#  PHASE 2: ONBOARDING-FLOW
# ══════════════════════════════════════════════════════════════

declare -a MODULE_TAGS=(
    "00_system"
    "01_pamac_aur"
    "02_shell"
    "03_browser"
    "04_communication"
    "05_media"
    "06_office"
    "07_flatpak"
    "08_dev"
    "09_gaming"
    "10_system_tools"
    "11_kde"
)

declare -A MODULE_LABELS=(
    ["00_system"]="System-Basis & Sicherheit"
    ["01_pamac_aur"]="Pamac AUR-Support + yay"
    ["02_shell"]="Shell & Terminal-Tools"
    ["03_browser"]="Browser"
    ["04_communication"]="Kommunikation & Mail"
    ["05_media"]="Medien, Grafik & Fonts"
    ["06_office"]="Office-Suiten"
    ["07_flatpak"]="Flatpak & Flathub"
    ["08_dev"]="Entwicklungs-Tools"
    ["09_gaming"]="Gaming"
    ["10_system_tools"]="Nützliche System-Tools"
    ["11_kde"]="KDE-spezifische Anpassungen"
)

declare -A MODULE_DEFAULT=(
    ["00_system"]="on"
    ["01_pamac_aur"]="on"
    ["02_shell"]="on"
    ["03_browser"]="off"
    ["04_communication"]="off"
    ["05_media"]="off"
    ["06_office"]="off"
    ["07_flatpak"]="off"
    ["08_dev"]="off"
    ["09_gaming"]="off"
    ["10_system_tools"]="off"
    ["11_kde"]="off"
)

declare -A MODULE_DESC=(
    ["00_system"]="System-Basis & Sicherheit  —  Update, Mirrors, Firewall, zram, TRIM ..."
    ["01_pamac_aur"]="Pamac AUR-Support + yay  —  AUR aktivieren, yay installieren"
    ["02_shell"]="Shell & Terminal-Tools  —  Zsh, Starship, fzf, bat, eza, btop ..."
    ["03_browser"]="Browser  —  Firefox, Brave, Chrome, Librewolf, Zen"
    ["04_communication"]="Kommunikation & Mail  —  Discord, Signal, Telegram, Thunderbird ..."
    ["05_media"]="Medien, Grafik & Fonts  —  MPV, VLC, OBS, GIMP, Nerd Fonts ..."
    ["06_office"]="Office-Suiten  —  ONLYOFFICE, LibreOffice, WPS, Okular"
    ["07_flatpak"]="Flatpak & Flathub  —  Flatpak installieren, Flathub hinzufügen"
    ["08_dev"]="Entwicklungs-Tools  —  Git, Docker, Node, Python, Rust, VSCode ..."
    ["09_gaming"]="Gaming  —  Steam, Lutris, Proton-GE, MangoHud, Wine ..."
    ["10_system_tools"]="Nützliche System-Tools  —  NTFS, Archive, KeePassXC, TLP ..."
    ["11_kde"]="KDE-Anpassungen  —  Dark Mode, Kvantum, Yakuake, KDE Connect ..."
)

step1_module_selection() {
    local -a items=()
    for tag in "${MODULE_TAGS[@]}"; do
        items+=("${tag}" "${MODULE_DESC[$tag]}" "${MODULE_DEFAULT[$tag]}")
    done

    checklist \
        "Modul-Auswahl" \
        "Space = Toggle  ·  Enter = Bestätigen  ·  / = Filtern" \
        "${items[@]}"
}

step4_confirmation() {
    local -a selected_modules=("$@")
    echo ""
    gum style \
        --border=rounded \
        --border-foreground="${GUM_BLUE}" \
        --padding="1 3" \
        --margin="0 2" \
        "Folgende Module werden installiert:"
    echo ""
    for tag in "${selected_modules[@]}"; do
        [[ -z "${tag}" ]] && continue
        gum style --foreground="${GUM_GREEN}" --margin="0 4" "✓  ${MODULE_LABELS[$tag]:-Modul $tag}"
    done
    echo ""
    gum confirm \
        --prompt.foreground="${GUM_BLUE}" \
        --selected.background="${GUM_BLUE}" \
        --selected.foreground="#000000" \
        --unselected.foreground="${GUM_DIM}" \
        "Jetzt installieren?" \
        2>/dev/null
}

show_summary() {
    clear
    echo ""
    gum style \
        --border=rounded \
        --border-foreground="${GUM_BLUE}" \
        --padding="1 4" \
        --margin="1 2" \
        "M A N J A R O   S E T U P  —  Zusammenfassung"
    echo ""

    for tag in "${MODULE_TAGS[@]}"; do
        local status="${MODULE_STATUS[$tag]:-skipped}"
        local note="${MODULE_NOTES[$tag]:-}"
        local label="${MODULE_LABELS[$tag]:-Modul $tag}"
        local padded
        printf -v padded "%-32s" "${label}"
        case "${status}" in
            success) gum style --foreground="${GUM_GREEN}"  --margin="0 2" "✓  ${padded}${note}" ;;
            warn)    gum style --foreground="${GUM_YELLOW}" --margin="0 2" "△  ${padded}${note}" ;;
            error)   gum style --foreground="${GUM_RED}"    --margin="0 2" "✗  ${padded}${note}" ;;
            skipped) gum style --foreground="${GUM_DIM}"    --margin="0 2" "─  ${padded}Übersprungen" ;;
        esac
    done

    echo ""
    gum style --foreground="${GUM_DIM}"  --margin="0 2" "One-Liner für neue Systeme:"
    gum style --foreground="${GUM_BLUE}" --margin="0 2" \
        "bash <(curl -fsSL https://raw.githubusercontent.com/Raindancer118/manjaro-setupper/main/setup.sh)"
    echo ""
    gum input --placeholder="[Enter] zum Beenden" --prompt="" --width=30 &>/dev/null || true
}

run_module() {
    local tag="$1"
    local module_file="${MODULES_DIR}/${tag}.sh"

    if [[ ! -f "${module_file}" ]]; then
        error "Modul-Datei nicht gefunden: ${module_file}"
        MODULE_STATUS[$tag]="error"
        MODULE_NOTES[$tag]="Datei nicht gefunden"
        return
    fi

    section "Modul: ${MODULE_LABELS[$tag]}"
    
    CURRENT_MODULE="${tag}"
    if {
        # shellcheck disable=SC1090
        source "${module_file}"
        run_module_main
    }; then
        MODULE_STATUS[$tag]="${MODULE_STATUS[$tag]:-success}"
    else
        MODULE_STATUS[$tag]="error"
        MODULE_NOTES[$tag]="${MODULE_NOTES[$tag]:-Fehler beim Ausführen}"
        error "Modul ${tag} fehlgeschlagen — weiter mit nächstem Modul."
    fi
    unset CURRENT_MODULE
}

# ══════════════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════════════

main() {
    bootstrap
    header "Dein System wird konfiguriert."

    echo ""
    gum style --foreground="${GUM_DIM}" --margin="0 4" \
        "Willkommen! Dieses Script richtet dein frisches Manjaro vollständig ein." \
        "" \
        "Du wählst per Checkliste welche Module installiert werden sollen." \
        "Jedes Modul hat eigene Unter-Optionen." \
        "" \
        "Tipp: In Checklisten  Space = Toggle  /  Enter = Bestätigen  /  / = Filtern"
    echo ""
    gum input \
        --placeholder="[Enter] drücken um zu starten ..." \
        --prompt="  › " \
        --prompt.foreground="${GUM_BLUE}" \
        --width=50 \
        >/dev/null 2>/dev/null || true

    # Schritt 1: Modul-Auswahl
    local -a SELECTED_MODULES=()
    mapfile -t SELECTED_MODULES < <(step1_module_selection)

    if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then
        echo ""
        gum style --foreground="${GUM_YELLOW}" --margin="0 2" \
            "△  Keine Module gewählt. Setup beendet."
        exit 0
    fi

    # Schritt 4: Bestätigung
    if ! step4_confirmation "${SELECTED_MODULES[@]}"; then
        echo ""
        gum style --foreground="${GUM_YELLOW}" --margin="0 2" \
            "△  Abgebrochen. Keine Änderungen vorgenommen."
        exit 0
    fi

    # Schritt 5: Ausführung
    clear
    header "Installation läuft ..."

    for tag in "${SELECTED_MODULES[@]}"; do
        MODULE_STATUS[$tag]=""
        run_module "${tag}"
    done

    for tag in "${MODULE_TAGS[@]}"; do
        if [[ -z "${MODULE_STATUS[$tag]:-}" ]]; then
            MODULE_STATUS[$tag]="skipped"
        fi
    done

    show_summary
}

main "$@"
