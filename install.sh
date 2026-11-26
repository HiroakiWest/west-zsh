#!/usr/bin/env zsh
# =============================================================================
#  zsh-west — West palette zsh environment installer
#
#  配色は Westlab (www.west.sd.keio.ac.jp) と Athenergy (athenergy.com) の CSS から:
#    navy #1e2f5a  /  teal #0e7c7b  /  teal-light #14a3a1  /  gold #ffd042
#
#  何度実行してもよい (冪等)。sudo は使わない。macOS / Linux (x86_64, aarch64)。
#  zsh 前提 (ログインシェルも zsh にする)。bash では動かない。
#    zsh install.sh             # インストール / 更新
#    zsh install.sh --no-git    # git の pager (delta) 設定を変えない
#
#  配置:
#    ~/.config/zsh-west/zshrc        本体 (このスクリプトが毎回上書き)
#    ~/.config/zsh-west/plugins/     プラグイン (git clone)
#    ~/.config/starship.toml         プロンプト (毎回上書き)
#    ~/.zshrc                        ローダ (上を source するだけ)
#    ~/.zshrc.local                  ホスト固有設定 (PATH, conda 等)。上書きしない
#    ~/.zsh-west-backup/<日時>/      旧設定のバックアップ
# =============================================================================
emulate zsh
autoload -Uz is-at-least
setopt err_exit pipe_fail no_unset
SELF=${0:A}

TOUCH_GIT=1
[[ "${1:-}" == "--no-git" ]] && TOUCH_GIT=0

ZW="$HOME/.config/zsh-west"
BIN="$HOME/.local/bin"
TS="$(date +%Y%m%d-%H%M%S)"
BK="$HOME/.zsh-west-backup/$TS"
mkdir -p "$ZW/plugins" "$BIN" "$HOME/.config"
path=("$BIN" $path)

c_gold=$'\e[38;2;255;208;66m'; c_teal=$'\e[38;2;20;163;161m'; c_red=$'\e[31m'; c_off=$'\e[0m'
say()  { printf '%s==>%s %s\n' "$c_teal" "$c_off" "$*"; }
warn() { printf '%s!!%s  %s\n' "$c_gold" "$c_off" "$*" >&2; }

command -v git  >/dev/null || { printf '%sgit がありません。%s\n' "$c_red" "$c_off"; exit 1; }
command -v curl >/dev/null || { printf '%scurl がありません。%s\n' "$c_red" "$c_off"; exit 1; }

# -----------------------------------------------------------------------------
# 1. CLI ツール (brew が使えれば brew、だめなら GitHub release のバイナリを ~/.local/bin へ)
# -----------------------------------------------------------------------------
OS="$(uname -s)"; ARCH="$(uname -m)"
case "$ARCH" in arm64|aarch64) ARCH=aarch64; GOARCH=arm64 ;; x86_64|amd64) ARCH=x86_64; GOARCH=amd64 ;; *) GOARCH="$ARCH" ;; esac
case "$OS" in Darwin) TRIPLES="apple-darwin"; GOOS=darwin ;; Linux) TRIPLES="unknown-linux-musl unknown-linux-gnu"; GOOS=linux ;; *) TRIPLES=""; GOOS="" ;; esac

have() { command -v "$1" >/dev/null 2>&1; }

# gh_install <owner/repo> <binary> <regex...>  : 最初にマッチした asset を使う
gh_install() {
  local repo="$1" bin="$2"; shift 2
  local urls url="" pat tmp f
  urls="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
          | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4)" || { warn "$bin: release 情報を取得できません"; return 1; }
  for pat in "$@"; do url="$(grep -E "$pat" <<<"$urls" | head -1 || true)"; [[ -n "$url" ]] && break; done
  [[ -z "$url" ]] && { warn "$bin: $OS/$ARCH 用のバイナリがありません"; return 1; }
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/pkg" || { warn "$bin: ダウンロード失敗"; rm -rf "$tmp"; return 1; }
  case "$url" in
    *.zip) (cd "$tmp" && unzip -q pkg) ;;
    *)     tar -xzf "$tmp/pkg" -C "$tmp" ;;
  esac
  f="$(find "$tmp" -type f -name "$bin" | head -1)"
  [[ -z "$f" ]] && { warn "$bin: アーカイブにバイナリがありません"; rm -rf "$tmp"; return 1; }
  install -m 755 "$f" "$BIN/$bin"
  # bat / fd / rg / delta / eza の補完・man は同梱されていれば拾う
  local comp; comp="$(find "$tmp" -type f \( -name "_$bin" -o -name "$bin.zsh" \) | head -1)"
  if [[ -n "$comp" ]]; then mkdir -p "$ZW/completions"; cp "$comp" "$ZW/completions/_$bin"; fi
  rm -rf "$tmp"
  say "$bin を $BIN に入れました ($(basename "$url"))"
}

