#### Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

#### Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

#### Source/Load zinit ####
source "${ZINIT_HOME}/zinit.zsh"

#### Add in zsh plugins ####
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

#### Add in Snippet ####
zinit snippet OMZP::git

#### Load completions ####
autoload -Uz compinit && compinit

#### Keybindings ####
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

#### History ####
HISTSIZE=5000
HISTFILE=~/.config/zsh/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

export FZF_CTRL_T_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'if [ -d {} ]; then eza -ah --oneline --icons=always --color=always {}; else bat -n --color=always {}; fi'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'
  --height 40%"

#### Completion Styling ####
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:*' fzf-preview '
    if [[ -d $realpath ]]; then
        eza -ah --oneline --icons=always --color=always "$realpath"
    elif [[ -f $realpath ]]; then
        bat --color=always --style=plain "$realpath"
    fi'
 zstyle ':fzf-tab:*' fzf-flags --bind='ctrl-/:change-preview-window(down|hidden|)'

##### Include Aliases ####
[ -f "$HOME/.config/zsh/aliasrc" ] && source "$HOME/.config/zsh/aliasrc"
[ -f "$HOME/.config/zsh/functionrc" ] && source "$HOME/.config/zsh/functionrc"

#### Shell Integration ####
eval "$(fzf --zsh)"
eval "$(starship init zsh)"

export VIRTUAL_ENV_DISABLE_PROMPT=0
export XCURSOR_THEME=phinger-cursors-dark
export XCURSOR_SIZE=24

# source <(ng completion script)
# source /usr/share/nvm/init-nvm.sh
