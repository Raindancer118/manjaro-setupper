#!/usr/bin/env bash
# ── Modul 02: Shell & Terminal-Tools ─────────────────────────

run_module_main() {
    local selected
    selected=$(checklist \
        "Shell & Terminal-Tools" \
        "Wähle die Shell-Tools:" \
        "zsh"          "Zsh installieren + als Default setzen (chsh)"       "on"  \
        "starship"     "Starship Prompt installieren"                        "on"  \
        "zsh_plugins"  "zsh-autosuggestions + zsh-syntax-highlighting"       "on"  \
        "ohmyzsh"      "Oh-My-Zsh (alternativ zu Starship)"                 "off" \
        "fish"         "Fish shell installieren"                              "off" \
        "zshrc"        ".zshrc mit Aliases schreiben (ll, la, update, ...)"  "off" \
        "zellij"       "Zellij (moderner Terminal-Multiplexer)"               "off" \
        "tmux"         "tmux (klassischer Multiplexer)"                       "off" \
        "fzf"          "fzf (fuzzy finder, shell-integration)"                "off" \
        "bat"          "bat (besseres cat mit Syntax-Highlighting)"            "off" \
        "eza"          "eza (besseres ls mit Icons)"                           "off" \
        "fd"           "fd (schnelleres find)"                                 "off" \
        "ripgrep"      "ripgrep (schnelleres grep)"                            "off" \
        "btop"         "btop (schönes Ressource-Monitor)"                      "off" \
        "fastfetch"    "fastfetch (System-Info beim Shell-Start)"              "off" \
        "thefuck"      "thefuck (Autokorrekt für falsche Befehle)"             "off" \
        "zoxide"       "zoxide (smartes cd mit Lernfunktion)"                  "off" \
    )

    [[ -z "${selected}" ]] && { skip "Keine Optionen gewählt"; return; }

    declare -A OPTS=()
    for opt in ${selected}; do OPTS[$opt]=1; done

    local installed_list=()

    # ── Zsh ────────────────────────────────────────────────────
    if [[ -n "${OPTS[zsh]:-}" ]]; then
        install_pkg zsh
        if [[ "${SHELL}" != "$(which zsh)" ]]; then
            info "Zsh wird als Standard-Shell gesetzt ..."
            chsh -s "$(which zsh)"
            warn "Shell-Wechsel wirkt nach dem nächsten Login."
            MODULE_STATUS["02_shell"]="warn"
            MODULE_NOTES["02_shell"]="Zsh: Neuanmeldung erforderlich"
        else
            skip "Zsh bereits Standard-Shell"
        fi
        installed_list+=("Zsh")
    fi

    # ── Starship ───────────────────────────────────────────────
    if [[ -n "${OPTS[starship]:-}" ]]; then
        if command -v starship &>/dev/null; then
            skip "Starship bereits installiert"
        else
            info "Starship Prompt wird installiert ..."
            curl -sS https://starship.rs/install.sh | sh -s -- --yes
            success "Starship installiert."
        fi
        installed_list+=("Starship")
    fi

    # ── Zsh-Plugins ────────────────────────────────────────────
    if [[ -n "${OPTS[zsh_plugins]:-}" ]]; then
        info "Zsh-Plugins werden installiert ..."
        if command -v yay &>/dev/null; then
            yay -S --noconfirm --needed zsh-autosuggestions zsh-syntax-highlighting
        else
            install_pkg zsh-autosuggestions zsh-syntax-highlighting
        fi
        installed_list+=("zsh-autosuggestions" "zsh-syntax-highlighting")
    fi

    # ── Oh-My-Zsh ──────────────────────────────────────────────
    if [[ -n "${OPTS[ohmyzsh]:-}" ]]; then
        if [[ -d "${HOME}/.oh-my-zsh" ]]; then
            skip "Oh-My-Zsh bereits installiert"
        else
            info "Oh-My-Zsh wird installiert ..."
            RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
            success "Oh-My-Zsh installiert."
        fi
        installed_list+=("Oh-My-Zsh")
    fi

    # ── Fish ───────────────────────────────────────────────────
    if [[ -n "${OPTS[fish]:-}" ]]; then
        install_pkg fish
        installed_list+=("Fish")
    fi

    # ── Einzelne Tools ─────────────────────────────────────────
    [[ -n "${OPTS[zellij]:-}" ]]   && { install_pkg zellij;   installed_list+=("Zellij"); }
    [[ -n "${OPTS[tmux]:-}" ]]     && { install_pkg tmux;     installed_list+=("tmux"); }
    [[ -n "${OPTS[fzf]:-}" ]]      && { install_pkg fzf;      installed_list+=("fzf"); }
    [[ -n "${OPTS[bat]:-}" ]]      && { install_pkg bat;      installed_list+=("bat"); }
    [[ -n "${OPTS[eza]:-}" ]]      && { install_pkg eza;      installed_list+=("eza"); }
    [[ -n "${OPTS[fd]:-}" ]]       && { install_pkg fd;       installed_list+=("fd"); }
    [[ -n "${OPTS[ripgrep]:-}" ]]  && { install_pkg ripgrep;  installed_list+=("ripgrep"); }
    [[ -n "${OPTS[btop]:-}" ]]     && { install_pkg btop;     installed_list+=("btop"); }
    [[ -n "${OPTS[fastfetch]:-}" ]]&& { install_pkg fastfetch;installed_list+=("fastfetch"); }
    [[ -n "${OPTS[thefuck]:-}" ]]  && { install_pkg thefuck;  installed_list+=("thefuck"); }
    [[ -n "${OPTS[zoxide]:-}" ]]   && { install_pkg zoxide;   installed_list+=("zoxide"); }

    # ── .zshrc schreiben ───────────────────────────────────────
    if [[ -n "${OPTS[zshrc]:-}" ]]; then
        local zshrc="${HOME}/.zshrc"
        local write_it=true

        if [[ -f "${zshrc}" ]]; then
            if ! yesno ".zshrc überschreiben?" "Eine ~/.zshrc existiert bereits.\nSoll sie überschrieben werden?\n(Backup wird angelegt: ~/.zshrc.bak)"; then
                write_it=false
                skip ".zshrc unverändert gelassen"
            else
                cp "${zshrc}" "${zshrc}.bak"
                info "Backup angelegt: ~/.zshrc.bak"
            fi
        fi

        if [[ "${write_it}" == true ]]; then
            cat > "${zshrc}" <<'ZSHRC'
# ── Zsh Konfiguration (Manjaro Setup) ───────────────────────

# Zsh-Plugins
[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Starship Prompt
command -v starship &>/dev/null && eval "$(starship init zsh)"

# fzf integration
command -v fzf &>/dev/null && source <(fzf --zsh) 2>/dev/null || true

# zoxide
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# fastfetch beim Start
command -v fastfetch &>/dev/null && fastfetch

# ── Aliases ──────────────────────────────────────────────────
alias ll='ls -lah'
alias la='ls -A'
alias cls='clear'
alias gs='git status'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias update='sudo pacman -Syu && command -v yay &>/dev/null && yay -Syu --aur'

# eza-Aliases (falls installiert)
if command -v eza &>/dev/null; then
    alias ls='eza --icons'
    alias ll='eza -lah --icons --git'
    alias la='eza -a --icons'
    alias lt='eza --tree --icons'
fi

# bat alias (falls installiert)
command -v bat &>/dev/null && alias cat='bat'

# thefuck
command -v thefuck &>/dev/null && eval "$(thefuck --alias)"
ZSHRC
            success ".zshrc geschrieben."
            installed_list+=(".zshrc")
        fi
    fi

    local notes
    notes=$(IFS=", "; echo "${installed_list[*]}")
    MODULE_STATUS["02_shell"]="${MODULE_STATUS["02_shell"]:-success}"
    MODULE_NOTES["02_shell"]="${MODULE_NOTES["02_shell"]:-${notes}}"
}