triple_pats() { # <prefix-regex> -> 各 triple の正規表現を $reply に
  reply=(); local t; for t in ${=TRIPLES}; do reply+=("$1.*${ARCH}-${t}\.(tar\.gz|tgz|zip)\$"); done
}

TOOLS=(starship eza bat fzf zoxide fd rg delta)
missing=()
for t in $TOOLS; do have $t || missing+=($t); done

if (( $#missing )) && have brew; then
  typeset -A formula=(rg ripgrep delta git-delta)
  pkgs=(); for t in $missing; do pkgs+=(${formula[$t]:-$t}); done
  say "brew install $pkgs"
  brew install $pkgs >/dev/null 2>&1 || warn "brew install に失敗 (Xcode ライセンス未同意など)。GitHub release から入れます"
  missing=(); for t in $TOOLS; do have $t || missing+=($t); done
fi

# starship は palette / os モジュールのため 1.20 以上が必要。古ければ ~/.local/bin に新しいものを入れる
if have starship; then
  sv=$(starship --version 2>/dev/null | awk 'NR==1{print $2}')
  if ! is-at-least 1.20 ${sv:-0}; then warn "starship $sv は古いので更新します"; missing+=(starship-upgrade); fi
fi

for t in $missing; do
  case $t in
    starship|starship-upgrade) triple_pats 'starship-'; gh_install starship/starship starship $reply || true ;;
    bat)      triple_pats 'bat-v';     gh_install sharkdp/bat bat $reply || true ;;
    fd)       triple_pats 'fd-v';      gh_install sharkdp/fd fd $reply || true ;;
    rg)       triple_pats 'ripgrep-';  gh_install BurntSushi/ripgrep rg $reply || true ;;
    delta)    triple_pats 'delta-';    gh_install dandavison/delta delta $reply || true ;;
    zoxide)   triple_pats 'zoxide-';   gh_install ajeetdsouza/zoxide zoxide $reply || true ;;
    fzf)      gh_install junegunn/fzf fzf "fzf-.*-${GOOS}_${GOARCH}\.(tar\.gz|zip)\$" || true ;;
    eza)      if [[ $OS == Linux ]]; then gh_install eza-community/eza eza "eza_${ARCH}-unknown-linux-musl\.tar\.gz\$" "eza_${ARCH}-unknown-linux-gnu\.tar\.gz\$" || true
              else warn "eza: macOS 用 release バイナリは無いので brew が必要 (ls で代替します)"; fi ;;
  esac
done

# -----------------------------------------------------------------------------
# 2. zsh プラグイン
# -----------------------------------------------------------------------------
plug() { # <owner/repo>
  local d="$ZW/plugins/${1#*/}"
  if [[ -d "$d/.git" ]]; then git -C "$d" pull -q --ff-only || warn "$1 の更新に失敗"
  else git clone -q --depth 1 "https://github.com/$1.git" "$d" && say "plugin $1"; fi
}
plug zsh-users/zsh-completions
plug zsh-users/zsh-autosuggestions
plug zsh-users/zsh-syntax-highlighting
plug zsh-users/zsh-history-substring-search
plug Aloxaf/fzf-tab

# -----------------------------------------------------------------------------
# 3. 既存設定のバックアップと移行
# -----------------------------------------------------------------------------
backup() { [[ -e "$1" || -L "$1" ]] || return 0; mkdir -p "$BK"; cp -P "$1" "$BK/"; }

for f in .zshrc .zshenv .zprofile .zlogin .zlogout .zpreztorc; do backup "$HOME/$f"; done

