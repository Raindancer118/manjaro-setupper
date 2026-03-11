#!/usr/bin/env bash
# ── Modul 04: Kommunikation & Mail ────────────────────────────

run_module_main() {
    local selected
    selected=$(checklist \
        "Kommunikation & Mail" \
        "Wähle Kommunikations-Apps:" \
        "discord"    "Discord"                                         "off" \
        "signal"     "Signal Desktop"                                   "off" \
        "telegram"   "Telegram Desktop"                                 "off" \
        "thunderbird""Thunderbird (E-Mail-Client)"                      "off" \
        "slack"      "Slack [AUR]"                                      "off" \
        "zoom"       "Zoom [AUR]"                                       "off" \
        "teams"      "Microsoft Teams (inoffiziell) [AUR]"             "off" \
        "element"    "Element (Matrix-Client, E2E-verschlüsselt)"       "off" \
        "vesktop"    "Vesktop (verbesserter Discord-Client) [AUR]"      "off" \
    )

    [[ -z "${selected}" ]] && { skip "Keine Apps gewählt"; return; }

    declare -A OPTS=()
    for opt in ${selected}; do OPTS[$opt]=1; done

    local installed_list=()

    [[ -n "${OPTS[discord]:-}" ]]     && { install_pkg discord;                    installed_list+=("Discord"); }
    [[ -n "${OPTS[signal]:-}" ]]      && { install_pkg signal-desktop;             installed_list+=("Signal"); }
    [[ -n "${OPTS[telegram]:-}" ]]    && { install_pkg telegram-desktop;           installed_list+=("Telegram"); }
    [[ -n "${OPTS[thunderbird]:-}" ]] && { install_pkg thunderbird;                installed_list+=("Thunderbird"); }
    [[ -n "${OPTS[element]:-}" ]]     && { install_pkg element-desktop;            installed_list+=("Element"); }
    [[ -n "${OPTS[slack]:-}" ]]       && { install_aur slack-desktop;              installed_list+=("Slack"); }
    [[ -n "${OPTS[zoom]:-}" ]]        && { install_aur zoom;                       installed_list+=("Zoom"); }
    [[ -n "${OPTS[teams]:-}" ]]       && { install_aur teams-for-linux-bin;        installed_list+=("Teams"); }
    [[ -n "${OPTS[vesktop]:-}" ]]     && { install_aur vesktop-bin;                installed_list+=("Vesktop"); }

    local notes
    notes=$(IFS=", "; echo "${installed_list[*]}")
    MODULE_STATUS["04_communication"]="success"
    MODULE_NOTES["04_communication"]="${notes}"
}
