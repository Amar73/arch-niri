# =============================================================================
# ~/.bashrc — Конфигурация интерактивной оболочки Bash
# =============================================================================
#
# ПОРЯДОК ЗАГРУЗКИ ФАЙЛОВ BASH:
#   Логин-оболочка (ssh, su -):  ~/.bash_profile → ~/.bashrc (если вызван из profile)
#   Интерактивная оболочка:      ~/.bashrc
#   Неинтерактивная (скрипты):   ничего из этих файлов
#
# =============================================================================


# =============================================================================
# ЗАЩИТА ОТ НЕИНТЕРАКТИВНОЙ ОБОЛОЧКИ
# =============================================================================

[[ $- != *i* ]] && return


# =============================================================================
# ИСТОРИЯ КОМАНД
# =============================================================================

HISTCONTROL=ignoreboth:erasedups
HISTSIZE=10000
HISTFILESIZE=20000
HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "
PROMPT_COMMAND='history -a'


# =============================================================================
# РАСШИРЕНИЯ BASH (shopt)
# =============================================================================

shopt -s histappend
shopt -s checkwinsize
shopt -s cdspell
shopt -s dirspell
shopt -s autocd


# =============================================================================
# ФУНКЦИИ
# =============================================================================

# --- Создание директории и немедленный переход в неё ---
mkcd() {
    mkdir -p "$1" && cd "$1" || return
}

# --- Универсальное извлечение архивов ---
extract() {
    if [ -f "$1" ]; then
        case $1 in
            *.tar.bz2)   tar xvjf "$1"     ;;
            *.tar.gz)    tar xvzf "$1"     ;;
            *.bz2)       bunzip2 "$1"      ;;
            *.rar)       unrar x "$1"      ;;
            *.gz)        gunzip "$1"       ;;
            *.tar)       tar xvf "$1"      ;;
            *.tbz2)      tar xvjf "$1"     ;;
            *.tgz)       tar xvzf "$1"     ;;
            *.zip)       unzip "$1"        ;;
            *.Z)         uncompress "$1"   ;;
            *.7z)        7z x "$1"         ;;
            *.xz)        unxz "$1"         ;;
            *.exe)       cabextract "$1"   ;;
            *)           echo "extract: '$1' - unknown format" ;;
        esac
    else
        echo "extract: '$1' - file not found"
    fi
}

# --- Поиск по истории команд ---
hgrep() { history | grep "$@"; }

# --- Быстрый поиск файлов по имени ---
ff() { find . -name "*$1*" 2>/dev/null; }

# --- Поиск процессов ---
psg() {
    ps aux | grep -v grep | grep -i -e VSZ -e "$@"
}


# =============================================================================
# АЛИАСЫ НАВИГАЦИИ
# =============================================================================

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ~='cd ~'
alias -- -='cd -'


# =============================================================================
# ЦВЕТНОЙ LS (через eza, если установлен)
# =============================================================================

if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -l --icons --group-directories-first --header'
    alias la='eza -la --icons --group-directories-first --header'
    alias lt='eza --tree --level=2 --icons'
    alias lta='eza --tree --level=2 --icons -a'
else
    alias ls='ls --color=auto --group-directories-first'
    alias ll='ls -lh --color=auto --group-directories-first'
    alias la='ls -lah --color=auto --group-directories-first'
fi


# =============================================================================
# БЕЗОПАСНЫЕ ВЕРСИИ ДЕСТРУКТИВНЫХ КОМАНД
# =============================================================================

alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -I'


# =============================================================================
# МОНИТОРИНГ СИСТЕМЫ
# =============================================================================

alias df='df -h'
alias du='du -ch'
alias free='free -h'
alias psa='ps auxf'
alias myip='curl -s ifconfig.me'
alias ports='ss -tulanp'


# =============================================================================
# GIT-АЛИАСЫ И ФУНКЦИИ
# =============================================================================

alias gs='git status'
alias ga='git add -A'
alias gc='git commit -m'

# ИСПРАВЛЕНО v6.3: были алиасы с $() — вычислялись при source .bashrc,
# а не при вызове команды. Переведены в функции: ветка читается в runtime.
gp()  { git push origin "$(git symbolic-ref --short HEAD)"; }
gpf() { git push --force-with-lease -u origin "$(git symbolic-ref --short HEAD)"; }
gl()  { git pull origin "$(git symbolic-ref --short HEAD)"; }

