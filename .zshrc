#!/usr/bin/env zsh
# ============================================
# 轻量级zsh配置（从bashrc迁移）
# ============================================

# 启用Zsh的现代特性
autoload -Uz compinit colors vcs_info
compinit -d ~/.zcompdump
colors

# ============================================
# 1. 环境变量（直接迁移）
# ============================================
export EDITOR=nvim
export VISUAL=nvim
export BAT_THEME="tokyonight_night"

# ============================================
# 2. 别名（优化迁移）
# ============================================
alias hyprland="start-hyprland"
alias ls="eza --color=always --long --git --no-filesize --icons=always --no-time --no-user --no-permissions"
alias grep='grep --color=auto'
alias snvim='sudo -E nvim'

# ============================================
# 3. Starship提示符
# ============================================
eval "$(starship init zsh)"

# ============================================
# 4. Zsh插件系统（轻量级配置）
# ============================================

# 语法高亮（替代blesh的syntax highlight）
if [[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  # 自定义高亮颜色
  ZSH_HIGHLIGHT_STYLES[default]='none'
  ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=red'
  ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=green'
  ZSH_HIGHLIGHT_STYLES[alias]='fg=cyan'
  ZSH_HIGHLIGHT_STYLES[builtin]='fg=cyan'
  ZSH_HIGHLIGHT_STYLES[function]='fg=cyan'
  ZSH_HIGHLIGHT_STYLES[command]='fg=green'
  ZSH_HIGHLIGHT_STYLES[precommand]='fg=green'
  ZSH_HIGHLIGHT_STYLES[commandseparator]='none'
  ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=green'
  ZSH_HIGHLIGHT_STYLES[path]='underline'
  ZSH_HIGHLIGHT_STYLES[globbing]='fg=blue'
  ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=blue'
  ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=yellow'
  ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=yellow'
  ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='none'
  ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=yellow'
  ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=yellow'
  ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=cyan'
  ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=cyan'
  ZSH_HIGHLIGHT_STYLES[assign]='none'
fi

# 自动建议（替代blesh的auto-complete）
if [[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
  # 配置自动建议
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  ZSH_AUTOSUGGEST_USE_ASYNC=true
  ZSH_AUTOSUGGEST_MANUAL_REBIND=true  # 提升性能

  # 颜色配置（类似blesh的auto_complete='fg=242'）
  if [[ $TERM == "linux" ]];then
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=0,bold"
  else
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=242"
  fi
fi

# ============================================
# 5. 增强补全系统（替代blesh的complete）
# ============================================

# 启用zsh的补全系统
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# 限制补全数量（类似blesh的complete_limit_auto=50）
zstyle ':completion:*' max-errors 2 numeric
zstyle ':completion:*' completer _expand _complete _ignored _approximate

# 缓存补全结果
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# ============================================
# 6. FZF配置（迁移自bash）
# ============================================
if [[ -f /usr/share/fzf/key-bindings.zsh ]]; then
  source /usr/share/fzf/key-bindings.zsh
fi

if [[ -f /usr/share/fzf/completion.zsh ]]; then
  source /usr/share/fzf/completion.zsh
fi

# FZF默认选项
export FZF_DEFAULT_OPTS="--preview 'bat --color=always {}'"
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS \
  --highlight-line \
  --info=inline-right \
  --ansi \
  --layout=reverse \
  --border=none \
  --color=bg+:#2d3f76 \
  --color=bg:#1e2030 \
  --color=border:#589ed7 \
  --color=fg:#c8d3f5 \
  --color=gutter:#1e2030 \
  --color=header:#ff966c \
  --color=hl+:#65bcff \
  --color=hl:#65bcff \
  --color=info:#545c7e \
  --color=marker:#ff007c \
  --color=pointer:#ff007c \
  --color=prompt:#65bcff \
  --color=query:#c8d3f5:regular \
  --color=scrollbar:#589ed7 \
  --color=separator:#ff966c \
  --color=spinner:#ff007c \
"

# FZF补全配置
_fzf_compgen_path() {
  fd --hidden --follow --exclude ".git" . "$1"
}

_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude ".git" . "$1"
}

# ============================================
# 7. SSH密钥加载函数（调整后迁移）
# ============================================
function _prompt_load_ssh_keys() {
  if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" >/dev/null 2>&1
  fi

  if ! ssh-add -l >/dev/null 2>&1; then
    local old_stty_settings
    if [ -t 0 ] && old_stty_settings=$(stty -g 2>/dev/null); then
      stty sane echo
    else
      echo "(Non-interactive or non-TYY environment, skipping key load.)"
      return 0
    fi

    if [[ $TERM == "linux" ]]; then
      echo "Loading SSH keys..."
      ssh-add ~/.ssh/id_ed25519 2>/dev/null
      if [ $? -eq 0 ]; then
        echo "Keys loaded successfully."
      else
        echo "Failed to load keys."
        echo "Please check if the key file exists or the passphrase is correct."
      fi
    else
      echo -n "No SSH keys loaded. Load now? [y]: "
      local response
      read -t 3 -r response
      [ -n "$old_stty_settings" ] && stty "$old_stty_settings" 2>/dev/null

      case "$response" in
        [yY])
            echo "Loading SSH keys..."
            ssh-add ~/.ssh/id_ed25519 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "Keys loaded successfully."
            else
                echo "Failed to load keys."
                echo "Please check if the key file exists or the passphrase is correct."
            fi
            ;;
        *)
            echo ""
            echo "Skipped SSH key loading."
            ;;
      esac
    fi
  fi
}

# 只在交互式shell中执行
if [[ -o interactive ]]; then
  _prompt_load_ssh_keys
fi

# ============================================
# 8. Zsh特有优化和配置
# ============================================

# 历史记录配置
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS     # 忽略重复命令
setopt HIST_IGNORE_SPACE    # 忽略空格开头的命令
setopt SHARE_HISTORY        # 共享历史记录

# 目录导航优化
setopt AUTO_CD              # 直接输入目录名进入
setopt CDABLE_VARS          # 允许cd到变量表示的目录
setopt AUTO_PUSHD           # 自动pushd
setopt PUSHD_IGNORE_DUPS    # 忽略重复目录

# 补全优化
setopt COMPLETE_IN_WORD     # 在单词中间补全
setopt ALWAYS_TO_END        # 补全后移动到末尾
setopt LIST_PACKED          # 紧凑列表显示
setopt MENU_COMPLETE        # 按Tab自动选择第一个

# 通配符增强
setopt EXTENDED_GLOB        # 启用扩展通配符

# 禁用功能以减少内存
unsetopt BEEP              # 关闭提示音
unsetopt CORRECT           # 关闭自动纠正
unsetopt FLOW_CONTROL      # 禁用Ctrl+S/Ctrl+Q流控制

# ============================================
# 9. 性能优化
# ============================================

# 延迟加载重插件（如果有的话）
zmodload zsh/terminfo 2>/dev/null
zmodload zsh/complist 2>/dev/null

# 异步初始化某些组件
() {
  # 延迟1秒后运行非关键初始化
  sleep 1 && {
    # 这里可以放非必要的初始化
    :
  } &!
}

# ============================================
# 10. 键绑定（类似blesh体验）
# ============================================


# ============================================
# 11. 兼容性设置（可选的bash兼容模式）
# ============================================

# 如果需要运行bash脚本或命令
bash() {
  if [[ $1 == -c ]]; then
    command bash "$@"
  else
    NO_ZSH_BASH_COMPAT=1 command bash "$@"
  fi
}

# 加载用户自定义配置（如果存在）
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local


# Created by `pipx` on 2026-01-25 05:23:03
export PATH="$PATH:/home/jomoarch/.local/bin"
export JAVA_HOME=/usr/lib/jvm/default

