#!/usr/bin/env bash
# ── Modul 05: Medien, Grafik & Fonts ─────────────────────────

run_module_main() {
    local selected
    selected=$(checklist \
        "Medien, Grafik & Fonts" \
        "Wähle Medien-Apps und Fonts:" \
        "mpv"         "MPV (schlanker Video-Player)"                     "off" \
        "vlc"         "VLC (universeller Media-Player)"                  "off" \
        "spotify"     "Spotify [AUR]"                                     "off" \
        "elisa"       "Elisa (lokale Musikverwaltung, KDE-nativ)"         "off" \
        "gstreamer"   "GStreamer Codecs (good/bad/ugly)"                   "off" \
        "ffmpeg"      "ffmpeg (Multimedia-Framework)"                      "off" \
        "ytdlp"       "yt-dlp (YouTube/Video-Downloader)"                 "off" \
        "obs"         "OBS Studio (Screen Recording & Streaming)"          "off" \
        "gimp"        "GIMP (Bildbearbeitung)"                             "off" \
        "inkscape"    "Inkscape (Vektorgrafik)"                            "off" \
        "kdenlive"    "Kdenlive (Video-Schnitt, KDE-nativ)"               "off" \
        "darktable"   "Darktable (RAW-Foto-Entwicklung)"                  "off" \
        "nerdfonts"   "Nerd Fonts (JetBrains Mono, FiraCode, Hack)"       "off" \
        "msfonts"     "Microsoft Fonts (ttf-ms-fonts) [AUR]"              "off" \
    )

    [[ -z "${selected}" ]] && { skip "Keine Optionen gewählt"; return; }

    declare -A OPTS=()
    for opt in ${selected}; do OPTS[$opt]=1; done

    local installed_list=()
    local needs_fc_cache=false

    [[ -n "${OPTS[mpv]:-}" ]]       && { install_pkg mpv;                         installed_list+=("MPV"); }
    [[ -n "${OPTS[vlc]:-}" ]]       && { install_pkg vlc;                         installed_list+=("VLC"); }
    [[ -n "${OPTS[elisa]:-}" ]]     && { install_pkg elisa;                       installed_list+=("Elisa"); }
    [[ -n "${OPTS[ffmpeg]:-}" ]]    && { install_pkg ffmpeg;                      installed_list+=("ffmpeg"); }
    [[ -n "${OPTS[ytdlp]:-}" ]]     && { install_pkg yt-dlp;                      installed_list+=("yt-dlp"); }
    [[ -n "${OPTS[obs]:-}" ]]       && { install_pkg obs-studio;                  installed_list+=("OBS"); }
    [[ -n "${OPTS[gimp]:-}" ]]      && { install_pkg gimp;                        installed_list+=("GIMP"); }
    [[ -n "${OPTS[inkscape]:-}" ]]  && { install_pkg inkscape;                    installed_list+=("Inkscape"); }
    [[ -n "${OPTS[kdenlive]:-}" ]]  && { install_pkg kdenlive;                    installed_list+=("Kdenlive"); }
    [[ -n "${OPTS[darktable]:-}" ]] && { install_pkg darktable;                   installed_list+=("Darktable"); }

    if [[ -n "${OPTS[spotify]:-}" ]]; then
        install_aur spotify
        installed_list+=("Spotify")
    fi

    if [[ -n "${OPTS[gstreamer]:-}" ]]; then
        info "GStreamer Codecs werden installiert ..."
        install_pkg gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav
        installed_list+=("GStreamer-Codecs")
    fi

    if [[ -n "${OPTS[nerdfonts]:-}" ]]; then
        info "Nerd Fonts werden installiert ..."
        install_aur ttf-jetbrains-mono-nerd ttf-firacode-nerd ttf-hack-nerd
        needs_fc_cache=true
        installed_list+=("Nerd Fonts")
    fi

    if [[ -n "${OPTS[msfonts]:-}" ]]; then
        info "Microsoft Fonts werden installiert ..."
        install_aur ttf-ms-fonts
        needs_fc_cache=true
        installed_list+=("MS Fonts")
    fi

    if [[ "${needs_fc_cache}" == true ]]; then
        info "Font-Cache wird aktualisiert ..."
        fc-cache -fv &>/dev/null
        success "Font-Cache aktualisiert."
    fi

    local notes
    notes=$(IFS=", "; echo "${installed_list[*]}")
    MODULE_STATUS["05_media"]="success"
    MODULE_NOTES["05_media"]="${notes}"
}
