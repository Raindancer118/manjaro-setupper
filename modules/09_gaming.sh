#!/usr/bin/env bash
# ── Modul 09: Gaming ──────────────────────────────────────────

run_module_main() {
    local selected
    selected=$(checklist \
        "Gaming" \
        "Wähle Gaming-Tools (Steam benötigt Multilib!):" \
        "steam"      "Steam (benötigt Multilib)"                        "off" \
        "lutris"     "Lutris (Game-Launcher für alles)"                 "off" \
        "heroic"     "Heroic Games Launcher (Epic + GOG) [AUR]"        "off" \
        "bottles"    "Bottles (Windows-Apps in Containern) [AUR]"      "off" \
        "proton_ge"  "Proton-GE (verbesserte Steam-Proton-Version) [AUR]" "off" \
        "mangohud"   "MangoHud (In-Game Overlay: FPS, Temps)"           "off" \
        "gamemode"   "GameMode (CPU/GPU-Boost während Spielen)"         "off" \
        "xpadneo"    "xpadneo (verbesserter Xbox-Gamepad-Treiber) [AUR]""off" \
        "antimicrox" "AntiMicroX (Gamepad → Tastatur/Maus-Mapper) [AUR]""off" \
        "lunar"      "Lunar Client (Minecraft-Performance-Client) [AUR]""off" \
        "wine"       "Wine Staging"                                       "off" \
    )

    [[ -z "${selected}" ]] && { skip "Keine Gaming-Tools gewählt"; return; }

    declare -A OPTS=()
    for opt in ${selected}; do OPTS[$opt]=1; done

    local installed_list=()

    if [[ -n "${OPTS[steam]:-}" ]]; then
        # Multilib prüfen
        if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
            warn "Multilib ist nicht aktiviert. Steam benötigt Multilib!"
            if yesno "Multilib aktivieren?" "Multilib ist für Steam erforderlich.\nJetzt aktivieren?"; then
                sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
                sudo pacman -Sy --noconfirm
            fi
        fi
        install_pkg steam
        installed_list+=("Steam")
    fi

    [[ -n "${OPTS[lutris]:-}" ]]   && { install_pkg lutris;                     installed_list+=("Lutris"); }
    [[ -n "${OPTS[mangohud]:-}" ]] && { install_pkg mangohud;                   installed_list+=("MangoHud"); }
    [[ -n "${OPTS[gamemode]:-}" ]] && { install_pkg gamemode;                   installed_list+=("GameMode"); }
    [[ -n "${OPTS[wine]:-}" ]]     && { install_pkg wine-staging;               installed_list+=("Wine Staging"); }
    [[ -n "${OPTS[heroic]:-}" ]]   && { install_aur heroic-games-launcher-bin;  installed_list+=("Heroic"); }
    [[ -n "${OPTS[bottles]:-}" ]]  && { install_aur bottles;                    installed_list+=("Bottles"); }
    [[ -n "${OPTS[proton_ge]:-}" ]]&& { install_aur proton-ge-custom-bin;       installed_list+=("Proton-GE"); }
    [[ -n "${OPTS[xpadneo]:-}" ]]  && { install_aur xpadneo-dkms;               installed_list+=("xpadneo"); }
    [[ -n "${OPTS[antimicrox]:-}" ]]&& { install_aur antimicrox;                installed_list+=("AntiMicroX"); }
    [[ -n "${OPTS[lunar]:-}" ]]    && { install_aur lunarclient;                installed_list+=("Lunar Client"); }

    local notes
    notes=$(IFS=", "; echo "${installed_list[*]}")
    MODULE_STATUS["09_gaming"]="success"
    MODULE_NOTES["09_gaming"]="${notes}"
}
