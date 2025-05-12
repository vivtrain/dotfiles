# Preferences
alias vim='nvim'
alias nv='nvim'
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

alias ppd='popd'
alias pd=pushd $1
alias bd='cd -'
alias ..='cd ..'

alias c='clear'
alias x='exit'
alias tm='tmux'

alias mkdir='mkdir -m u=rwx,g=r,o=r'


# # Shortcuts
alias py='python3'
alias py3='python3'
#alias killpy='killall python'
#alias open='nautilus $1 &>/dev/null'
#alias term='gnome-terminal'
#alias sysmon='gnome-system-monitor & disown'
#alias off='shutdown now'
#alias fan="sudo ~/scripts/_fan $1"
alias mk='make'
alias km='make'
alias mkr='make && echo "" && ./run'
alias mkc='make clean'
alias vs='vim -S'
alias chrome='google-chrome-stable &> /dev/null & disown'
alias CUR_DIR='basename $PWD'
alias omp='oh-my-posh'


# # Git
alias gs='git status'
alias gl='git log --graph'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gd='git diff'
alias gf='git fetch origin'
alias gr='cd $(git rev-parse --show-toplevel)'
alias prod='git switch production'
alias dev='git switch development'


# # Windows Clipboard Access
alias clip='clip.exe'
alias paste='powershell.exe Get-Clipboard'


# # Colors and highlights
export        NO_COLOR='\e[0m'
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