# prezto 等へのシンボリックリンクは実ファイルに置き換える (リンク先を消しても壊れないように)
for f in .zshenv .zprofile .zlogin .zlogout; do
  if [[ -L "$HOME/$f" ]]; then cp -L "$HOME/$f" "$HOME/$f.zw-tmp" && mv -f "$HOME/$f.zw-tmp" "$HOME/$f"; fi
done

# 初回のみ: 旧 .zshrc を .zshrc.local に移す (フレームワーク読み込み行はコメントアウト)
if ! grep -q 'zsh-west loader' "$HOME/.zshrc" 2>/dev/null; then
  if [[ -e "$HOME/.zshrc" && ! -e "$HOME/.zshrc.local" ]]; then
    {
      echo "# ~/.zshrc.local — ホスト固有の設定 (zsh-west 導入時に旧 ~/.zshrc から移行: $TS)"
      echo "# ': #[zsh-west]' で始まる行は旧フレームワーク/プロンプト関連なので無効化しています。"
      echo
      # 行単位で無効化するのは「読み込み行」と「プロンプト代入」だけ (if/fi などの構造は残す)
      sed -E '/^[[:space:]]*((source|\.)[[:space:]].*(zprezto|oh-my-zsh|powerlevel|p10k|antigen|zinit|zplug)|eval .*starship init|(export[[:space:]]+)?(PS1|PROMPT|RPROMPT|ZSH_THEME)=)/ s/^/: #[zsh-west] /' "$HOME/.zshrc"
    } > "$HOME/.zshrc.local"
    say "旧 ~/.zshrc を ~/.zshrc.local に移行しました (要確認)"
  fi
  rm -f "$HOME/.zshrc"
fi
[[ -e "$HOME/.zshrc.local" ]] || printf '# ~/.zshrc.local — ホスト固有の設定 (PATH, conda, nvm など)\n' > "$HOME/.zshrc.local"

cat > "$HOME/.zshrc" <<'EOF'
# zsh-west loader — 本体は ~/.config/zsh-west/zshrc、ホスト固有設定は ~/.zshrc.local
[[ -r ~/.config/zsh-west/zshrc ]] && source ~/.config/zsh-west/zshrc
EOF

# -----------------------------------------------------------------------------
# 4. zshrc 本体
# -----------------------------------------------------------------------------
cat > "$ZW/zshrc" <<'EOF'
# =============================================================================
#  zsh-west  (このファイルは install.sh が上書きする。個別設定は ~/.zshrc.local へ)
#  palette: navy #1e2f5a / teal #0e7c7b / teal-light #14a3a1 / gold #ffd042
# =============================================================================
ZW=~/.config/zsh-west
typeset -gU path fpath
path=(~/.local/bin $path)
fpath=($ZW/completions $ZW/plugins/zsh-completions/src $fpath)
if [[ -z $LANG || $LANG == C || $LANG == POSIX ]]; then
  [[ $OSTYPE == darwin* ]] && export LANG=en_US.UTF-8 || export LANG=C.UTF-8
fi
export EDITOR=${EDITOR:-vim} PAGER=${PAGER:-less} LESS='-R -F -i -M -X -z-4'
[[ -n $SSH_CONNECTION && -z $COLORTERM ]] && export COLORTERM=truecolor

# ---- 履歴 -------------------------------------------------------------------
HISTFILE=~/.zsh_history HISTSIZE=200000 SAVEHIST=200000
setopt extended_history share_history hist_ignore_all_dups hist_ignore_space \
       hist_reduce_blanks hist_verify hist_expire_dups_first

# ---- 一般 -------------------------------------------------------------------
setopt auto_cd auto_pushd pushd_ignore_dups pushd_silent extended_glob \
       interactive_comments no_beep nonomatch prompt_subst no_flow_control
WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'

