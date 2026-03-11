#!/usr/bin/env bash
# ── Modul 11: KDE-spezifische Anpassungen ────────────────────

run_module_main() {
    local selected
    selected=$(checklist \
        "KDE-Anpassungen" \
        "Wähle KDE-spezifische Optionen:" \
        "darkmode"     "Dark Mode aktivieren (Breeze Dark)"               "off" \
        "kvantum"      "Kvantum (erweiterte Qt-Theme-Engine)"              "off" \
        "yakuake"      "Yakuake (Dropdown-Terminal, KDE-nativ)"           "off" \
        "kdeconnect"   "KDE Connect (Smartphone-Integration)"             "off" \
        "spectacle"    "Spectacle (Screenshot-Tool)"                       "off" \
        "filelight"    "Filelight (grafische Festplatten-Analyse)"        "off" \
        "xdg_dirs"     "xdg-user-dirs anlegen (Downloads, Bilder, etc.)" "off" \
        "plasma_browser""Plasma-Browser-Integration"                       "off" \
        "global_menu"  "Global Menu in Taskbar aktivieren"                "off" \
    )

    [[ -z "${selected}" ]] && { skip "Keine Optionen gewählt"; return; }

    declare -A OPTS=()
    for opt in ${selected}; do OPTS[$opt]=1; done

    local installed_list=()

    # ── Dark Mode ──────────────────────────────────────────────
    if [[ -n "${OPTS[darkmode]:-}" ]]; then
        if command -v lookandfeeltool &>/dev/null; then
            lookandfeeltool -a org.kde.breezedark.desktop
            success "KDE Dark Mode (Breeze Dark) aktiviert."
            installed_list+=("Dark Mode")
        else
            warn "lookandfeeltool nicht verfügbar — Dark Mode muss manuell gesetzt werden."
            warn "Systemeinstellungen → Erscheinungsbild → Globales Thema → Breeze Dark"
        fi
    fi

    # ── Kvantum ────────────────────────────────────────────────
    if [[ -n "${OPTS[kvantum]:-}" ]]; then
        install_pkg kvantum
        installed_list+=("Kvantum")
    fi

    # ── Yakuake ────────────────────────────────────────────────
    if [[ -n "${OPTS[yakuake]:-}" ]]; then
        install_pkg yakuake
        # Autostart einrichten
        local autostart_dir="${HOME}/.config/autostart"
        mkdir -p "${autostart_dir}"
        if [[ ! -f "${autostart_dir}/yakuake.desktop" ]]; then
            cat > "${autostart_dir}/yakuake.desktop" <<'EOF'
[Desktop Entry]
Exec=yakuake
Icon=yakuake
Name=Yakuake
Type=Application
X-KDE-autostart-phase=1
EOF
        fi
        success "Yakuake installiert + Autostart eingerichtet."
        installed_list+=("Yakuake")
    fi

    # ── KDE Connect ────────────────────────────────────────────
    if [[ -n "${OPTS[kdeconnect]:-}" ]]; then
        install_pkg kdeconnect
        # Firewall-Regel für KDE Connect (falls ufw aktiv)
        if command -v ufw &>/dev/null && sudo ufw status | grep -q "active"; then
            sudo ufw allow 1714:1764/tcp comment "KDE Connect" 2>/dev/null || true
            sudo ufw allow 1714:1764/udp comment "KDE Connect" 2>/dev/null || true
        fi
        installed_list+=("KDE Connect")
    fi

    # ── Spectacle ──────────────────────────────────────────────
    if [[ -n "${OPTS[spectacle]:-}" ]]; then
        install_pkg spectacle
        installed_list+=("Spectacle")
    fi

    # ── Filelight ──────────────────────────────────────────────
    if [[ -n "${OPTS[filelight]:-}" ]]; then
        install_pkg filelight
        installed_list+=("Filelight")
    fi

    # ── xdg-user-dirs ──────────────────────────────────────────
    if [[ -n "${OPTS[xdg_dirs]:-}" ]]; then
        install_pkg xdg-user-dirs
        xdg-user-dirs-update
        success "Standard-Benutzerordner angelegt."
        installed_list+=("xdg-user-dirs")
    fi

    # ── Plasma-Browser-Integration ─────────────────────────────
    if [[ -n "${OPTS[plasma_browser]:-}" ]]; then
        install_pkg plasma-browser-integration
        success "Plasma-Browser-Integration installiert."
        info "Bitte die Browser-Erweiterung im Browser installieren."
        installed_list+=("Plasma-Browser-Integration")
    fi

    # ── Global Menu ────────────────────────────────────────────
    if [[ -n "${OPTS[global_menu]:-}" ]]; then
        install_pkg appmenu-gtk-module libdbusmenu-glib
        if command -v kwriteconfig5 &>/dev/null; then
            kwriteconfig5 --file kwinrc --group Plugins --key appmenuEnabled true
            success "Global Menu aktiviert (Neustart von KWin empfohlen)."
        else
            info "Global Menu: Pakete installiert. Bitte manuell in Systemeinstellungen aktivieren."
        fi
        installed_list+=("Global Menu")
    fi

    local notes
    notes=$(IFS=", "; echo "${installed_list[*]}")
    MODULE_STATUS["11_kde"]="success"
    MODULE_NOTES["11_kde"]="${notes}"
}
