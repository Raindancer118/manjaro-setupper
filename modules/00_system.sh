#!/usr/bin/env bash
# ── Modul 00: System-Basis & Sicherheit ──────────────────────

declare -A OPTS=()

run_module_main() {
    # Sub-Optionen auswählen
    local selected
    selected=$(checklist \
        "System-Basis & Sicherheit" \
        "Wähle die System-Optionen:" \
        "update"       "System vollständig updaten (pacman -Syu)"          "on"  \
        "mirror"       "Mirrorlist optimieren (reflector)"                  "on"  \
        "multilib"     "Multilib aktivieren (/etc/pacman.conf)"             "on"  \
        "kernelhdrs"   "Kernel-Header installieren (passend zu uname -r)"   "off" \
        "ufw"          "Firewall aktivieren (ufw, default deny incoming)"   "off" \
        "timeshift"    "Timeshift einrichten"                               "off" \
        "earlyoom"     "earlyoom installieren (verhindert RAM-Freeze)"      "off" \
        "zram"         "zram-generator einrichten (komprimierter Swap)"     "off" \
        "trim"         "SSD TRIM aktivieren (fstrim.timer)"                 "off" \
        "ntp"          "NTP-Zeitsynchronisation sicherstellen"              "on"  \
        "sudopasswd"   "Sudo ohne Passwort (opt-in, Sicherheitswarnung!)"   "off" \
        "darkmode"     "KDE Dark Mode aktivieren (lookandfeeltool)"         "off" \
    )

    [[ -z "${selected}" ]] && { skip "Keine Optionen gewählt"; return; }

    for opt in ${selected}; do OPTS[$opt]=1; done

    # Timeshift-Typ abfragen
    local timeshift_type=""
    if [[ -n "${OPTS[timeshift]:-}" ]]; then
        timeshift_type=$(dialog \
            --backtitle "Manjaro Setup" \
            --title "Timeshift — Backup-Typ" \
            --stdout \
            --radiolist "Welchen Backup-Typ für Timeshift?" \
            10 50 2 \
            "btrfs" "BTRFS (empfohlen für BTRFS-Dateisystem)" "on" \
            "rsync" "RSYNC (für ext4 und andere)"              "off" \
            2>/dev/null) || timeshift_type="rsync"
    fi

    # Sudo-Warnung
    if [[ -n "${OPTS[sudopasswd]:-}" ]]; then
        if ! yesno "Sicherheitswarnung" "Sudo ohne Passwort deaktiviert den Passwortschutz für administrative Aktionen.\n\nNur auf vertrauenswürdigen Systemen empfohlen!\n\nFortfahren?"; then
            unset "OPTS[sudopasswd]"
        fi
    fi

    # ── Ausführung ─────────────────────────────────────────────

    if [[ -n "${OPTS[update]:-}" ]]; then
        info "System wird aktualisiert ..."
        sudo pacman -Syu --noconfirm
        success "System-Update abgeschlossen."
    fi

    if [[ -n "${OPTS[mirror]:-}" ]]; then
        info "Mirrorlist wird optimiert ..."
        if ! pkg_installed reflector; then
            sudo pacman -S --noconfirm --needed reflector
        fi
        sudo reflector --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
        success "Mirrorlist optimiert."
    fi

    if [[ -n "${OPTS[multilib]:-}" ]]; then
        info "Multilib wird aktiviert ..."
        if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
            sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
            sudo pacman -Sy --noconfirm
            success "Multilib aktiviert."
        else
            skip "Multilib bereits aktiv"
        fi
    fi

    if [[ -n "${OPTS[kernelhdrs]:-}" ]]; then
        local kernel_ver
        kernel_ver=$(uname -r | grep -oP '^\d+\.\d+')
        local hdr_pkg="linux$(echo "${kernel_ver}" | tr -d '.')-headers"
        info "Kernel-Header werden installiert: ${hdr_pkg}"
        install_pkg "${hdr_pkg}" || install_pkg linux-headers
        success "Kernel-Header installiert."
    fi

    if [[ -n "${OPTS[ufw]:-}" ]]; then
        info "Firewall (ufw) wird eingerichtet ..."
        install_pkg ufw
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw --force enable
        sudo systemctl enable --now ufw
        success "Firewall aktiviert (default deny incoming)."
    fi

    if [[ -n "${OPTS[timeshift]:-}" ]]; then
        info "Timeshift wird eingerichtet (${timeshift_type}) ..."
        install_pkg timeshift
        success "Timeshift installiert. Bitte manuell konfigurieren (Startmenü → Timeshift)."
        MODULE_NOTES["00_system"]="Timeshift: Manuelle Erstkonfiguration erforderlich"
        MODULE_STATUS["00_system"]="warn"
    fi

    if [[ -n "${OPTS[earlyoom]:-}" ]]; then
        info "earlyoom wird installiert ..."
        install_pkg earlyoom
        sudo systemctl enable --now earlyoom
        success "earlyoom aktiviert."
    fi

    if [[ -n "${OPTS[zram]:-}" ]]; then
        info "zram-generator wird eingerichtet ..."
        install_pkg zram-generator
        if [[ ! -f /etc/systemd/zram-generator.conf ]]; then
            sudo tee /etc/systemd/zram-generator.conf > /dev/null <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF
        fi
        sudo systemctl daemon-reload
        sudo systemctl start systemd-zram-setup@zram0.service 2>/dev/null || true
        success "zram-generator eingerichtet."
    fi

    if [[ -n "${OPTS[trim]:-}" ]]; then
        info "SSD TRIM wird aktiviert ..."
        sudo systemctl enable --now fstrim.timer
        success "fstrim.timer aktiviert."
    fi

    if [[ -n "${OPTS[ntp]:-}" ]]; then
        info "NTP wird sichergestellt ..."
        sudo timedatectl set-ntp true
        success "NTP-Zeitsynchronisation aktiviert."
    fi

    if [[ -n "${OPTS[sudopasswd]:-}" ]]; then
        info "Sudo ohne Passwort wird konfiguriert ..."
        local sudoers_file="/etc/sudoers.d/${USER}-nopasswd"
        echo "${USER} ALL=(ALL) NOPASSWD: ALL" | sudo tee "${sudoers_file}" > /dev/null
        sudo chmod 440 "${sudoers_file}"
        warn "Sudo ohne Passwort für ${USER} aktiviert."
        if [[ -z "${MODULE_STATUS["00_system"]:-}" || "${MODULE_STATUS["00_system"]:-}" == "success" ]]; then
            MODULE_STATUS["00_system"]="warn"
            MODULE_NOTES["00_system"]="Sudo ohne Passwort aktiviert!"
        fi
    fi

    if [[ -n "${OPTS[darkmode]:-}" ]]; then
        info "KDE Dark Mode wird aktiviert ..."
        if command -v lookandfeeltool &>/dev/null; then
            lookandfeeltool -a org.kde.breezedark.desktop
            success "KDE Dark Mode aktiviert."
        else
            warn "lookandfeeltool nicht gefunden — Dark Mode muss manuell gesetzt werden."
        fi
    fi

    [[ -z "${MODULE_STATUS["00_system"]:-}" ]] && MODULE_STATUS["00_system"]="success"
    [[ -z "${MODULE_NOTES["00_system"]:-}" ]] && MODULE_NOTES["00_system"]="Update, Mirrorlist, Basis-Konfiguration"
}