# ---- 補完 -------------------------------------------------------------------
autoload -Uz compinit
_zcd=${XDG_CACHE_HOME:-~/.cache}/zsh/zcompdump; mkdir -p ${_zcd:h}
_zold=($_zcd(N.mh+20))
if (( $#_zold )) || [[ ! -s $_zcd ]]; then compinit -i -d $_zcd; else compinit -C -d $_zcd; fi
unset _zold
{ [[ ! -s $_zcd.zwc || $_zcd -nt $_zcd.zwc ]] && zcompile $_zcd } &!
zmodload zsh/complist
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ${_zcd:h}/compcache
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu no
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*:git-checkout:*' sort false
unset _zcd

# ---- 色 ---------------------------------------------------------------------
# ディレクトリ=teal, 実行可能=gold, リンク=teal-light, アーカイブ=橙, 画像=紫
export LS_COLORS='di=1;38;2;20;163;161:ln=38;2;94;214;211:ex=1;38;2;255;208;66:so=38;2;199;146;234:pi=38;2;199;146;234:bd=38;2;255;160;80:cd=38;2;255;160;80:or=1;31:*.tar=38;2;255;160;80:*.gz=38;2;255;160;80:*.zip=38;2;255;160;80:*.xz=38;2;255;160;80:*.bz2=38;2;255;160;80:*.7z=38;2;255;160;80:*.png=38;2;199;146;234:*.jpg=38;2;199;146;234:*.jpeg=38;2;199;146;234:*.gif=38;2;199;146;234:*.svg=38;2;199;146;234:*.pdf=38;2;240;113;120:*.md=38;2;230;230;230:*.py=38;2;125;200;255:*.c=38;2;125;200;255:*.h=38;2;125;200;255:*.js=38;2;125;200;255:*.ts=38;2;125;200;255'
export EZA_COLORS="uu=38;2;255;208;66:gu=38;2;20;163;161:da=38;2;127;142;168:sn=38;2;94;214;211:sb=38;2;20;163;161"
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
export BAT_THEME=${BAT_THEME:-ansi}
export GREP_COLORS='mt=1;38;2;255;208;66'

# ---- fzf --------------------------------------------------------------------
export FZF_DEFAULT_OPTS="--height=50% --layout=reverse --border=rounded --info=inline-right \
 --prompt='❯ ' --pointer='▶' --marker='✚' --separator='─' \
 --color=fg:#d0d6e0,bg:-1,hl:#ffd042,fg+:#ffffff,bg+:#1e2f5a,hl+:#ffd042 \
 --color=border:#0e7c7b,prompt:#14a3a1,pointer:#ffd042,marker:#14a3a1,info:#7f8ea8,spinner:#ffd042,header:#ffd042,label:#ffd042"
if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi
(( $+commands[bat] )) && export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :300 {}'"
if (( $+commands[eza] )); then
  export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons --color=always {} | head -100'"
fi
if (( $+commands[fzf] )); then
  source <(fzf --zsh 2>/dev/null) 2>/dev/null
fi

# ---- キー -------------------------------------------------------------------
bindkey -e
autoload -Uz edit-command-line; zle -N edit-command-line
bindkey '^X^E' edit-command-line                 # コマンドをエディタで編集
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[H'    beginning-of-line
bindkey '^[[F'    end-of-line
bindkey '^[[3~'   delete-char

# ---- エイリアス ---------------------------------------------------------------
if (( $+commands[eza] )); then
  alias ls='eza --icons=auto --group-directories-first'
  alias l='ls -1'
  alias ll='ls -lh --git --time-style=long-iso'
  alias la='ll -a'
  alias lt='eza --tree --level=2 --icons=auto --git-ignore'
else
  if ls --color=auto / >/dev/null 2>&1; then alias ls='ls --color=auto -F'; else export CLICOLOR=1; alias ls='ls -F'; fi
  alias l='ls -1' ll='ls -lh' la='ls -lhA'
fi
if (( $+commands[bat] )); then alias cat='bat -pp'; export MANPAGER="sh -c 'col -bx | bat -l man -p'" MANROFFOPT=-c
elif (( $+commands[batcat] )); then alias bat=batcat cat='batcat -pp'; fi
alias grep='grep --color=auto'
alias ...='cd ../..' ....='cd ../../..'
alias -- -='cd -'
alias d='dirs -v | head -10'
alias g=git gs='git status -sb' gd='git diff' gl='git log --oneline --graph --decorate -20' ga='git add' gc='git commit' gp='git push'
alias reload='exec zsh'
alias path='print -l $path'
alias zw-update='zsh ~/.config/zsh-west/install.sh'

mkcd() { mkdir -p -- "$1" && cd -- "$1"; }
# 何でも展開
x() {
  case $1 in
    *.tar.gz|*.tgz) tar xzf $1 ;; *.tar.xz) tar xJf $1 ;; *.tar.bz2|*.tbz2) tar xjf $1 ;;
    *.tar) tar xf $1 ;; *.zip) unzip $1 ;; *.gz) gunzip $1 ;; *.bz2) bunzip2 $1 ;; *.xz) unxz $1 ;;
    *.7z) 7z x $1 ;; *) print -u2 "x: 未対応の形式: $1"; return 1 ;;
  esac
}
# fzf で履歴のディレクトリ / ファイル内容検索
if (( $+commands[fzf] && $+commands[rg] )); then
  fif() { rg --line-number --no-heading --color=always --smart-case "${*:-}" | fzf --ansi --delimiter : \
          --preview 'bat --color=always {1} --highlight-line {2} 2>/dev/null || sed -n {2}p {1}' \
          --preview-window '+{2}-/2' --bind 'enter:become(${EDITOR:-vim} {1} +{2})'; }
