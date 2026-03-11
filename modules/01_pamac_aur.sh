#!/usr/bin/env bash
# ── Modul 01: Pamac AUR-Support + yay ────────────────────────

run_module_main() {
    local selected
    selected=$(checklist \
        "Pamac & AUR-Helper" \
        "Wähle die AUR-Optionen:" \
        "pamac_aur"     "Pamac AUR-Support aktivieren"          "on"  \
        "yay"           "yay als AUR-Helper installieren"        "on"  \
        "pamac_flatpak" "Pamac Flatpak-Support aktivieren"       "off" \
        "pamac_snap"    "Pamac Snap-Support aktivieren"          "off" \
    )

    [[ -z "${selected}" ]] && { skip "Keine Optionen gewählt"; return; }

    declare -A OPTS=()
    for opt in ${selected}; do OPTS[$opt]=1; done

    # ── Pamac AUR ──────────────────────────────────────────────
    if [[ -n "${OPTS[pamac_aur]:-}" ]]; then
        info "Pamac AUR-Support wird aktiviert ..."
        local conf="/etc/pamac.conf"
        if [[ -f "${conf}" ]]; then
            sudo sed -i 's/^#EnableAUR/EnableAUR/' "${conf}"
            sudo sed -i 's/^#CheckAURUpdates/CheckAURUpdates/' "${conf}"
            # Falls noch nicht vorhanden, am Ende einfügen
            grep -q "^EnableAUR" "${conf}" || echo "EnableAUR" | sudo tee -a "${conf}" > /dev/null
            grep -q "^CheckAURUpdates" "${conf}" || echo "CheckAURUpdates" | sudo tee -a "${conf}" > /dev/null
            success "Pamac AUR-Support aktiviert."
        else
            warn "/etc/pamac.conf nicht gefunden — Pamac möglicherweise nicht installiert."
        fi
    fi

    # ── yay ────────────────────────────────────────────────────
    if [[ -n "${OPTS[yay]:-}" ]]; then
        if command -v yay &>/dev/null; then
            skip "yay bereits installiert ($(yay --version | head -1))"
        else
            info "yay wird aus dem AUR gebaut ..."
            local build_dir
            build_dir=$(mktemp -d)
            git clone https://aur.archlinux.org/yay.git "${build_dir}/yay"
            (cd "${build_dir}/yay" && makepkg -si --noconfirm)
            rm -rf "${build_dir}"
            if command -v yay &>/dev/null; then
                success "yay installiert: $(yay --version | head -1)"
            else
                error "yay-Installation fehlgeschlagen."
                MODULE_STATUS["01_pamac_aur"]="error"
                MODULE_NOTES["01_pamac_aur"]="yay-Installation fehlgeschlagen"
                return 1
            fi
        fi
    fi

    # ── Pamac Flatpak ──────────────────────────────────────────
    if [[ -n "${OPTS[pamac_flatpak]:-}" ]]; then
        info "Pamac Flatpak-Support wird aktiviert ..."
        local conf="/etc/pamac.conf"
        if [[ -f "${conf}" ]]; then
            sudo sed -i 's/^#EnableFlatpak/EnableFlatpak/' "${conf}"
            grep -q "^EnableFlatpak" "${conf}" || echo "EnableFlatpak" | sudo tee -a "${conf}" > /dev/null
            success "Pamac Flatpak-Support aktiviert."
        fi
    fi

    # ── Pamac Snap ─────────────────────────────────────────────
    if [[ -n "${OPTS[pamac_snap]:-}" ]]; then
        info "Pamac Snap-Support wird aktiviert ..."
        local conf="/etc/pamac.conf"
        if [[ -f "${conf}" ]]; then
            sudo sed -i 's/^#EnableSnap/EnableSnap/' "${conf}"
            grep -q "^EnableSnap" "${conf}" || echo "EnableSnap" | sudo tee -a "${conf}" > /dev/null
            success "Pamac Snap-Support aktiviert."
        fi
    fi

    MODULE_STATUS["01_pamac_aur"]="${MODULE_STATUS["01_pamac_aur"]:-success}"
    MODULE_NOTES["01_pamac_aur"]="${MODULE_NOTES["01_pamac_aur"]:-Pamac AUR aktiviert, yay installiert}"
}
