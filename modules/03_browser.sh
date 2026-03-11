#!/usr/bin/env bash
# ── Modul 03: Browser ─────────────────────────────────────────

run_module_main() {
    local selected
    selected=$(checklist \
        "Browser" \
        "Wähle Browser (Mehrfachauswahl möglich):" \
        "firefox"    "Firefox (Open Source, oft vorinstalliert)"           "off" \
        "brave"      "Brave (Privacy-first, Chromium-basiert) [AUR]"       "off" \
        "chrome"     "Google Chrome [AUR]"                                  "off" \
        "chromium"   "Chromium (Open-Source Chrome)"                        "off" \
        "librewolf"  "Librewolf (gehärtetes Firefox) [AUR]"                "off" \
        "zen"        "Zen Browser (Firefox-basiert, modernes UI) [AUR]"    "off" \
    )

    [[ -z "${selected}" ]] && { skip "Kein Browser gewählt"; return; }

    declare -A OPTS=()
    for opt in ${selected}; do OPTS[$opt]=1; done

    local installed_list=()

    [[ -n "${OPTS[firefox]:-}" ]]   && { install_pkg firefox;               installed_list+=("Firefox"); }
    [[ -n "${OPTS[chromium]:-}" ]]  && { install_pkg chromium;              installed_list+=("Chromium"); }
    [[ -n "${OPTS[brave]:-}" ]]     && { install_aur brave-bin;             installed_list+=("Brave"); }
    [[ -n "${OPTS[chrome]:-}" ]]    && { install_aur google-chrome;         installed_list+=("Google Chrome"); }
    [[ -n "${OPTS[librewolf]:-}" ]] && { install_aur librewolf-bin;         installed_list+=("Librewolf"); }
    [[ -n "${OPTS[zen]:-}" ]]       && { install_aur zen-browser-bin;       installed_list+=("Zen Browser"); }

    local notes
    notes=$(IFS=", "; echo "${installed_list[*]}")
    MODULE_STATUS["03_browser"]="success"
    MODULE_NOTES["03_browser"]="${notes}"
}
