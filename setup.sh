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

# ── Colors (für Terminal-Ausgabe während Installation) ───────
BLUE='\033[38;2;96;165;250m'
DIM='\033[38;2;71;85;105m'
GREEN='\033[38;2;74;222;128m'
YELLOW='\033[38;2;250;204;21m'
RED='\033[38;2;239;68;68m'
BOLD='\033[1m'
RESET='\033[0m'

# Hex-Farben für gum
GUM_BLUE="#60a5fa"
GUM_GREEN="#4ade80"
GUM_YELLOW="#facc15"
GUM_RED="#ef4444"
GUM_DIM="#475569"

# ── Log-Funktionen (Terminal-Ausgabe während Installation) ────
info()    { echo -e "  ${BLUE}·${RESET} $*"; }
success() { echo -e "  ${GREEN}✓${RESET} $*"; }
warn()    { echo -e "  ${YELLOW}△${RESET} $*"; }
error()   { echo -e "  ${RED}✗${RESET} $*" >&2; }
skip()    { echo -e "  ${DIM}· $* — übersprungen${RESET}"; }

header() {
    clear
    gum style \
        --border=rounded \
        --border-foreground="${GUM_BLUE}" \
        --padding="1 4" \
        --margin="1 2" \
        "$(gum style --bold --foreground="${GUM_BLUE}" 'M A N J A R O   S E T U P')" \
        "" \
        "$(gum style --foreground="${GUM_DIM}" "$*")"
}

section() {
    echo ""
    gum style \
        --foreground="${GUM_BLUE}" \
        --bold \
        --margin="0 2" \
        "▸  $*"
    gum style \
        --foreground="${GUM_DIM}" \
        --margin="0 2" \
        "────────────────────────────────────────"
}

# ── Paket-Management ──────────────────────────────────────────
pkg_installed() { pacman -Qi "$1" &>/dev/null; }

install_pkg() {
    for pkg in "$@"; do
        if pkg_installed "$pkg"; then
            skip "$pkg bereits installiert"
        else
            gum spin \
                --spinner=dot \
                --spinner.foreground="${GUM_BLUE}" \
                --title="  Installiere ${pkg} ..." \
                -- sudo pacman -S --noconfirm --needed "$pkg" 2>/dev/null
            success "$pkg installiert"
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
            gum spin \
                --spinner=dot \
                --spinner.foreground="${GUM_BLUE}" \
                --title="  Installiere ${pkg} (AUR) ..." \
                -- yay -S --noconfirm --needed "$pkg" 2>/dev/null
            success "$pkg (AUR) installiert"
        fi
    done
}

# ── gum-Wrapper ───────────────────────────────────────────────