alias gf='git fetch origin'
alias glo='git log --oneline --graph --decorate'
alias glog='git log --graph --pretty=format:"%Cred%h%Creset - %Cgreen(%cr)%Creset %s%C(yellow)%d%Creset %C(bold blue)<%an>%Creset" --abbrev-commit'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gm='git merge'
alias gr='git reset'
alias grh='git reset --hard'


# =============================================================================
# БЫСТРАЯ НАВИГАЦИЯ ПО ПРОЕКТАМ
# =============================================================================

alias cdconf='cd ~/.config'
alias cddown='cd ~/Downloads'
alias cddoc='cd ~/Documents'
alias cdproj='cd ~/Amar73'
alias cdniri='cd ~/.config/niri'
alias cdwaybar='cd ~/.config/waybar'
alias cdsetup='cd ~/Amar73/setup'
alias cdrclone='cd ~/Amar73/rclone'


# =============================================================================
# ПАКЕТНЫЕ МЕНЕДЖЕРЫ
# =============================================================================

if command -v pacman >/dev/null 2>&1; then
    alias search='pacman -Ss'
    alias install='sudo pacman -S'
    alias update='sudo pacman -Syu'
    alias remove='sudo pacman -R'

    # ИСПРАВЛЕНО: вынесено в функцию + shellcheck disable для намеренного
    # word splitting (имена пакетов Arch не содержат пробелов — это безопасно)
    autoremove() {
        local orphans
        orphans=$(pacman -Qtdq 2>/dev/null)
        if [[ -n "$orphans" ]]; then
            # shellcheck disable=SC2086  # intentional word splitting on package names
            sudo pacman -Rns $orphans
        else
            echo "No orphan packages"
        fi
    }

    alias installed='pacman -Q'

    # yay — AUR-хелпер
    if command -v yay >/dev/null 2>&1; then
        alias yaysearch='yay -Ss'
        alias yayinstall='yay -S'
        alias yayupdate='yay -Syu'
        alias yayshow='yay -Qi'
        alias yayremove='yay -Rns'
        alias aurorphans='yay -Yc'
    fi

elif command -v nixos-rebuild >/dev/null 2>&1; then
    alias rebuild='sudo nixos-rebuild switch'
    alias rebuild-test='sudo nixos-rebuild test'
    alias upgrade='sudo nixos-rebuild switch --upgrade'
    alias search='nix-env -qaP'
    alias nix-search='nix search'

elif command -v nix-env >/dev/null 2>&1; then
    alias nix-search='nix-env -qaP'
    alias nix-install='nix-env -i'
    alias nix-remove='nix-env -e'
    alias nix-upgrade='nix-env -u'
fi


# =============================================================================
# РЕДАКТОРЫ
# =============================================================================

alias v='vim'
alias sv='sudo vim'
alias e='$EDITOR'
alias se='sudo $EDITOR'


# =============================================================================
# РАСШИРЕНИЕ PATH
# =============================================================================

add_to_path() {
    if [[ -d "$1" && ":$PATH:" != *":$1:"* ]]; then
        PATH="$1:$PATH"
    fi
}

add_to_path "$HOME/bin"
add_to_path "$HOME/.local/bin"
add_to_path "/usr/local/bin"
add_to_path "/usr/local/go/bin"

if [[ -d "/usr/lib/flutter" ]]; then
    add_to_path "/usr/lib/flutter/bin"
    export CHROME_EXECUTABLE=/usr/bin/chromium
fi

if [[ -d "$HOME/Android/Sdk" ]]; then
    export ANDROID_HOME="$HOME/Android/Sdk"
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
    add_to_path "$ANDROID_HOME/cmdline-tools/latest/bin"
    add_to_path "$ANDROID_HOME/platform-tools"
fi


# =============================================================================
# ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ
# =============================================================================

export VISUAL=vim
export EDITOR=vim
export PAGER=less
export BROWSER=firefox


# =============================================================================
# ЦВЕТОВЫЕ ПЕРЕМЕННЫЕ
# =============================================================================

COLOR_GREEN=$'\033[0;32m'
COLOR_RED=$'\033[0;31m'
COLOR_YELLOW=$'\033[1;33m'
COLOR_RESET=$'\033[0m'