fi

# ---- zoxide (z <部分名> / zi で対話選択) ---------------------------------------
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# ---- ターミナルタイトル ----------------------------------------------------------
_zw_title() { print -Pn "\e]0;${SSH_CONNECTION:+%m: }%~\a"; }
autoload -Uz add-zsh-hook; add-zsh-hook precmd _zw_title

# ---- ホスト固有設定 ------------------------------------------------------------
[[ -r ~/.zshrc.local ]] && source ~/.zshrc.local

# ---- プロンプト ---------------------------------------------------------------
if (( $+commands[starship] )); then
  eval "$(starship init zsh)"
else
  PROMPT=$'%K{#1e2f5a}%F{#ffffff} %n%F{#ffd042}@%m %K{#0e7c7b}%F{#ffffff} %~ %k%f\n%(?.%F{#ffd042}.%F{red})❯%f '
fi

# ---- プラグイン (fzf-tab → autosuggest → syntax-highlight → substring-search の順) --
if (( $+commands[fzf] )) && [[ -r $ZW/plugins/fzf-tab/fzf-tab.plugin.zsh ]]; then
  source $ZW/plugins/fzf-tab/fzf-tab.plugin.zsh
  zstyle ':fzf-tab:*' use-fzf-default-opts yes
  zstyle ':fzf-tab:*' switch-group '<' '>'
  if (( $+commands[eza] )); then
    zstyle ':fzf-tab:complete:(cd|z|ls|ll|eza|lt):*' fzf-preview 'eza -1 --icons --color=always $realpath'
  fi
  zstyle ':fzf-tab:complete:(cat|bat|less|vim|nano):*' fzf-preview '[[ -f $realpath ]] && { bat -n --color=always --line-range :200 $realpath 2>/dev/null || head -200 $realpath; }'
fi
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#5d6f8f'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=40
source $ZW/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
bindkey '^ ' autosuggest-accept                  # Ctrl-Space で候補確定 (→ / Ctrl-E でも可)

ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)
source $ZW/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=#14a3a1,bold'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#14a3a1'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#14a3a1,bold'
ZSH_HIGHLIGHT_STYLES[function]='fg=#14a3a1'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#14a3a1,italic'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#ffd042'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#f07178,bold'
ZSH_HIGHLIGHT_STYLES[path]='fg=#d0d6e0,underline'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#ffd042'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#c3e88d'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#c3e88d'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#c3e88d'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#ffcb8b'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#ffcb8b'
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#ffd042'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#ffd042'
ZSH_HIGHLIGHT_STYLES[comment]='fg=#5d6f8f,italic'

if [[ -r $ZW/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ]]; then
  source $ZW/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
  HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='bg=#1e2f5a,fg=#ffd042,bold'
  HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
  bindkey '^[[A' history-substring-search-up
  bindkey '^[OA' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
  bindkey '^[OB' history-substring-search-down
  bindkey '^P'   history-substring-search-up
  bindkey '^N'   history-substring-search-down
fi