# checklist title text tag label status [tag label status ...]
# Gibt gewählte Tags (space-separated) zurück.
checklist() {
    local title="$1"
    local text="$2"
    shift 2

    local -a tags=() labels=() defaults=()
    while [[ $# -ge 3 ]]; do
        tags+=("$1")
        labels+=("$2")
        defaults+=("$3")
        shift 3
    done

    # Vorausgwählte Items als --selected-Flags
    local -a selected_args=()
    for i in "${!defaults[@]}"; do
        if [[ "${defaults[$i]}" == "on" ]]; then
            selected_args+=("--selected=${labels[$i]}")
        fi
    done

    echo ""
    gum style \
        --foreground="${GUM_BLUE}" \
        --bold \
        --margin="0 2" \
        "◆  ${title}"
    [[ -n "${text}" ]] && gum style \
        --foreground="${GUM_DIM}" \
        --margin="0 2" \
        "${text}"
    echo ""

    local chosen
    chosen=$(printf '%s\n' "${labels[@]}" | \
        gum choose --no-limit \
            "${selected_args[@]}" \
            --cursor="▶ " \
            --cursor.foreground="${GUM_BLUE}" \
            --selected.foreground="${GUM_GREEN}" \
            --header="" \
            2>/dev/null) || true

    [[ -z "${chosen}" ]] && return 0

    # Labels → Tags zurückführen
    local -a result_tags=()
    while IFS= read -r chosen_lbl; do
        for i in "${!labels[@]}"; do
            if [[ "${labels[$i]}" == "${chosen_lbl}" ]]; then
                result_tags+=("${tags[$i]}")
                break
            fi
        done
    done <<< "${chosen}"

    printf '%s ' "${result_tags[@]}"
}

inputbox() {
    local title="$1"
    local text="$2"
    local default="${3:-}"
    echo ""
    gum style --foreground="${GUM_BLUE}" --bold --margin="0 2" "◆  ${title}"
    gum input \
        --placeholder="${text}" \
        --value="${default}" \
        --prompt="  › " \
        --prompt.foreground="${GUM_BLUE}" \
        --cursor.foreground="${GUM_GREEN}" \
        --width=60 \
        2>/dev/null || true
}

yesno() {
    local title="$1"
    local text="$2"
    echo ""
    gum style --foreground="${GUM_BLUE}" --bold --margin="0 2" "◆  ${title}"
    [[ -n "${text}" ]] && gum style --foreground="${GUM_DIM}" --margin="0 2" "${text}"
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
        "$(gum style --bold --foreground="${GUM_BLUE}" "${title}")" \
        "" \
        "${text}"
    echo ""
    gum input --placeholder="[Enter] zum Schließen" --prompt="" --width=30 &>/dev/null || true
}

# ── Exports für Module ────────────────────────────────────────
export SCRIPT_DIR MODULES_DIR
export BLUE DIM GREEN YELLOW RED BOLD RESET
export GUM_BLUE GUM_GREEN GUM_YELLOW GUM_RED GUM_DIM
export -f info success warn error skip header section
export -f pkg_installed install_pkg install_aur
export -f checklist inputbox yesno msgbox

# ── Zusammenfassungs-Tracking ─────────────────────────────────
declare -A MODULE_STATUS=()
declare -A MODULE_NOTES=()

# ── Abbruch-Handler ───────────────────────────────────────────
trap 'clear
echo ""
gum style --border=rounded --border-foreground="${GUM_YELLOW}" --padding="1 3" --margin="1 2" \
    "$(gum style --bold --foreground="${GUM_YELLOW}" "△  Setup abgebrochen")" \
    "" \
    "$(gum style --foreground="${GUM_DIM}" "Bisher installiertes bleibt erhalten.")"
echo ""
exit 130' INT TERM

# ══════════════════════════════════════════════════════════════
#  PHASE 1: BOOTSTRAP
# ══════════════════════════════════════════════════════════════

bootstrap() {
    clear

    # Minimal-Banner vor gum (gum noch nicht verfügbar)
    echo -e "\n${BOLD}${BLUE}  M A N J A R O   S E T U P${RESET}"
    echo -e "  ${DIM}──────────────────────────────────${RESET}"
    echo -e "  Bootstrap wird vorbereitet ...\n"

    # OS-Prüfung
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

    info "Bootstrap-Pakete werden installiert ..."
    sudo pacman -Sy --noconfirm --needed git curl base-devel wget gum 2>&1 \
        | grep -v "^warning:" || true
    success "Bootstrap abgeschlossen — gum ist bereit."

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

step1_module_selection() {
    local items=()
    for tag in "${MODULE_TAGS[@]}"; do
        items+=("${tag}" "${MODULE_LABELS[$tag]}" "${MODULE_DEFAULT[$tag]}")
    done

    checklist \
        "Modul-Auswahl" \
        "Space = Toggle  ·  Enter = Bestätigen  ·  / = Filtern" \
        "${items[@]}"
}

step4_confirmation() {
    local selected_modules=("$@")
    echo ""
    gum style \
        --border=rounded \
        --border-foreground="${GUM_BLUE}" \
        --padding="1 3" \
        --margin="0 2" \
        "$(gum style --bold --foreground="${GUM_BLUE}" "Folgende Module werden installiert:")" \
        "" \
        "$(for tag in "${selected_modules[@]}"; do
            gum style --foreground="${GUM_GREEN}" "  ✓  ${MODULE_LABELS[$tag]}"
        done)"
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
        --width=60 \
        "$(gum style --bold --foreground="${GUM_BLUE}" 'M A N J A R O   S E T U P  —  Zusammenfassung')" \
        "" \
        "$(for tag in "${MODULE_TAGS[@]}"; do
            local status="${MODULE_STATUS[$tag]:-skipped}"
            local note="${MODULE_NOTES[$tag]:-}"
            local label="${MODULE_LABELS[$tag]}"
            local padded
            printf -v padded "%-30s" "${label}"
            case "${status}" in
                success) gum style --foreground="${GUM_GREEN}"  "  ✓  ${padded}${note}" ;;
                warn)    gum style --foreground="${GUM_YELLOW}" "  △  ${padded}${note}" ;;
                error)   gum style --foreground="${GUM_RED}"    "  ✗  ${padded}${note}" ;;
                skipped) gum style --foreground="${GUM_DIM}"    "  ─  ${padded}Übersprungen" ;;
            esac
        done)" \
        "" \
        "$(gum style --foreground="${GUM_DIM}" "One-Liner für neue Systeme:")" \
        "$(gum style --foreground="${GUM_BLUE}" "bash <(curl -fsSL https://raw.githubusercontent.com/Raindancer118/manjaro-setupper/main/setup.sh)")"

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

    header "Dein System wird konfiguriert."

    echo ""
    gum style --foreground="${GUM_DIM}" --margin="0 2" \
        "Willkommen! Dieses Script richtet dein frisches Manjaro ein."
    echo ""
    gum confirm \
        --prompt.foreground="${GUM_BLUE}" \
        --selected.background="${GUM_BLUE}" \
        --selected.foreground="#000000" \
        --unselected.foreground="${GUM_DIM}" \
        "Onboarding-Flow starten?" \
        2>/dev/null || { warn "Abgebrochen."; exit 0; }

    # Schritt 1: Modul-Auswahl
    local selected_str
    selected_str=$(step1_module_selection)

    if [[ -z "${selected_str// /}" ]]; then
        echo ""
        gum style --foreground="${GUM_YELLOW}" --margin="0 2" "△  Keine Module gewählt. Setup beendet."
        exit 0
    fi

    read -ra SELECTED_MODULES <<< "${selected_str}"

    # Schritt 4: Bestätigung
    if ! step4_confirmation "${SELECTED_MODULES[@]}"; then
        echo ""
        gum style --foreground="${GUM_YELLOW}" --margin="0 2" "△  Abgebrochen. Keine Änderungen vorgenommen."
        exit 0
    fi

    # Schritt 5: Ausführung
    clear
    header "Installation läuft ..."

    for tag in "${SELECTED_MODULES[@]}"; do
        MODULE_STATUS[$tag]=""
        run_module "${tag}"
    done

    # Nicht gewählte Module als skipped markieren
    for tag in "${MODULE_TAGS[@]}"; do
        if [[ -z "${MODULE_STATUS[$tag]:-}" ]]; then
            MODULE_STATUS[$tag]="skipped"
        fi
    done

    show_summary
}

main "$@"
