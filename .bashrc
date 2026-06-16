# ~/.bashrc: executed by bash(1) for non-login shells.
# See /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

### Inital Settings ############################################################
# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Check if tmux has been started. If not, then set the path
if [ -z "$TMUX" ]; then
    export PATH="\
/opt/nvim-linux64/bin:\
/home/vivtrain/.local/bin/:\
/usr/local/cuda/bin/:\
$PATH"
fi

# CD shortcuts go here
export CDPATH='.:~/.local/shortcuts'

# Neovim as default editor
EDITOR=nvim

# POSIX shell opts
set -o vi         # Vi-like line editing on the command line
set -o physical   # Use physical directories for cd instead of symbolic links
set -o noclobber  # Disable overwriting of files via redirection

# Welcome message
welcome() {
  source ~/.local/scripts/welcome.sh
  if [ -n "$VIRTUAL_ENV" ]; then
    unldvenv
  fi
}

# History
HISTCONTROL=ignoreboth      # no duplicate lines or lines starting with space
shopt -s histappend         # append to the history file instead of overwriting
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s checkwinsize       # update window size

# # The Prompt # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
  debian_chroot=$(cat /etc/debian_chroot)
fi

# Set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
  xterm-color|*-256color) color_prompt=yes;;
esac

### Colors #####################################################################
export COLORTERM=truecolor
force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
  if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    # We have color support; assume it's compliant with Ecma-48
    # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
    # a case would tend to support setf rather than setaf.)
    color_prompt=yes
  else
    color_prompt=
  fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi

# Set color capabilities of man
if [ "$color_prompt" = yes ]; then
  export MANPAGER="less -R --use-color -DSkY -DEwr"
fi

unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --group-directories-first --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# allow less to read color ANSI codes by default
export LESS=R

### Other Sources ##############################################################
# Alias definitions.
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

if [ -f ~/.inputrc ]; then
    bind -f ~/.inputrc
fi

# Miscellaneous preferences.
if [ -f ~/.bash_preferences ]; then
    . ~/.bash_preferences
fi

### Miscellaneous ##############################################################

# Enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Add an "alert" alias for long running commands.
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Start an ssh agent by default
if [ -z "$SSH_AUTH_SOCK" ]; then
  eval `ssh-agent -s` > /dev/null
fi

# Use oh-my-posh if available
if command -v oh-my-posh &> /dev/null; then
  eval "$(oh-my-posh init bash --config ~/.think.omp.json)"
fi

# Load nvm startup scripts manually
loadnvm() {
  unset -f nvm node npm
  export NVM_DIR=~/.nvm
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm
  nvm use default
}

# pnpm
export PNPM_HOME="/home/vivtrain/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# php development paths
export PATH="/home/vivtrain/.config/herd-lite/bin:$PATH"
export PHP_INI_SCAN_DIR="/home/vivtrain/.config/herd-lite/bin:$PHP_INI_SCAN_DIR"

# Start tmux by default if available
if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then
  # anything that needs to happen once on tmux startup
  loadnvm > /dev/null
  tmux new-session -A -s tmux
elif command -v tmux &> /dev/null && [ -z `tmux show-environment WELCOMED 2> /dev/null` ]; then
  welcome
  tmux set-environment WELCOMED 1
fi

# Make python venv
function mkvenv {
  dir='venv'
  if [ -n "$1" ]; then
    dir=$1
  fi
  python -m venv venv
}
# Load Python venv (and save into tmux session)
function ldvenv {
  if [ -n "$1" ]; then
    dir=$1
  elif [ -d venv ]; then
    dir='venv'
  elif [ -d .venv ]; then
    dir='.venv'
  fi
  source "$dir/bin/activate"
  if [ -n "$TMUX" ]; then
    tmux set-environment VIRTUAL_ENV "$VIRTUAL_ENV"
  fi
}
# Load Python virtual environment if VIRTUAL_ENV is set
if [ -n "$VIRTUAL_ENV" ]; then
    source "$VIRTUAL_ENV/bin/activate"
fi
# Unload Python venv (and remove from tmux session)
function unldvenv {
  deactivate
  if [ -n "$TMUX" ]; then
    tmux set-environment -u VIRTUAL_ENV
  fi
}

# Label studio
export LABEL_STUDIO_LOCAL_FILES_SERVING_ENABLED=true
export LABEL_STUDIO_LOCAL_FILES_DOCUMENT_ROOT=/home/vivtrain/data/recordings

# Claude
export CLAUDE_CODE_NO_FLICKER=1

# Rust (Cargo enviornment variables)
. "$HOME/.cargo/env"