# ---- ようこそ (トップレベルの対話シェルで一度だけ。ZW_BANNER=0 で無効) ---------------
if [[ ${ZW_BANNER:-1} == 1 && $SHLVL -le 1 && -o interactive && -z $TMUX$STY$BYOBU_BACKEND ]]; then
  () {
    local g=$'\e[38;2;255;208;66m' t=$'\e[38;2;20;163;161m' m=$'\e[38;2;127;142;168m' b=$'\e[1m' o=$'\e[0m'
    local os up
    if [[ $OSTYPE == darwin* ]]; then os="macOS $(sw_vers -productVersion 2>/dev/null)"
    else os=$(. /etc/os-release 2>/dev/null; print -r -- ${PRETTY_NAME:-$(uname -s)}); fi
    up=$(uptime 2>/dev/null | sed -E 's/.*up +//; s/, *[0-9]+ users?.*//; s/,  *load.*//')
    print -r -- "${g}━━${o} ${b}${t}${USER}${o}${m}@${o}${b}${g}${HOST%%.*}${o}  ${m}${os} · up ${up}${o}"
  }
fi
EOF

# -----------------------------------------------------------------------------
# 5. starship (navy → teal → gold のセグメント)
# -----------------------------------------------------------------------------
cat > "$HOME/.config/starship.toml" <<'EOF'
# zsh-west starship theme — navy #1e2f5a / teal #0e7c7b / gold #ffd042
"$schema" = 'https://starship.rs/config-schema.json'
add_newline = true
command_timeout = 800
palette = "west"

format = """
$os$username$hostname\
$directory\
$git_branch$git_status$git_state\
$python$conda$nodejs$rust$golang$java$c$docker_context\
$fill\
$cmd_duration$jobs$status$time
$character"""

[palettes.west]
navy = "#1e2f5a"
teal = "#0e7c7b"
teal_light = "#14a3a1"
gold = "#ffd042"
ink = "#1a1a1a"
panel = "#123c46"
mist = "#7f8ea8"
white = "#ffffff"

[os]
disabled = false
style = "fg:gold bg:navy"
format = "[](fg:navy)[ $symbol]($style)"
[os.symbols]
Macos = " "
Ubuntu = " "
Debian = " "
Raspbian = " "
Fedora = " "
CentOS = " "
RedHatEnterprise = " "
RockyLinux = " "
AlmaLinux = " "
Arch = " "
Alpine = " "
FreeBSD = " "
Linux = " "

[username]
show_always = true
style_user = "fg:white bg:navy"
style_root = "fg:#ff6b6b bg:navy bold"
format = "[$user]($style)"

[hostname]
ssh_only = false
ssh_symbol = " "
style = "fg:gold bg:navy bold"
format = "[@$hostname$ssh_symbol ]($style)[](fg:navy) "

[directory]
style = "fg:white bg:teal bold"
read_only = " "
read_only_style = "fg:gold bg:teal"
format = "[](fg:teal)[ $path ]($style)[$read_only]($read_only_style)[](fg:teal) "
truncation_length = 4
truncation_symbol = "…/"
truncate_to_repo = false
home_symbol = "~"
[directory.substitutions]
"Documents" = " Documents"
"Downloads" = " Downloads"
"Library/CloudStorage" = ""

[git_branch]
symbol = ""
style = "fg:ink bg:gold bold"
format = "[](fg:gold)[ $symbol $branch ]($style)"
truncation_length = 28

[git_status]
style = "fg:ink bg:gold"
format = "[($all_status$ahead_behind )]($style)[](fg:gold) "
conflicted = "=$count "
ahead = "⇡$count "
behind = "⇣$count "
diverged = "⇕⇡$ahead_count⇣$behind_count "
untracked = "?$count "
stashed = "≡$count "
modified = "!$count "
staged = "+$count "
renamed = "»$count "
deleted = "✘$count "

[git_state]
style = "fg:ink bg:gold bold"
format = "[](fg:gold)[ $state $progress_current/$progress_total ]($style)[](fg:gold) "

[python]
symbol = ""
style = "fg:teal_light bg:panel"
format = "[](fg:panel)[ $symbol $version(\\($virtualenv\\)) ]($style)[](fg:panel) "
version_format = "${major}.${minor}"