PS_CYAN='\[\033[0;36m\]'
PS_BLUE='\[\033[0;34m\]'
PS_YELLOW='\[\033[1;33m\]'
PS_PURPLE='\[\033[0;35m\]'
PS_RED='\[\033[0;31m\]'
PS_RESET='\[\033[0m\]'


# =============================================================================
# GIT-СТАТУС ДЛЯ ПРИГЛАШЕНИЯ (PS1)
# =============================================================================

# ИСПРАВЛЕНО: внутри функций вызываемых из PS1 через $() нужно использовать
# \001 и \002 вместо \[ и \] — иначе bash неправильно считает длину строки
# и курсор съезжает при навигации по истории (команды наплывают друг на друга).

git_status() {
    local branch
    local RL=$'\001'        # начало непечатаемой последовательности
    local RR=$'\002'        # конец непечатаемой последовательности
    local YELLOW=$'\033[1;33m'
    local GREEN=$'\033[0;32m'
    local RESET=$'\033[0m'
    if branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null); then
        local changes
        changes=$(git status --porcelain 2>/dev/null)
        if [[ -n $changes ]]; then
            echo -n " ${RL}${YELLOW}${RR}(${branch}*)${RL}${RESET}${RR}"
        else
            echo -n " ${RL}${GREEN}${RR}(${branch})${RL}${RESET}${RR}"
        fi
    fi
}

last_command_status() {
    local status=$?
    local RL=$'\001'
    local RR=$'\002'
    local GREEN=$'\033[0;32m'
    local RED=$'\033[0;31m'
    local RESET=$'\033[0m'
    if [[ $status -eq 0 ]]; then
        echo -n "${RL}${GREEN}${RR}✓${RL}${RESET}${RR}"
    else
        echo -n "${RL}${RED}${RR}✗${status}${RL}${RESET}${RR}"
    fi
}


# =============================================================================
# ПРИГЛАШЕНИЕ КОМАНДНОЙ СТРОКИ (PS1)
# =============================================================================

# Формат: HH:MM:SS user@host:~/path (branch*)
#         ✓ $
PS1="${PS_CYAN}\t${PS_RESET} ${PS_PURPLE}\u${PS_RESET}@${PS_PURPLE}\h${PS_RESET}:${PS_BLUE}\w${PS_RESET}\$(git_status)\n\$(last_command_status) ${PS_YELLOW}\\\$${PS_RESET} "


# =============================================================================
# SSH AGENT
# =============================================================================

