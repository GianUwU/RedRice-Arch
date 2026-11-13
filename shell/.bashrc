#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

eval "$(zoxide init bash)"


mv() {
    # If first argument is -p, enable auto-create
    if [[ "$1" == "-p" ]]; then
        shift  # remove -p
        local target="${@: -1}"  # last argument

        # Create the target directory if it doesn't exist
        [[ ! -d "$target" ]] && mkdir -p "$target"
    fi

    # Run the original mv with all arguments
    command mv "$@"
}
export PATH="/home/gian/.config/herd-lite/bin:$PATH"
export PHP_INI_SCAN_DIR="/home/gian/.config/herd-lite/bin:$PHP_INI_SCAN_DIR"


# Added by Antigravity CLI installer
export PATH="/home/gian/.local/bin:$PATH"

# Kitty SSH integration: automatically copies terminfo to remote hosts
if [[ "$TERM" == "xterm-kitty" ]]; then
    alias ssh="kitten ssh"
fi

# RedRice-Arch quick sync helper
redrice-sync() {
    local msg="${1:-Rice update $(date '+%Y-%m-%d %H:%M')}"
    (cd "$HOME/RedRice-Arch" && git add -A && git commit -m "$msg" && git push)
}

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