[conda]
symbol = "\U000f1052"
style = "fg:teal_light bg:panel"
format = "[](fg:panel)[ $symbol $environment ]($style)[](fg:panel) "
ignore_base = true

[nodejs]
symbol = ""
style = "fg:teal_light bg:panel"
format = "[](fg:panel)[ $symbol $version ]($style)[](fg:panel) "
version_format = "${major}.${minor}"

[rust]
symbol = ""
style = "fg:teal_light bg:panel"
format = "[](fg:panel)[ $symbol $version ]($style)[](fg:panel) "

[golang]
symbol = ""
style = "fg:teal_light bg:panel"
format = "[](fg:panel)[ $symbol $version ]($style)[](fg:panel) "

[java]
symbol = ""
style = "fg:teal_light bg:panel"
format = "[](fg:panel)[ $symbol $version ]($style)[](fg:panel) "

[c]
symbol = ""
style = "fg:teal_light bg:panel"
format = "[](fg:panel)[ $symbol $version ]($style)[](fg:panel) "

[docker_context]
symbol = ""
style = "fg:teal_light bg:panel"
format = "[](fg:panel)[ $symbol $context ]($style)[](fg:panel) "

[fill]
symbol = " "

[cmd_duration]
min_time = 2000
style = "fg:gold"
format = "[ $duration ]($style)"

[jobs]
symbol = " "
style = "fg:teal_light"
format = "[$symbol$number ]($style)"

[status]
disabled = false
symbol = " "
style = "fg:#ff6b6b"
format = "[$symbol$status ]($style)"

[time]
disabled = false
time_format = "%H:%M"
style = "fg:mist"
format = "[ $time]($style)"

[character]
success_symbol = "[❯](bold gold)"
error_symbol = "[❯](bold #ff6b6b)"
vimcmd_symbol = "[❮](bold teal_light)"
EOF

# -----------------------------------------------------------------------------
# 6. git の pager を delta に (未設定の場合のみ)
# -----------------------------------------------------------------------------
if ((TOUCH_GIT)) && have delta && [[ -z "$(git config --global --get core.pager || true)" ]]; then
  git config --global core.pager delta
  git config --global interactive.diffFilter 'delta --color-only'
  git config --global delta.navigate true
  git config --global delta.line-numbers true
  git config --global delta.syntax-theme ansi
  git config --global delta.file-style 'bold "#ffd042"'
  git config --global delta.hunk-header-style 'file line-number syntax'
  git config --global delta.minus-style 'syntax "#3b1d26"'
  git config --global delta.plus-style 'syntax "#12352f"'
  say "git の pager を delta に設定しました"
fi

# Ubuntu/Debian: /etc/zsh/zshrc の compinit を止める (二重 compinit で起動が遅くなるため)
if [[ -r /etc/zsh/zshrc ]] && ! grep -q skip_global_compinit "$HOME/.zshenv" 2>/dev/null; then
  print 'skip_global_compinit=1  # zsh-west: 補完初期化は ~/.config/zsh-west/zshrc で行う' >> "$HOME/.zshenv"
  say "~/.zshenv に skip_global_compinit=1 を追加しました"
fi

# 自身を ~/.config/zsh-west/ にコピー (zw-update 用)
[[ $SELF != $ZW/install.sh ]] && cp "$SELF" "$ZW/install.sh"

# -----------------------------------------------------------------------------
# 7. 検証
# -----------------------------------------------------------------------------
zsh -n "$ZW/zshrc" && zsh -n "$HOME/.zshrc.local" || { printf '%s構文エラーがあります%s\n' "$c_red" "$c_off"; exit 1; }
ok=(); for t in $TOOLS; do have $t && ok+=($t) || ok+=("($t 無し)"); done
say "完了。ツール: $ok"
[[ -d "$BK" ]] && say "旧設定のバックアップ: $BK"
[[ ${SHELL:t} == zsh ]] || warn "ログインシェルが zsh ではありません: chsh -s \"$(command -v zsh)\""
say "新しいシェルを開くか exec zsh で反映。アイコンには Nerd Font 対応ターミナルが必要です (Ghostty は内蔵)"