if command -v keychain >/dev/null 2>&1; then
    keys=()
    [[ -f ~/.ssh/id_ed25519 ]] && keys+=(~/.ssh/id_ed25519)
    [[ -f ~/.ssh/id_rsa     ]] && keys+=(~/.ssh/id_rsa)

    if [[ ${#keys[@]} -gt 0 ]]; then
        # --quiet — не выводить приветствие
        # Парольная фраза запрашивается один раз за сессию
        eval "$(keychain --quiet "${keys[@]}")"
    else
        eval "$(keychain --quiet)"
    fi
else
    _SSH_ENV="$HOME/.ssh/agent.env"

    _start_agent() {
        ssh-agent > "$_SSH_ENV"
        chmod 600 "$_SSH_ENV"
        source "$_SSH_ENV" >/dev/null
        for key in ~/.ssh/id_rsa ~/.ssh/id_ed25519; do
            [[ -f "$key" ]] && ssh-add "$key" >/dev/null 2>&1
        done
    }

    if [[ -f "$_SSH_ENV" ]]; then
        source "$_SSH_ENV" >/dev/null
        if ! kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
            _start_agent
        fi
    else
        _start_agent
    fi
fi


# =============================================================================
# SSH АЛИАСЫ
# =============================================================================

alias a03='ssh arch03'
alias a04='ssh arch04'
alias a05='ssh arch05'
alias m01='ssh archminio01'
alias m02='ssh archminio02'


# =============================================================================
# ФУНКЦИИ ПЕРЕДАЧИ ФАЙЛОВ ПО SSH
# =============================================================================

download_from_server() {
    if [[ $# -ne 3 ]]; then
        echo "Usage: download_from_server <host> <remote_path> <local_path>"
        return 1
    fi
    scp "$1:$2" "$3" \
        && echo "[OK] Downloaded: $3" \
        || echo "[ERR] Download failed"
}

upload_to_server() {
    if [[ $# -ne 3 ]]; then
        echo "Usage: upload_to_server <host> <local_path> <remote_path>"
        return 1
    fi
    if [[ ! -f "$2" ]]; then
        echo "[ERR] Local file '$2' not found"
        return 1
    fi
    scp "$2" "$1:$3" \
        && echo "[OK] Uploaded to $1:$3" \
        || echo "[ERR] Upload failed"
}

alias scpget='download_from_server'
alias scpput='upload_to_server'
alias scpto='download_from_server'
alias putto='upload_to_server'


# =============================================================================
# GIT — РАБОТА С ПРОЕКТАМИ
# =============================================================================

gitinit() {
    local repo_name="${1:-$(basename "$PWD")}"
    git init
    echo "# $repo_name" > README.md
    printf '.DS_Store\n*.log\n*.tmp\n*~\n.env\n__pycache__/\n' > .gitignore
    git add .
    git commit -m "Initial commit"
    echo "[OK] Git repo '$repo_name' initialized"
}

project() {
    if [[ -z "$1" ]]; then
        ls ~/Amar73/ 2>/dev/null || echo "~/Amar73/ not found - create it: mkdir ~/Amar73"
        return
    fi
    local p="$HOME/Amar73/$1"
    if [[ -d "$p" ]]; then
        cd "$p" || return 1
        echo ">> Project: $1"
        [[ -f README.md ]] && head -5 README.md
    else
        echo "[ERR] Project '$1' not found in ~/Amar73/"
        echo "  Available projects:"
        ls ~/Amar73/ 2>/dev/null | sed 's/^/    /'
        return 1
    fi
}


# =============================================================================
# ДОПОЛНИТЕЛЬНЫЕ КОНФИГИ
# =============================================================================

[[ -f ~/.bashrc.local ]] && source ~/.bashrc.local
[[ -f ~/.bashrc.$(hostname) ]] && source ~/.bashrc.$(hostname)


# =============================================================================
# ИНФОРМАЦИЯ О СИСТЕМЕ ПРИ ВХОДЕ
# =============================================================================

if [[ "${SHOW_SYSTEM_INFO:-false}" == "true" ]]; then
    echo -e "${COLOR_GREEN}=== System Info ===${COLOR_RESET}"
    echo -e "${COLOR_GREEN}System:${COLOR_RESET}  $(uname -sr)"
    echo -e "${COLOR_GREEN}Uptime:${COLOR_RESET}  $(uptime -p 2>/dev/null || uptime)"
    echo -e "${COLOR_GREEN}Load:${COLOR_RESET}    $(cut -d' ' -f1-3 < /proc/loadavg)"
    echo -e "${COLOR_GREEN}Memory:${COLOR_RESET}  $(free -h | awk '/Mem:/ {print $3"/"$2}')"
    echo
fi


# =============================================================================
# SYSTEMD УТИЛИТЫ
# =============================================================================

if command -v systemctl >/dev/null 2>&1; then
    alias sc='systemctl'
    alias scu='systemctl --user'
    alias scr='sudo systemctl reload'
    alias scs='systemctl status'
    alias scus='systemctl --user status'

    logs() {
        if [[ -z "$1" ]]; then
            echo "Usage: logs <service> [user|u]"
            return 1
        fi
        if [[ "$2" == "user" || "$2" == "u" ]]; then
            journalctl --user -xeu "$1"
        else
            sudo journalctl -xeu "$1"
        fi
    }

fi


# =============================================================================
# ОТЛАДКА
# =============================================================================

[[ "${BASH_DEBUG:-false}" == "true" ]] && echo "[OK] .bashrc loaded"


# =============================================================================
# ПЕРЕЗАГРУЗКА BASHRC
# =============================================================================

reload() {
    echo "Reloading .bashrc..."
    unset -f git_status last_command_status reload mkcd extract hgrep ff psg \
             autoremove download_from_server upload_to_server gitinit project \
             logs add_to_path gp gpf gl 2>/dev/null
    source ~/.bashrc && echo "[OK] .bashrc reloaded"
}
