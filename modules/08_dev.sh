#!/usr/bin/env bash
# ── Modul 08: Entwicklungs-Tools ──────────────────────────────

run_module_main() {
    local selected
    selected=$(checklist \
        "Entwicklungs-Tools" \
        "Wähle Entwickler-Tools:" \
        "git_config"   "Git konfigurieren (Name + E-Mail)"               "off" \
        "ssh_key"      "SSH-Key generieren (ed25519)"                     "off" \
        "gh"           "GitHub CLI (gh)"                                   "off" \
        "docker"       "Docker + docker-compose"                           "off" \
        "podman"       "Podman (rootless Docker-Alternative)"              "off" \
        "kvm"          "QEMU/KVM + virt-manager (VMs)"                    "off" \
        "virtualbox"   "VirtualBox"                                         "off" \
        "nvm"          "NVM + Node.js LTS"                                 "off" \
        "bun"          "Bun (schneller JS-Runtime + Paketmanager)"         "off" \
        "pnpm"         "pnpm (schnellerer npm-Ersatz)"                     "off" \
        "yarn"         "Yarn"                                               "off" \
        "astro"        "Astro CLI"                                          "off" \
        "pyenv"        "pyenv (Python-Versionsmanager)"                    "off" \
        "poetry"       "Poetry (Python-Paketmanager)"                      "off" \
        "uv"           "uv (ultraschneller Python-Paketmanager)"           "off" \
        "rust"         "Rust (rustup + stable toolchain)"                  "off" \
        "go"           "Go"                                                 "off" \
        "deno"         "Deno (modernes JS/TS Runtime)"                     "off" \
        "php"          "PHP + Composer"                                     "off" \
        "ruby"         "Ruby + rbenv + Bundler"                            "off" \
        "java"         "Java (JDK OpenJDK)"                                "off" \
        "kotlin"       "Kotlin"                                             "off" \
        "lua"          "Lua"                                                "off" \
        "zig"          "Zig [AUR]"                                          "off" \
        "elixir"       "Erlang / Elixir"                                   "off" \
        "pipx"         "pipx (isolierte Python CLI-Tools)"                  "off" \
        "snap"         "Snap (snapd) [AUR]"                                "off" \
        "claude_code"  "Claude Code (npm install -g)"                      "off" \
        "gemini"       "Gemini CLI (npm install -g)"                       "off" \
        "vscode"       "VS Code [AUR]"                                      "off" \
        "vscodium"     "VS Codium (Open-Source, kein Telemetrie) [AUR]"   "off" \
        "neovim"       "Neovim"                                             "off" \
        "jetbrains"    "JetBrains Toolbox [AUR]"                           "off" \
        "insomnia"     "Insomnia / Bruno (REST-Client)"                    "off" \
        "dbeaver"      "DBeaver (Datenbank-Client)"                        "off" \
        "meld"         "meld (Diff/Merge-Tool)"                            "off" \
        "httpie"       "httpie (modernes curl im Terminal)"                "off" \
    )

    [[ -z "${selected}" ]] && { skip "Keine Optionen gewählt"; return; }

    declare -A OPTS=()
    for opt in ${selected}; do OPTS[$opt]=1; done

    local installed_list=()

    # ── Git konfigurieren ──────────────────────────────────────
    if [[ -n "${OPTS[git_config]:-}" ]]; then
        local git_name git_email
        git_name=$(inputbox "Git-Konfiguration" "Dein vollständiger Name für Git:" \
            "$(git config --global user.name 2>/dev/null || echo '')")
        git_email=$(inputbox "Git-Konfiguration" "Deine E-Mail-Adresse für Git:" \
            "$(git config --global user.email 2>/dev/null || echo '')")

        if [[ -n "${git_name}" && -n "${git_email}" ]]; then
            git config --global user.name "${git_name}"
            git config --global user.email "${git_email}"
            git config --global init.defaultBranch main
            success "Git konfiguriert: ${git_name} <${git_email}>"
            installed_list+=("Git-Config")
        else
            warn "Git-Konfiguration übersprungen (Name oder E-Mail leer)"
        fi
    fi

    # ── SSH-Key ────────────────────────────────────────────────
    if [[ -n "${OPTS[ssh_key]:-}" ]]; then
        local ssh_comment
        ssh_comment=$(inputbox "SSH-Key" "Kommentar für SSH-Key (z.B. deine E-Mail):" \
            "$(git config --global user.email 2>/dev/null || echo "${USER}@$(hostname)")")

        if [[ -n "${ssh_comment}" ]]; then
            local key_file="${HOME}/.ssh/id_ed25519"
            if [[ -f "${key_file}" ]]; then
                warn "SSH-Key existiert bereits: ${key_file}"
            else
                mkdir -p "${HOME}/.ssh"
                chmod 700 "${HOME}/.ssh"
                ssh-keygen -t ed25519 -C "${ssh_comment}" -f "${key_file}" -N ""
                success "SSH-Key generiert: ${key_file}.pub"
            fi
            local pubkey
            pubkey=$(cat "${key_file}.pub")
            msgbox "Dein SSH Public Key" "Kopiere diesen Key zu GitHub/GitLab:\n\n${pubkey}"
            installed_list+=("SSH-Key")
        fi
    fi

    # ── GitHub CLI ─────────────────────────────────────────────
    [[ -n "${OPTS[gh]:-}" ]] && { install_pkg github-cli; installed_list+=("GitHub CLI"); }

    # ── Docker ─────────────────────────────────────────────────
    if [[ -n "${OPTS[docker]:-}" ]]; then
        install_pkg docker docker-compose
        sudo systemctl enable --now docker
        sudo usermod -aG docker "${USER}"
        success "Docker installiert. ${USER} zur docker-Gruppe hinzugefügt."
        warn "Neustart erforderlich damit docker-Gruppe aktiv wird!"
        MODULE_STATUS["08_dev"]="warn"
        MODULE_NOTES["08_dev"]="Docker: Neustart erforderlich (docker-Gruppe)"
        installed_list+=("Docker")
    fi

    # ── Podman ─────────────────────────────────────────────────
    [[ -n "${OPTS[podman]:-}" ]] && { install_pkg podman podman-compose; installed_list+=("Podman"); }

    # ── QEMU/KVM ───────────────────────────────────────────────
    if [[ -n "${OPTS[kvm]:-}" ]]; then
        install_pkg qemu-full virt-manager virt-viewer libvirt dnsmasq
        sudo systemctl enable --now libvirtd
        sudo usermod -aG libvirt "${USER}"
        success "QEMU/KVM + virt-manager installiert."
        installed_list+=("QEMU/KVM")
    fi

    # ── VirtualBox ─────────────────────────────────────────────
    if [[ -n "${OPTS[virtualbox]:-}" ]]; then
        install_pkg virtualbox virtualbox-host-modules-arch
        sudo usermod -aG vboxusers "${USER}"
        installed_list+=("VirtualBox")
    fi

    # ── NVM + Node.js ──────────────────────────────────────────
    if [[ -n "${OPTS[nvm]:-}" ]]; then
        if [[ -d "${HOME}/.nvm" ]]; then
            skip "NVM bereits installiert"
        else
            info "NVM wird installiert ..."
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
            export NVM_DIR="${HOME}/.nvm"
            # shellcheck disable=SC1091
            [[ -s "${NVM_DIR}/nvm.sh" ]] && source "${NVM_DIR}/nvm.sh"
            nvm install --lts
            nvm use --lts
            success "NVM + Node.js LTS installiert."
        fi
        installed_list+=("NVM/Node")
    fi

    # ── Bun ────────────────────────────────────────────────────
    if [[ -n "${OPTS[bun]:-}" ]]; then
        if command -v bun &>/dev/null; then
            skip "Bun bereits installiert"
        else
            info "Bun wird installiert ..."
            curl -fsSL https://bun.sh/install | bash
            success "Bun installiert."
        fi
        installed_list+=("Bun")
    fi

    # ── npm-basierte Tools ─────────────────────────────────────
    _npm_install() {
        local pkg="$1"
        if command -v npm &>/dev/null; then
            npm install -g "${pkg}"
        elif command -v bun &>/dev/null; then
            bun install -g "${pkg}"
        else
            warn "Kein npm/bun gefunden — ${pkg} nicht installiert"
            return 1
        fi
    }

    [[ -n "${OPTS[pnpm]:-}" ]]  && { _npm_install pnpm;  installed_list+=("pnpm"); }
    [[ -n "${OPTS[yarn]:-}" ]]  && { _npm_install yarn;  installed_list+=("Yarn"); }
    [[ -n "${OPTS[astro]:-}" ]] && { _npm_install astro; installed_list+=("Astro"); }

    # ── Python-Tools ───────────────────────────────────────────
    if [[ -n "${OPTS[pyenv]:-}" ]]; then
        if command -v pyenv &>/dev/null; then
            skip "pyenv bereits installiert"
        else
            info "pyenv wird installiert ..."
            curl https://pyenv.run | bash
            success "pyenv installiert."
        fi
        installed_list+=("pyenv")
    fi

    if [[ -n "${OPTS[poetry]:-}" ]]; then
        if command -v poetry &>/dev/null; then
            skip "Poetry bereits installiert"
        else
            info "Poetry wird installiert ..."
            curl -sSL https://install.python-poetry.org | python3 -
            success "Poetry installiert."
        fi
        installed_list+=("Poetry")
    fi

    if [[ -n "${OPTS[uv]:-}" ]]; then
        if command -v uv &>/dev/null; then
            skip "uv bereits installiert"
        else
            info "uv wird installiert ..."
            curl -LsSf https://astral.sh/uv/install.sh | sh
            success "uv installiert."
        fi
        installed_list+=("uv")
    fi

    [[ -n "${OPTS[pipx]:-}" ]] && { install_pkg python-pipx; installed_list+=("pipx"); }

    # ── Rust ───────────────────────────────────────────────────
    if [[ -n "${OPTS[rust]:-}" ]]; then
        if command -v rustup &>/dev/null; then
            skip "Rust bereits installiert"
        else
            info "Rust (rustup) wird installiert ..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            success "Rust installiert."
        fi
        installed_list+=("Rust")
    fi

    # ── Weitere Sprachen ───────────────────────────────────────
    [[ -n "${OPTS[go]:-}" ]]    && { install_pkg go;                    installed_list+=("Go"); }
    [[ -n "${OPTS[lua]:-}" ]]   && { install_pkg lua;                   installed_list+=("Lua"); }
    [[ -n "${OPTS[java]:-}" ]]  && { install_pkg jdk-openjdk;           installed_list+=("Java"); }
    [[ -n "${OPTS[kotlin]:-}" ]]&& { install_pkg kotlin;                installed_list+=("Kotlin"); }
    [[ -n "${OPTS[elixir]:-}" ]]&& { install_pkg elixir;                installed_list+=("Elixir"); }
    [[ -n "${OPTS[zig]:-}" ]]   && { install_aur zig;                   installed_list+=("Zig"); }

    if [[ -n "${OPTS[deno]:-}" ]]; then
        if command -v deno &>/dev/null; then
            skip "Deno bereits installiert"
        else
            info "Deno wird installiert ..."
            curl -fsSL https://deno.land/install.sh | sh
            success "Deno installiert."
        fi
        installed_list+=("Deno")
    fi

    if [[ -n "${OPTS[php]:-}" ]]; then
        install_pkg php
        if ! command -v composer &>/dev/null; then
            info "Composer wird installiert ..."
            curl -sS https://getcomposer.org/installer | php
            sudo mv composer.phar /usr/local/bin/composer
        fi
        installed_list+=("PHP+Composer")
    fi

    if [[ -n "${OPTS[ruby]:-}" ]]; then
        install_pkg ruby
        if ! command -v rbenv &>/dev/null; then
            install_aur rbenv ruby-build
        fi
        gem install bundler 2>/dev/null || true
        installed_list+=("Ruby+rbenv")
    fi

    # ── Snap ───────────────────────────────────────────────────
    if [[ -n "${OPTS[snap]:-}" ]]; then
        install_aur snapd
        sudo systemctl enable --now snapd.socket
        installed_list+=("Snap")
    fi

    # ── AI-Tools ───────────────────────────────────────────────
    if [[ -n "${OPTS[claude_code]:-}" ]]; then
        info "Claude Code wird installiert ..."
        _npm_install @anthropic-ai/claude-code
        installed_list+=("Claude Code")
    fi

    if [[ -n "${OPTS[gemini]:-}" ]]; then
        info "Gemini CLI wird installiert ..."
        _npm_install @google/gemini-cli
        installed_list+=("Gemini CLI")
    fi

    # Genesis CLI — immer installiert
    info "Genesis CLI wird installiert ..."
    curl -fsSL https://raw.githubusercontent.com/Raindancer118/genesis/main/install.sh | bash
    success "Genesis CLI installiert."
    installed_list+=("Genesis CLI")

    # ── Editoren ───────────────────────────────────────────────
    [[ -n "${OPTS[neovim]:-}" ]]   && { install_pkg neovim;                        installed_list+=("Neovim"); }
    [[ -n "${OPTS[meld]:-}" ]]     && { install_pkg meld;                          installed_list+=("meld"); }
    [[ -n "${OPTS[httpie]:-}" ]]   && { install_pkg httpie;                        installed_list+=("httpie"); }
    [[ -n "${OPTS[dbeaver]:-}" ]]  && { install_aur dbeaver;                       installed_list+=("DBeaver"); }
    [[ -n "${OPTS[vscode]:-}" ]]   && { install_aur visual-studio-code-bin;        installed_list+=("VS Code"); }
    [[ -n "${OPTS[vscodium]:-}" ]] && { install_aur vscodium-bin;                  installed_list+=("VSCodium"); }
    [[ -n "${OPTS[jetbrains]:-}" ]]&& { install_aur jetbrains-toolbox;             installed_list+=("JetBrains Toolbox"); }

    if [[ -n "${OPTS[insomnia]:-}" ]]; then
        if yesno "REST-Client" "Welchen REST-Client installieren?\n\nJa = Insomnia\nNein = Bruno"; then
            install_aur insomnia-bin
            installed_list+=("Insomnia")
        else
            install_aur bruno-bin
            installed_list+=("Bruno")
        fi
    fi

    local notes
    notes=$(IFS=", "; echo "${installed_list[*]}")
    MODULE_STATUS["08_dev"]="${MODULE_STATUS["08_dev"]:-success}"
    MODULE_NOTES["08_dev"]="${MODULE_NOTES["08_dev"]:-${notes}}"
}
