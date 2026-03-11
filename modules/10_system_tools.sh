#!/usr/bin/env bash
# ── Modul 10: Nützliche System-Tools ─────────────────────────

run_module_main() {
    local selected
    selected=$(checklist \
        "Nützliche System-Tools" \
        "Wähle System-Tools:" \
        "ntfs"        "ntfs-3g (Windows-Partitionen lesen/schreiben)"    "off" \
        "exfat"       "exfatprogs (exFAT-Unterstützung)"                  "off" \
        "archives"    "p7zip + unrar + unzip (Archiv-Tools)"             "off" \
        "fastfetch"   "fastfetch (System-Info-Tool)"                      "off" \
        "tldr"        "tldr (vereinfachte Man-Pages)"                     "off" \
        "keepassxc"   "KeePassXC (lokaler Passwort-Manager)"              "off" \
        "bitwarden"   "Bitwarden (Cloud-Passwort-Manager)"                "off" \
        "syncthing"   "Syncthing (dezentrale Datei-Synchronisation)"      "off" \
        "ventoy"      "Ventoy (Multi-Boot USB-Stick erstellen) [AUR]"    "off" \
        "gparted"     "GParted (grafisches Partitionierungstool)"         "off" \
        "cpux"        "CPU-X (CPU-Info-Tool) [AUR]"                       "off" \
        "clamav"      "ClamAV (Antivirus, optional)"                      "off" \
        "tlp"         "TLP (Laptop-Akku-Optimierung)"                     "off" \
        "autocpufreq" "auto-cpufreq (CPU-Frequenz für Laptops) [AUR]"   "off" \
    )

    [[ -z "${selected}" ]] && { skip "Keine Tools gewählt"; return; }

    declare -A OPTS=()
    for opt in ${selected}; do OPTS[$opt]=1; done

    local installed_list=()

    [[ -n "${OPTS[ntfs]:-}" ]]      && { install_pkg ntfs-3g;                installed_list+=("ntfs-3g"); }
    [[ -n "${OPTS[exfat]:-}" ]]     && { install_pkg exfatprogs;             installed_list+=("exfatprogs"); }
    [[ -n "${OPTS[fastfetch]:-}" ]] && { install_pkg fastfetch;              installed_list+=("fastfetch"); }
    [[ -n "${OPTS[tldr]:-}" ]]      && { install_pkg tldr;                   installed_list+=("tldr"); }
    [[ -n "${OPTS[keepassxc]:-}" ]] && { install_pkg keepassxc;              installed_list+=("KeePassXC"); }
    [[ -n "${OPTS[bitwarden]:-}" ]] && { install_pkg bitwarden;              installed_list+=("Bitwarden"); }
    [[ -n "${OPTS[syncthing]:-}" ]] && { install_pkg syncthing;              installed_list+=("Syncthing"); }
    [[ -n "${OPTS[gparted]:-}" ]]   && { install_pkg gparted;                installed_list+=("GParted"); }
    [[ -n "${OPTS[clamav]:-}" ]]    && { install_pkg clamav;                 installed_list+=("ClamAV"); }
    [[ -n "${OPTS[ventoy]:-}" ]]    && { install_aur ventoy;                 installed_list+=("Ventoy"); }
    [[ -n "${OPTS[cpux]:-}" ]]      && { install_aur cpu-x;                  installed_list+=("CPU-X"); }
    [[ -n "${OPTS[autocpufreq]:-}" ]]&& { install_aur auto-cpufreq;          installed_list+=("auto-cpufreq"); }

    if [[ -n "${OPTS[archives]:-}" ]]; then
        install_pkg p7zip unzip
        install_aur unrar
        installed_list+=("p7zip+unrar+unzip")
    fi

    if [[ -n "${OPTS[tlp]:-}" ]]; then
        install_pkg tlp tlp-rdw
        sudo systemctl enable --now tlp
        # Disable conflicting service
        sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket 2>/dev/null || true
        success "TLP aktiviert."
        installed_list+=("TLP")
    fi

    if [[ -n "${OPTS[clamav]:-}" ]]; then
        info "ClamAV Datenbank wird aktualisiert ..."
        sudo freshclam 2>/dev/null || true
    fi

    local notes
    notes=$(IFS=", "; echo "${installed_list[*]}")
    MODULE_STATUS["10_system_tools"]="success"
    MODULE_NOTES["10_system_tools"]="${notes}"
}
