#!/usr/bin/env bash
# ── Modul 06: Office-Suiten ───────────────────────────────────

run_module_main() {
    local selected
    selected=$(checklist \
        "Office-Suiten" \
        "Wähle Office-Anwendungen:" \
        "onlyoffice"   "ONLYOFFICE (modernes UI, MS-Office-Kompatibilität) [AUR]" "off" \
        "libreoffice"  "LibreOffice Fresh (quelloffen, vollständig)"               "off" \
        "libreoffice_s""LibreOffice Still (stabilere LTS-Version)"                 "off" \
        "wps"          "WPS Office (kommerziell, sehr MS-Office-ähnlich) [AUR]"   "off" \
        "okular"       "Okular (KDE PDF-Viewer)"                                    "off" \
        "calibre"      "Calibre (E-Book-Verwaltung)"                               "off" \
    )

    [[ -z "${selected}" ]] && { skip "Keine Apps gewählt"; return; }

    declare -A OPTS=()
    for opt in ${selected}; do OPTS[$opt]=1; done

    local installed_list=()

    [[ -n "${OPTS[libreoffice]:-}" ]]  && { install_pkg libreoffice-fresh;    installed_list+=("LibreOffice Fresh"); }
    [[ -n "${OPTS[libreoffice_s]:-}" ]]&& { install_pkg libreoffice-still;    installed_list+=("LibreOffice Still"); }
    [[ -n "${OPTS[okular]:-}" ]]       && { install_pkg okular;               installed_list+=("Okular"); }
    [[ -n "${OPTS[calibre]:-}" ]]      && { install_pkg calibre;              installed_list+=("Calibre"); }
    [[ -n "${OPTS[onlyoffice]:-}" ]]   && { install_aur onlyoffice-bin;       installed_list+=("ONLYOFFICE"); }
    [[ -n "${OPTS[wps]:-}" ]]          && { install_aur wps-office;           installed_list+=("WPS Office"); }

    local notes
    notes=$(IFS=", "; echo "${installed_list[*]}")
    MODULE_STATUS["06_office"]="success"
    MODULE_NOTES["06_office"]="${notes}"
}
