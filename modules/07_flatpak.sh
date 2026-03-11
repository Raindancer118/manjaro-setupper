#!/usr/bin/env bash
# ── Modul 07: Flatpak & Flathub ───────────────────────────────

run_module_main() {
    local selected
    selected=$(checklist \
        "Flatpak & Flathub" \
        "Wähle Flatpak-Optionen:" \
        "flatpak"     "Flatpak installieren"                              "on"  \
        "flathub"     "Flathub als Repository hinzufügen"                 "on"  \
        "xdg_kde"     "xdg-desktop-portal-kde (KDE Plasma Integration)"  "off" \
        "discover"    "KDE Discover Flatpak-Plugin"                        "off" \
    )

    [[ -z "${selected}" ]] && { skip "Keine Optionen gewählt"; return; }

    declare -A OPTS=()
    for opt in ${selected}; do OPTS[$opt]=1; done

    local installed_list=()

    if [[ -n "${OPTS[flatpak]:-}" ]]; then
        install_pkg flatpak
        installed_list+=("Flatpak")
    fi

    if [[ -n "${OPTS[flathub]:-}" ]]; then
        if ! command -v flatpak &>/dev/null; then
            warn "Flatpak ist nicht installiert — Flathub wird übersprungen."
        else
            info "Flathub wird hinzugefügt ..."
            flatpak remote-add --if-not-exists flathub \
                https://dl.flathub.org/repo/flathub.flatpakrepo
            success "Flathub hinzugefügt."
            installed_list+=("Flathub")
        fi
    fi

    if [[ -n "${OPTS[xdg_kde]:-}" ]]; then
        install_pkg xdg-desktop-portal-kde
        installed_list+=("xdg-portal-kde")
    fi

    if [[ -n "${OPTS[discover]:-}" ]]; then
        install_pkg discover packagekit-qt6 flatpak-kcm
        installed_list+=("Discover-Flatpak-Plugin")
    fi

    local notes
    notes=$(IFS=", "; echo "${installed_list[*]}")
    MODULE_STATUS["07_flatpak"]="success"
    MODULE_NOTES["07_flatpak"]="${notes}"
}
