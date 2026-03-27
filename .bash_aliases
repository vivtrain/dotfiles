# Preferences
alias vim='nvim'
alias nv='nvim'
alias view='nvim -R'
alias vb='vim ~/.bashrc'
alias sb='source ~/.bashrc'
alias vba='vim ~/.bash_aliases'

alias vc='vim ~/.vimrc'

alias tc='vim ~/.tmux.conf'
alias st='tmux source-file ~/.tmux.conf'


# File system/shell navigation
alias ll='ls -lhXv'
alias la='ls -A'
alias lla='ll -A'
alias l='ll'
alias tree='tree -vC'
alias treeg='tree --gitignore'

alias ppd='popd'
alias pd=pushd $1
alias bd='cd -'
alias ..='cd ..'

alias c='clear'
alias x='exit'

alias mkdir='mkdir -m u=rwx,g=r,o=r'

alias please='sudo'


# # Shortcuts
alias tm='tmux new-session -A -s tmux'
alias mk='make'
alias km='make'
alias mkr='make && echo "" && ./run'
alias mrk=mkr
alias krm=mkr
alias rmk=mkr
alias mkc='make clean'
alias vs='vim -S'
alias nvs='nvim -S'
alias omp='oh-my-posh'
alias open='xdg-open'
# markdown viewer
function md {
    if [[ -z "$1" ]]; then
        echo "Usage: md <file.md>"
        return 1
    fi

    if [[ ! -f "$1" ]]; then
        echo "Error: File '$1' not found"
        return 1
    fi

    (retext --preview "`realpath $1`" &>/dev/null &) 2>/dev/null
}
# basename of a file
function bn {
  if [ $# -eq 1 ]; then
    basename `realpath $1`
  elif [ $# -eq 0 ]; then
    basename `realpath .`
  fi
}


# # Orin stuff
alias ssh-orin='ssh dm@192.168.55.1'
alias sshfs-orin='sshfs dm@192.168.55.1:/home/dm /home/vivtrain/DavisMechatronics/orin/'

# # Python
alias py='python'
alias py3='python3'
alias prettyjson='python -m json.tool'
alias mkvenv='python -m venv venv'


# # Git
alias gs='git status'
alias gl='git log --graph'
alias gt='git log --graph --all --oneline --decorate --topo-order'
alias ga='git add'
alias gap='git add --patch'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gp='git push'
alias gd='git diff'
alias gds='git diff --staged'
alias gf='git fetch origin'
alias gfa='git fetch --all'
alias gr='cd $(git rev-parse --show-toplevel)'
alias grd='git rev-parse --show-toplevel'
alias gsw='git switch'


# # Colors and highlights
export    NORMAL_COLOR='\e[0m'
export           BLACK='\e[30m'
export             RED='\e[31m'
export           GREEN='\e[32m'
export          YELLOW='\e[33m'
export            BLUE='\e[34m'
export          PURPLE='\e[35m'
export            CYAN='\e[36m'
export      LIGHT_GRAY='\e[37m'
export            GRAY='\e[90m'
export       LIGHT_RED='\e[91m'
export     LIGHT_GREEN='\e[92m'
export    LIGHT_YELLOW='\e[93m'
export      LIGHT_BLUE='\e[94m'
export    LIGHT_PURPLE='\e[95m'
export      LIGHT_CYAN='\e[96m'
export           WHITE='\e[97m'
export        BG_BLACK='\e[97;40m'
export          BG_RED='\e[30;41m'
export        BG_GREEN='\e[30;42m'
export       BG_YELLOW='\e[30;43m'
export         BG_BLUE='\e[97;44m'
export       BG_PURPLE='\e[30;45m'
export         BG_CYAN='\e[30;46m'
export   BG_LIGHT_GRAY='\e[30;47m'
export         BG_GRAY='\e[30;100m'
export    BG_LIGHT_RED='\e[30;101m'
export  BG_LIGHT_GREEN='\e[30;102m'
export BG_LIGHT_YELLOW='\e[30;103m'
export   BG_LIGHT_BLUE='\e[30;104m'
export BG_LIGHT_PURPLE='\e[30;105m'
export   BG_LIGHT_CYAN='\e[30;106m'
export        BG_WHITE='\e[30;107m'
# Note on modes ################
# normal:    \e[0;${COLOR_CODE}m
# bold:      \e[1;${COLOR_CODE}m
# faint:     \e[2;${COLOR_CODE}m
# italics:   \e[3;${COLOR_CODE}m
# underline: \e[4;${COLOR_CODE}m

function color {
  echo -ne $1
  ${@:2}
  echo -ne $NO_COLOR
}

