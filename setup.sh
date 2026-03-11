#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
#  Manjaro Setup — Interaktiver Onboarding-Installer
#  Usage: bash setup.sh
#  Remote: bash <(curl -fsSL https://raw.githubusercontent.com/Raindancer118/manjaro-setupper/main/setup.sh)
# ──────────────────────────────────────────────────────────────

REPO_URL="https://github.com/Raindancer118/manjaro-setupper.git"

# ── Remote-Erkennung & Self-Bootstrap ────────────────────────
# Wenn via "bash <(curl ...)" gestartet, existiert kein modules/-Ordner
# neben BASH_SOURCE[0]. In diesem Fall klont das Script sich selbst
# in ein Temp-Verzeichnis und startet von dort neu.
_detect_script_dir() {
    local src="${BASH_SOURCE[0]}"
    # Prüfe ob src ein echter Dateipfad ist (nicht /dev/fd/...)
    if [[ "${src}" == /dev/fd/* || "${src}" == /proc/* || ! -f "${src}" ]]; then
        echo ""
        return
    fi
    cd "$(dirname "${src}")" && pwd
}

SCRIPT_DIR="$(_detect_script_dir)"
MODULES_DIR="${SCRIPT_DIR}/modules"

# Falls kein lokales modules/-Verzeichnis gefunden → Repo klonen & neu starten
if [[ -z "${SCRIPT_DIR}" || ! -d "${MODULES_DIR}" ]]; then
    TMPDIR_REPO="$(mktemp -d)"
    echo -e "\n\033[38;2;96;165;250m  ·\033[0m Lade Manjaro Setup herunter ..."
    if command -v git &>/dev/null; then
        git clone --depth=1 "${REPO_URL}" "${TMPDIR_REPO}/repo" &>/dev/null
    else
        # git noch nicht installiert → erst pacman bootstrap
        sudo pacman -Sy --noconfirm --needed git &>/dev/null
        git clone --depth=1 "${REPO_URL}" "${TMPDIR_REPO}/repo" &>/dev/null
    fi
    echo -e "  \033[38;2;74;222;128m✓\033[0m Download abgeschlossen. Starte Setup ..."
    exec bash "${TMPDIR_REPO}/repo/setup.sh" "$@"
fi

# ── Colors ────────────────────────────────────────────────────
BLUE='\033[38;2;96;165;250m'
DIM='\033[38;2;71;85;105m'
GREEN='\033[38;2;74;222;128m'
YELLOW='\033[38;2;250;204;21m'
RED='\033[38;2;239;68;68m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Log-Funktionen ────────────────────────────────────────────
info()    { echo -e "  ${BLUE}·${RESET} $*"; }
success() { echo -e "  ${GREEN}✓${RESET} $*"; }
warn()    { echo -e "  ${YELLOW}△${RESET} $*"; }
error()   { echo -e "  ${RED}✗${RESET} $*" >&2; }
skip()    { echo -e "  ${DIM}· $* — übersprungen${RESET}"; }
header()  {
    echo -e "\n${BOLD}${BLUE}  M A N J A R O   S E T U P${RESET}"
    echo -e "  ${DIM}──────────────────────────────────${RESET}"
    echo -e "  $*\n"
}
section() {
    echo -e "\n  ${BOLD}$*${RESET}"
    echo -e "  ${DIM}────────────────────────────────────────${RESET}"
}

# ── Paket-Management ──────────────────────────────────────────
pkg_installed() { pacman -Qi "$1" &>/dev/null; }

install_pkg() {
    for pkg in "$@"; do
        if pkg_installed "$pkg"; then
            skip "$pkg bereits installiert"
        else
            info "Installiere $pkg ..."
            sudo pacman -S --noconfirm --needed "$pkg"
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
            info "Installiere $pkg (AUR) ..."
            yay -S --noconfirm --needed "$pkg"
        fi
    done
}

# ── Dialog-Wrapper ────────────────────────────────────────────
DIALOG_BACKTITLE="Manjaro Setup"
DIALOG_HEIGHT=0
DIALOG_WIDTH=0

# Zeigt eine Checkliste und gibt die gewählten Items (space-separated) zurück.
# Rückgabe "" wenn abgebrochen.
checklist() {
    local title="$1"
    local text="$2"
    shift 2
    # $@ = item tag item_text item_status [help_text] ...
    local result
    result=$(dialog \
        --backtitle "${DIALOG_BACKTITLE}" \
        --title "${title}" \
        --stdout \
        --checklist "${text}" \
        ${DIALOG_HEIGHT} ${DIALOG_WIDTH} 20 \
        "$@" 2>/dev/null) || true
    echo "${result}"
}

inputbox() {
    local title="$1"
    local text="$2"
    local default="${3:-}"
    local result
    result=$(dialog \
        --backtitle "${DIALOG_BACKTITLE}" \
        --title "${title}" \
        --stdout \
        --inputbox "${text}" \
        10 60 "${default}" 2>/dev/null) || true
    echo "${result}"
}

yesno() {
    local title="$1"
    local text="$2"
    dialog \
        --backtitle "${DIALOG_BACKTITLE}" \
        --title "${title}" \
        --yesno "${text}" \
        10 60 2>/dev/null
}

msgbox() {
    local title="$1"
    local text="$2"
    dialog \
        --backtitle "${DIALOG_BACKTITLE}" \
        --title "${title}" \
        --msgbox "${text}" \
        ${DIALOG_HEIGHT} ${DIALOG_WIDTH} 2>/dev/null || true
}

# ── Exports für Module ────────────────────────────────────────
export SCRIPT_DIR MODULES_DIR
export BLUE DIM GREEN YELLOW RED BOLD RESET
export -f info success warn error skip header section
export -f pkg_installed install_pkg install_aur
export -f checklist inputbox yesno msgbox

# ── Zusammenfassungs-Tracking ─────────────────────────────────
declare -A MODULE_STATUS=()
declare -A MODULE_NOTES=()

# ── Abbruch-Handler ───────────────────────────────────────────
trap 'clear; dialog --backtitle "Manjaro Setup" --title "Abbruch" --msgbox "Abbruch! Bisher installiertes bleibt erhalten." 8 50 2>/dev/null || true; clear; echo -e "\n  ${YELLOW}△${RESET} Setup abgebrochen. Bisher installiertes bleibt erhalten.\n"; exit 130' INT TERM

# ══════════════════════════════════════════════════════════════
#  PHASE 1: BOOTSTRAP
# ══════════════════════════════════════════════════════════════

bootstrap() {
    clear
    header "Bootstrap wird vorbereitet ..."

    # OS-Prüfung
    if [[ ! -f /etc/os-release ]]; then
        error "/etc/os-release nicht gefunden. Dieses Script läuft nur auf Manjaro/Arch."
        exit 1
    fi
    source /etc/os-release
    if [[ "${ID}" != "manjaro" && "${ID_LIKE:-}" != *"arch"* && "${ID}" != "arch" ]]; then
        error "Dieses Script ist für Manjaro/Arch gedacht. Erkanntes OS: ${ID}"
        exit 1
    fi
    success "OS erkannt: ${PRETTY_NAME}"

    # Root-Warnung
    if [[ "${EUID}" -eq 0 ]]; then
        warn "Du läufst als root. sudo wird intern verwendet — normaler User empfohlen."
    fi

    # Bootstrap-Pakete
    info "Bootstrap-Pakete werden installiert (dialog, git, curl, base-devel, wget) ..."
    sudo pacman -Sy --noconfirm --needed dialog git curl base-devel wget 2>&1 \
        | grep -v "^warning:" || true
    success "Bootstrap abgeschlossen."

    sleep 1
}

# ══════════════════════════════════════════════════════════════
#  PHASE 2: ONBOARDING-FLOW
# ══════════════════════════════════════════════════════════════

# Modul-Definitionen: tag | Anzeigename | Hilfetext
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

declare -A MODULE_HELP=(
    ["00_system"]="Update, Mirrorlist, Firewall, zram, TRIM, earlyoom und mehr.\nGrundlage für ein stabiles System."
    ["01_pamac_aur"]="Aktiviert AUR-Unterstützung in Pamac und installiert yay\nals AUR-Helper für Community-Pakete."
    ["02_shell"]="Zsh + Starship Prompt, fzf, bat, eza, ripgrep, btop\nund weitere Terminal-Tools."
    ["03_browser"]="Firefox, Brave, Chrome, Chromium, Librewolf, Zen Browser\n— Mehrfachauswahl möglich."
    ["04_communication"]="Discord, Signal, Telegram, Thunderbird, Slack, Zoom,\nTeams, Element, Vesktop."
    ["05_media"]="MPV, VLC, Spotify, OBS, GIMP, Inkscape, Kdenlive,\nffmpeg, yt-dlp und Fonts."
    ["06_office"]="ONLYOFFICE, LibreOffice Fresh/Still, WPS Office,\nOkular, Calibre."
    ["07_flatpak"]="Installiert Flatpak und fügt Flathub als Repository\nhinzu. KDE Discover Integration optional."
    ["08_dev"]="Git, SSH, Docker, NVM/Node, Python, Rust, Go,\nEditoren (VSCode, Neovim), AI-Tools."
    ["09_gaming"]="Steam, Lutris, Heroic, Bottles, Proton-GE, MangoHud,\nGameMode, Wine und mehr."
    ["10_system_tools"]="NTFS, Archiver, KeePassXC, Syncthing, GParted,\nTLP, ClamAV und weitere System-Tools."
    ["11_kde"]="Dark Mode, Kvantum, Yakuake, KDE Connect, Filelight,\nPlasma Browser Integration."
)

# Standard-Auswahl (empfohlen vorausgewählt)
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

step1_module_selection() {
    local items=()
    for tag in "${MODULE_TAGS[@]}"; do
        items+=("${tag}" "${MODULE_LABELS[$tag]}" "${MODULE_DEFAULT[$tag]}")
    done

    local selected
    selected=$(checklist \
        "Modul-Auswahl" \
        "Wähle die Module, die installiert werden sollen.\n[Leertaste] = Toggle  [Enter] = Bestätigen  [?] = Hilfe" \
        "${items[@]}")

    # Hilfe-Schleife: Wenn User "?" eingibt kommt leere Auswahl, daher
    # interpretieren wir einen leeren Return mit Backtick als direkte Hilfe-Anfrage.
    echo "${selected}"
}

show_module_help() {
    local tag="$1"
    msgbox "Hilfe: ${MODULE_LABELS[$tag]}" "${MODULE_HELP[$tag]}"
}

# ── Bestätigungsscreen ────────────────────────────────────────
step4_confirmation() {
    local selected_modules=("$@")
    local summary="Folgende Module werden installiert:\n\n"
    for tag in "${selected_modules[@]}"; do
        summary+="  • ${MODULE_LABELS[$tag]}\n"
    done
    summary+="\nFortfahren?"

    yesno "Bestätigung" "${summary}"
}

# ── Zusammenfassung anzeigen ──────────────────────────────────
show_summary() {
    clear
    echo -e "\n${BOLD}${BLUE}  M A N J A R O   S E T U P  —  Zusammenfassung${RESET}"
    echo -e "  ${DIM}──────────────────────────────────────────────${RESET}\n"

    for tag in "${MODULE_TAGS[@]}"; do
        local status="${MODULE_STATUS[$tag]:-skipped}"
        local note="${MODULE_NOTES[$tag]:-}"
        local label="${MODULE_LABELS[$tag]}"
        local padded
        printf -v padded "%-26s" "${label}"

        case "${status}" in
            success) echo -e "  ${GREEN}✓${RESET}  ${padded} ${DIM}${note}${RESET}" ;;
            warn)    echo -e "  ${YELLOW}△${RESET}  ${padded} ${YELLOW}${note}${RESET}" ;;
            error)   echo -e "  ${RED}✗${RESET}  ${padded} ${RED}${note}${RESET}" ;;
            skipped) echo -e "  ${DIM}─  ${padded} Übersprungen${RESET}" ;;
        esac
    done

    echo -e "\n  ${DIM}──────────────────────────────────────────────${RESET}"
    echo -e "\n  ${BOLD}${GREEN}Setup abgeschlossen!${RESET}"
    echo -e "\n  ${DIM}Führe dieses Script auf einem neuen System aus mit:${RESET}"
    echo -e "\n  ${BLUE}  bash <(curl -fsSL https://raw.githubusercontent.com/Raindancer118/manjaro-setupper/main/setup.sh)${RESET}\n"
    echo -e "  ${DIM}Drücke [Enter] zum Beenden.${RESET}"
    read -r
}

# ── Modul ausführen ───────────────────────────────────────────
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

    # Modul in Subshell ausführen → Fehler stoppen nicht alles
    if (
        # shellcheck disable=SC1090
        source "${module_file}"
        run_module_main
    ); then
        MODULE_STATUS[$tag]="${MODULE_STATUS[$tag]:-success}"
    else
        MODULE_STATUS[$tag]="error"
        MODULE_NOTES[$tag]="${MODULE_NOTES[$tag]:-Fehler beim Ausführen}"
        error "Modul ${tag} fehlgeschlagen — weiter mit nächstem Modul."
    fi
}

# ══════════════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════════════

main() {
    bootstrap

    clear
    header "Dein System wird konfiguriert."
    info "Drücke [Enter] um den Onboarding-Flow zu starten ..."
    read -r

    # Schritt 1: Modul-Auswahl
    local selected_str
    selected_str=$(step1_module_selection)

    if [[ -z "${selected_str}" ]]; then
        clear
        warn "Keine Module gewählt. Setup beendet."
        exit 0
    fi

    # String in Array umwandeln
    read -ra SELECTED_MODULES <<< "${selected_str}"

    # Schritt 2 & 3: Sub-Optionen + Input pro Modul
    # (wird innerhalb jedes Moduls via run_module_main gemacht)

    # Schritt 4: Bestätigung
    if ! step4_confirmation "${SELECTED_MODULES[@]}"; then
        clear
        warn "Abgebrochen. Keine Änderungen vorgenommen."
        exit 0
    fi

    # Schritt 5: Ausführung
    clear
    header "Installation läuft ..."

    for tag in "${SELECTED_MODULES[@]}"; do
        # Status für nicht-gewählte Module auf skipped
        MODULE_STATUS[$tag]="skipped"
    done

    for tag in "${SELECTED_MODULES[@]}"; do
        MODULE_STATUS[$tag]=""
        run_module "${tag}"
    done

    # Finale Zusammenfassung
    # Alle nicht-ausgeführten Module als skipped markieren
    for tag in "${MODULE_TAGS[@]}"; do
        if [[ -z "${MODULE_STATUS[$tag]:-}" ]]; then
            MODULE_STATUS[$tag]="skipped"
        fi
    done

    show_summary
}

main "$@"
