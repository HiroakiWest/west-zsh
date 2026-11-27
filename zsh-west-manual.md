# zsh-west 導入マニュアル（Ubuntu 主対象 / LLM 実行用）

> **このファイルを受け取った LLM（Claude Code 等）へ:** 以下の「実行手順」に従って、このホストの zsh 環境を zsh-west に統一してください。既に zsh-west が入っているホスト（`~/.config/zsh-west` がある）では、代わりに「更新手順」に従ってください。インストーラ本体は末尾の「付録: install.sh」にそのまま全文があります。内容を一字一句変えずにファイルへ書き出して実行してください。
>
> **改訂 2026-11-15:** Nerd Font を既定では使わない（ASCII 表示）ように変更し、`nerdfont` コマンドを追加した。手元の端末に Nerd Font が無いと、プロンプトと `ls` が文字化けして使えなくなるため。「トラブルシューティング: 文字化け」を追記。
>
> **改訂 2026-11-17:** `Tab` / `Ctrl-I` を zsh 標準の補完に戻し、fzf-tab（fzf の一覧で補完）は `Shift-Tab` に移した。fzf-tab に `Tab` を任せると、候補が複数あるたびに fzf の画面に切り替わり、「途中まで打って Tab で補完する」という普通の補完ができなかったため。
>
> **改訂 2026-11-18:** `bindkey -e` を fzf の読み込みより前に移した。`EDITOR=vim` のホストでは、fzf の「`**` の後で `Tab` を押すと fzf で選べる」機能が効いていなかったため。普段の `Tab` は zsh 標準の補完のまま。
>
> **改訂 2026-11-21:** Nerd Font を使った表示を既定にした（11/15 の「既定は ASCII」は取り消し）。手元の端末に Nerd Font を入れて使う。`nerdfont off` は、そのシェルだけ ASCII 表示にする一時的な逃げ道になり、設定として保存しない。プロンプトの区切りを丸（`( ホスト名 )( パス )( バージョン )`）から尖った矢印（`> ホスト名 > パス > バージョン >`）に変えた。末尾に「対象ホストと配布」を追加した。

## 概要

| 項目 | 内容 |
|---|---|
| 配色 | Westlab / Athenergy のサイト配色 — navy `#1e2f5a` / teal `#0e7c7b`・`#14a3a1` / gold `#ffd042` |
| プロンプト | starship（色付きの部品型。user@host / ディレクトリ / git / 言語 / 実行時間・時刻）。**Nerd Font を使った表示が既定**で、OS アイコン付き、部品の区切りは `> ホスト名 > パス > git > 言語 >` の尖った矢印。手元の端末に Nerd Font が要る |
| プラグイン | zsh-autosuggestions, zsh-syntax-highlighting, zsh-history-substring-search, zsh-completions, fzf-tab |
| ツール | starship, eza, bat, fzf, zoxide, fd, ripgrep, delta（brew が無ければ GitHub release のバイナリを `~/.local/bin` に入れる。sudo 不要） |
| 対象 | Ubuntu / Debian（x86_64・aarch64）を主対象とする。macOS でも動く |

### 配置されるファイル

| パス | 役割 |
|---|---|
| `~/.config/zsh-west/zshrc` | 本体（インストーラが毎回上書きする） |
| `~/.config/zsh-west/plugins/` | プラグイン（git clone） |
| `~/.config/zsh-west/install.sh` | インストーラのコピー（`zw-update` で再実行される） |
| `~/.config/starship.toml` | プロンプト設定・Nerd Font 版＝既定（毎回上書きする） |
| `~/.config/starship-plain.toml` | プロンプト設定・ASCII 版。`nerdfont off` のシェルだけで使う（毎回上書きする） |
| `~/.config/zsh-west/nerdfont` | 11/15 版の `nerdfont on` / `off` が書いた設定。今は読まない。残っていればインストーラが消す |
| `~/.zshrc` | ローダ。上の本体を source するだけ |
| `~/.zshrc.local` | **ホスト固有の設定**（PATH, conda, nvm, エイリアス）。インストーラは上書きしない |
| `~/.zsh-west-backup/<日時>/` | 旧設定のバックアップ |

## 実行手順（LLM 向け）

### 0. 方針
- インストーラは **zsh スクリプト**である。`zsh install-zsh-west.sh` で実行し、bash では実行しない。
- **sudo が必要な操作は自分で実行せず、ユーザーに依頼する。** パスワード入力を伴うコマンドは、ユーザーに `! <コマンド>` の形で実行してもらう。
- 既存の設定ファイルを消す・上書きする前に、中身を確認する（インストーラ自体もバックアップを取る）。
- **表示は Nerd Font を使うのが既定であり、必須である。** 勝手に off（ASCII 表示）にしない。`~/.zshrc.local` や `~/.zshenv` に off にする設定（`ZW_NERDFONT=0` など）を書かない。
- **文字の見た目（フォント）は、SSH 先ではなく手元の端末で決まる。** 手元の端末に Nerd Font が無いと、プロンプトや `ls` が □ や ? に化ける。そのときは手元にフォントを入れてもらう（「トラブルシューティング: 文字化け」）。このホストに Nerd Font を入れても、SSH 越しの表示は変わらない。**このホストにフォントを入れて文字化けを直そうとしてはいけない。**
- LLM はユーザーの画面を見られない。このホストで確かめられるのは「端末に送る文字」まで（「5. 検証」の PUA 検査）。手元でどう見えるかは、ユーザーに `nerdfont test` を実行して見てもらう。見てもらうまでは、表示が直ったと報告しない。

### 1. 事前確認
次を調べ、結果を要約してユーザーに示す。
```sh
cat /etc/os-release | head -3; uname -m
command -v zsh git curl tar unzip
echo "SHELL=$SHELL"; getent passwd "$USER" | cut -d: -f7
ls -la ~/.zshrc ~/.zshenv ~/.zprofile ~/.zlogin ~/.oh-my-zsh ~/.zprezto ~/.p10k.zsh 2>/dev/null
```

### 2. 前提パッケージ（Ubuntu）
`zsh git curl` のどれかが無ければ、ユーザーに次の実行を依頼する。
```sh
! sudo apt update && sudo apt install -y zsh git curl unzip
```
（`tar` と `install` は coreutils に含まれる）

### 3. インストーラを書き出して実行
付録の install.sh を **そのまま** `~/install-zsh-west.sh` に書き出して実行する。
```sh
zsh ~/install-zsh-west.sh            # 通常
zsh ~/install-zsh-west.sh --no-git   # git の pager を delta にしたくない場合
```
インストーラは次を行う（冪等なので何度実行してもよい）。
1. brew があれば brew で、無ければ GitHub release からツールを `~/.local/bin` に入れる。starship が 1.20 未満なら更新する
2. プラグインを `~/.config/zsh-west/plugins/` に clone する（2 回目以降は pull）
3. 旧 dotfiles を `~/.zsh-west-backup/<日時>/` に退避する。シンボリックリンクの dotfiles は実ファイルに置き換える
4. **初回のみ**、旧 `~/.zshrc` を `~/.zshrc.local` に移す。oh-my-zsh / prezto / p10k 等の読み込み行とプロンプト代入は `: #[zsh-west] ` を前置して無効化する
5. `~/.zshrc`（ローダ）、本体、`starship.toml`（Nerd Font 版）、`starship-plain.toml`（ASCII 版）を書く
6. git の `core.pager` が未設定なら delta を設定する
7. Ubuntu では `~/.zshenv` に `skip_global_compinit=1` を追加する（`/etc/zsh/zshrc` との二重 compinit を防ぐ）
8. `zsh -n` で構文を確認する

GitHub API には未認証で 1 時間 60 回の制限がある。ツールの取得に失敗したら、時間を置いて再実行する。

### 4. `~/.zshrc.local` の整理
初回の移行があった場合は中身を読み、
- ホスト固有の PATH・conda・nvm・エイリアス等は残す
- oh-my-zsh の `plugins=(...)` など、旧フレームワーク前提の行は削除するかコメントにする
- zsh-west と重複するだけの設定（`setopt` の重複、`ls` エイリアス、`compinit` など）は削除する
- `zsh -n ~/.zshrc.local` が通ることを確認する

旧フレームワーク本体（`~/.oh-my-zsh` など）は**削除しない**。削除するかどうかはユーザーに任せる。

### 5. 検証
```sh
zsh -i -l -c exit 2>&1 | grep -iE 'warn|error|not found' || echo "clean"   # clean であること
starship --version | head -1                                                # 1.20 以上
time zsh -i -l -c exit                                                      # 起動時間
env -u CLAUDECODE zsh -i -c 'bindkey "^I"; bindkey "^[[Z"' 2>/dev/null      # 補完キー
```
補完キーは、`^I` が `fzf-completion`（fzf が無いホストでは `expand-or-complete`）、`^[[Z` が `zw-fzf-tab`（fzf が無いホストでは `reverse-menu-complete`）であること。`^I` が `fzf-tab-complete` なら Tab が fzf-tab に取られている。`expand-or-complete` なのに fzf があるなら、`**` の後の Tab が効いていない。
起動が 0.5 秒を超える場合は、`zsh -l -c 'zmodload zsh/zprof; source ~/.zshrc; zprof | head -15'` で原因を特定して報告する（`~/.zshrc.local` 内の nvm や conda が原因であることが多い）。

**Nerd Font 表示の検証（必須）。** 対話シェルを疑似端末で起動し、端末に送られた文字のうち PUA（Nerd Font 専用の私用領域 U+E000–U+F8FF・U+F0000 以降）の個数を数える。設定ファイルを読んで判断するのではなく、実際に送られた文字を数える。続けて、プロンプトの区切りが矢印型になっていることを、送られた区切り文字の種類で確かめる。
```sh
zw_pua() { { sleep 2; echo 'cd ~/.config; ls'; sleep 1; echo exit; } |
  env -u CLAUDECODE -u TMUX TERM=xterm-256color "$@" script -qfec 'zsh -i' /dev/null 2>&1 |
  LC_ALL=C.UTF-8 grep -oP '[\x{E000}-\x{F8FF}\x{F0000}-\x{10FFFF}]' | wc -l; }
zw_sep() { { sleep 2; echo exit; } |
  env -u CLAUDECODE -u TMUX TERM=xterm-256color script -qfec 'zsh -i' /dev/null 2>&1 |
  LC_ALL=C.UTF-8 perl -CS -ne 'printf "U+%04X\n", ord for /[\x{E0B0}-\x{E0D7}]/g' | sort | uniq -c; }
zw_pua                  # 既定: 1 以上であること（Nerd Font 表示が既定）
zw_pua ZW_NERDFONT=0    # 0 であること（nerdfont off にすれば化けない表示に切り替わる確認）
zw_sep                  # U+E0B0（矢印の先）と U+E0D7（矢印の根元の切り欠き）だけが出ること
```
`zw_sep` に U+E0B4・U+E0B6（丸い区切り）が出たら、古い版の `starship.toml` が使われている。`zw_pua` が既定で 0 なら、どこかで off にされている（`~/.zshrc.local`・`~/.zshenv` の `ZW_NERDFONT` / `LC_NERDFONT` / `STARSHIP_CONFIG` を調べる）。
（`script -qfec` は Linux の util-linux 版。macOS では `script -q /dev/null zsh -i` に読み替える。）

### 6. ログインシェルを zsh にする
`getent passwd "$USER"` の最後の欄が zsh でなければ、ユーザーに依頼する。
```sh
! chsh -s "$(command -v zsh)"
```
`chsh` が使えない環境（LDAP 等）なら `! sudo usermod -s "$(command -v zsh)" "$USER"` を提案する。どちらも使えない場合は、`~/.bash_profile` の末尾に `[ -t 1 ] && command -v zsh >/dev/null && exec zsh -l` を追記する案を提示する（実行前にユーザーに確認する）。

### 7. 報告
次を報告する。
- 入ったツール / 入らなかったツールと理由
- `~/.zshrc.local` に加えた変更
- バックアップの場所
- ログインシェルを変更したかどうか
- Nerd Font 表示の検証の結果（`zw_pua` の 2 つの数と `zw_sep` の出力）。手元での見え方は未確認であることを書き添え、ユーザーに `nerdfont test` を頼む

## 更新手順（zsh-west が既に入っているホスト / LLM 向け）

`~/.config/zsh-west` があるホストでは、上の「実行手順」ではなくこの手順で、冒頭の改訂（2026-11-15・11-17・11-18・11-21）までを入れる。方針は「実行手順」の 0 と同じ。`zw-update` は使わない。`zw-update` はこのホストにある古いインストーラを再実行するだけで、このマニュアルの内容にはならないため。以下のコマンドは、このマニュアルを `~/zsh-west-manual.md` に置いた前提で書いてある。別の場所に置いたら読み替える。macOS では `sed -i` を `sed -i ''` に読み替える。

### 更新 1. 現状の確認
```sh
uname -sm; head -3 ~/.zshrc
awk '/^~~~~zsh$/{f=1;next} /^~~~~$/{f=0} f' ~/zsh-west-manual.md | cmp -s - ~/.config/zsh-west/install.sh && echo "最新版です" || echo "更新が必要です"
[[ -e ~/.config/starship-plain.toml ]] && echo "11/15 改訂: 済" || echo "11/15 改訂: 未"
grep -q zw-fzf-tab ~/.config/zsh-west/zshrc && echo "11/17 改訂: 済" || echo "11/17 改訂: 未"
grep -q 'bindkey -e は fzf より前' ~/.config/zsh-west/zshrc && echo "11/18 改訂: 済" || echo "11/18 改訂: 未"
grep -q '既定は Nerd Font 表示' ~/.config/zsh-west/zshrc && echo "11/21 改訂: 済" || echo "11/21 改訂: 未"
[[ -e ~/.config/zsh-west/nerdfont ]] && echo "旧版の nerdfont 設定: $(<~/.config/zsh-west/nerdfont)（インストーラが消す）"
git config --global core.pager || echo "core.pager 未設定"
```
- 「最新版です」なら、更新 5 の検証だけ行って報告する。
- `core.pager` が未設定なら、前回 `--no-git` で入れた可能性がある。更新 3 で `--no-git` を付けるかどうかをユーザーに確認する（付けないと、git の pager が delta になる）。

### 更新 2. 退避と、`~/.zshrc.local` の確認
インストーラは `~/.zshrc` などの dotfiles を `~/.zsh-west-backup/<日時>/` に退避するが、本体（`~/.config/zsh-west/zshrc`）は退避しない。そこで本体は自分で控える。ローダの 2 行目に Claude 用のガード（`CLAUDECODE` を含む行）があれば、その行も控える。インストーラがローダを書き直すと、ガードは消える。同じ日にやり直しても、最初に控えたものは上書きしない。
```sh
B=~/.zsh-west-backup/pre-update-$(date +%Y%m%d)
if [[ ! -e $B ]]; then
  mkdir -p $B && cp -a ~/.config/zsh-west/zshrc ~/.config/zsh-west/install.sh $B/
  grep -m1 CLAUDECODE ~/.zshrc > $B/claude-guard.txt || rm -f $B/claude-guard.txt
fi
ls -la $B
grep -n -E "\^\[\[Z|\^I|menu|list-grouped|fzf-tab|bindkey +-[ev]\b|_zw_rebind_complete|NERDFONT|STARSHIP_CONFIG" ~/.zshrc.local
grep -n -E "NERDFONT|STARSHIP_CONFIG" ~/.zshenv ~/.zprofile ~/.zlogin 2>/dev/null
```
`~/.zshrc.local` で見つかった行は、次のように扱う。変える前に、内容と理由をユーザーに示す。

| 見つかった行 | 扱い |
|---|---|
| `bindkey '^[[Z' ...`（Shift-Tab） | 本体が後から `zw-fzf-tab` に付け替えるので、効いていない。削除する |
| `_zw_rebind_complete` を含むブロック | 11/17 の改訂前に pegasus で入れた一時的な回避策。本体に入ったので、ブロックごと削除する |
| `bindkey '^I' ...` | ユーザーが意図して入れたもの。残す（fzf-tab を読み込んだ後も、この割り当てに戻る）。報告に書く |
| `zstyle ... menu ...` | ユーザーの好み。残す（Tab の補完に効く。Shift-Tab の間だけ `menu no` になり、終われば戻る） |
| `zstyle ':fzf-tab:...'` | 残す（Shift-Tab の fzf-tab で使われる） |
| `bindkey -v`（vi モード） | 残す。Tab は標準の補完、Shift-Tab は fzf-tab で動くが、`**` の後の Tab は効かない（fzf が emacs 用のキー表にだけ付くため）。報告に書く |
| `ZW_NERDFONT=...`・`LC_NERDFONT=...`（どのファイルでも） | Nerd Font 表示が必須になったので削除する。ホスト側で off にしない |
| `STARSHIP_CONFIG=...starship-plain.toml` | 同じ理由で削除する |
| `STARSHIP_CONFIG` で別の設定ファイルを指定 | ユーザーが意図して入れたもの。残して、矢印型の区切りにならないことを報告に書く |

変えたら `zsh -n ~/.zshrc.local` で構文を確認する。

### 更新 3. インストーラを書き出して実行
```sh
awk '/^~~~~zsh$/{f=1;next} /^~~~~$/{f=0} f' ~/zsh-west-manual.md > ~/install-zsh-west.sh
env -u CLAUDECODE zsh ~/install-zsh-west.sh            # 通常
# env -u CLAUDECODE zsh ~/install-zsh-west.sh --no-git # 更新 1 で --no-git と決めた場合
```
GitHub API には未認証で 1 時間 60 回の制限がある。ツールの取得に失敗したら、時間を置いて再実行する。

### 更新 4. Claude 用ガードを戻す（更新 2 で控えた場合だけ）
```sh
B=$(ls -d ~/.zsh-west-backup/pre-update-* | tail -1)
if [[ -s $B/claude-guard.txt ]] && ! grep -q CLAUDECODE ~/.zshrc; then sed -i "1r $B/claude-guard.txt" ~/.zshrc; fi
head -3 ~/.zshrc     # 1 行目がローダの見出し、2 行目がガード、3 行目が本体の source
```

### 更新 5. 検証
「実行手順」の 5 の検証をすべて行う（`clean`、起動時間、補完キー、`zw_pua` の 2 つの数、`zw_sep`）。補完キーは `"^I" fzf-completion` と `"^[[Z" zw-fzf-tab` になること。

tmux があるホストでは、キー操作の試験も行う。LLM はキーを押せないので、tmux の中で対話 zsh を起動し、キーを送って画面を読む。実行するコマンドの先頭には空白を入れてあり、履歴には残らない（`hist_ignore_space`）。画面の取り込みでは、zsh-autosuggestions が灰色で出す候補も普通の文字として読める。そのままだと、Tab が効いていなくても補完済みに見えてしまう。そのため最初に灰色の候補を止めている（`ZSH_AUTOSUGGEST_STRATEGY=()`）。
```bash
bash <<'EOF'
D=$(mktemp -d); mkdir -p "$D/sabitake" "$D/qzwdir_a" "$D/qzwdir_b"
T="tmux -L zwtest"
show() { echo "=== $1"; $T capture-pane -p | grep -v '^[[:space:]]*$' | tail -n "${2:-3}"; }
$T kill-server 2>/dev/null
$T new-session -d -x 110 -y 30 "env -u CLAUDECODE -u TMUX TERM=screen-256color zsh -i"
sleep 3
$T send-keys -l " cd $D; ZSH_AUTOSUGGEST_STRATEGY=()"; $T send-keys Enter; sleep 1; $T send-keys C-l; sleep 0.5
$T send-keys -l "ls sab"; sleep 0.5
show "0 打っただけ: 'ls sab' のままであること" 1
$T send-keys Tab; sleep 1
show "1 Tab 1 回: 'ls sabitake/' になること" 1
$T send-keys C-u; $T send-keys -l "ls qzw"; $T send-keys Tab; sleep 1
show "2a Tab 1 回: 'ls qzwdir_' (共通部分まで) になること" 1
$T send-keys Tab; sleep 1
show "2b Tab 2 回: '[filename]' と 'qzwdir_a/  qzwdir_b/' の一覧が出て、fzf の枠は出ないこと" 3
$T send-keys C-c; sleep 0.5; $T send-keys C-l; $T send-keys -l "ls qzwdir_"; $T send-keys BTab; sleep 2
show "3 Shift-Tab: fzf の枠 (╭ ╰) が出ること" 8
$T send-keys Escape; sleep 0.5; $T send-keys C-u; $T send-keys C-l; $T send-keys -l "ls **"; $T send-keys Tab; sleep 2
show "4 ** の後で Tab: fzf の枠が出ること" 8
$T send-keys Escape; sleep 0.5; $T kill-server; rm -rf "$D"
EOF
```
0〜4 の見出しに書いたとおりの画面になれば合格。0 で `ls sab` より長く表示されたら、灰色の候補が止まっていない。その場合、1 と 2a の結果は信用できない。

### 更新 6. ユーザーに手元で確かめてもらう
LLM が確かめられるのは、端末に送る文字までである。次をユーザーに頼み、結果を聞くまでは「直った」と報告しない。
1. `exec zsh`（または新しい端末を開く）
2. 途中まで打って `Tab` / `Ctrl-I`: 普通に補完されること（fzf の画面に切り替わらない）
3. `Shift-Tab`: fzf の一覧が出ること
4. `ls **` の後で `Tab`: fzf でファイルを選べること
5. プロンプトが `> ユーザー@ホスト > パス > ...` の尖った矢印の区切りで、OS アイコン付きになっていること。記号が □ や ? に化けたら、手元の端末に Nerd Font が無い。`nerdfont test` で確かめ、「トラブルシューティング: 文字化け」の手順 4 で手元にフォントを入れてもらう（入れるまでの間は `nerdfont off` で、そのシェルだけ ASCII 表示にできる）

### 更新 7. 報告
- ホスト名と、更新 1 の結果（どの改訂が「未」だったか）
- `~/.zshrc.local` で見つかった行と、それぞれの扱い（削除したもの・残したもの）
- 入ったツール / 入らなかったツールと理由、`--no-git` の有無
- Claude 用ガードを戻したかどうか
- 更新 5 の結果（`clean`、`^I` と `^[[Z` の割り当て、`zw_pua` の 2 つの数、`zw_sep`、キー操作試験の 0〜4）
- 退避先（`~/.zsh-west-backup/pre-update-<日付>` と、インストーラが作った `~/.zsh-west-backup/<日時>`）
- 更新 6 でユーザーが確かめた結果（未確認ならそう書く）

元に戻すには、`~/.zsh-west-backup/pre-update-<日付>/` の `zshrc` と `install.sh` を `~/.config/zsh-west/` に戻し、`~/.zshrc` などはインストーラが作った `~/.zsh-west-backup/<日時>/` から戻す。

## 利用者向けメモ

| 操作 | 内容 |
|---|---|
| `→` / `Ctrl-Space` | 灰色の候補（履歴から）を確定 |
| `↑` `↓` / `Ctrl-P` `Ctrl-N` | 入力中の文字列を含む履歴を検索 |
| `Tab` / `Ctrl-I` | zsh 標準の補完（1 回目で共通部分まで、2 回目で候補の一覧、さらに押すと順に選択） |
| `Shift-Tab` | fzf の一覧で補完（プレビュー付き。`<` `>` でグループを切り替え） |
| `**` の後で `Tab` | fzf でファイル・ディレクトリを選んで入れる（例 `vim **` `Tab`、`cd src/**` `Tab`） |
| `Ctrl-R` / `Ctrl-T` / `Alt-C` | 履歴 / ファイル / ディレクトリを fzf で検索 |
| `Ctrl-X Ctrl-E` | 入力中のコマンドをエディタで編集 |
| `z 部分名` / `zi` | よく行くディレクトリへジャンプ / 一覧から選択 |
| `fif 語` | ファイル内容を検索し、Enter でエディタを開く |
| `ll` `la` `lt` | 詳細表示 / 隠しファイルも / ツリー表示（eza） |
| `x file` | アーカイブを形式に応じて展開 |
| `mkcd dir` | ディレクトリを作って移動 |
| `gs` `gd` `gl` | `git status -sb` / `git diff`（delta） / `git log` のグラフ表示 |
| `zw-update` | インストーラを再実行（ツールとプラグインを更新） |
| `ZW_BANNER=0` | 起動時の 1 行バナーを消す（`~/.zshrc.local` に書く） |
| `nerdfont test` | 手元の端末で Nerd Font の記号が見えるか確かめる |
| `nerdfont off` / `on` | このシェルだけ ASCII 表示にする（Nerd Font の無い端末から一時的に入ったとき） / Nerd Font 表示に戻す。どちらも保存しない |
| `nerdfont` | 現在の状態を表示 |

- 表示は Nerd Font を使う（既定・必須）。アイコンと矢印型の区切りは Nerd Font の文字で、**描くのは手元の端末**なので、手元に Nerd Font が要る（SSH 先には要らないし、入れても効かない）。Ghostty と WezTerm は内蔵しているので、そのまま見える。それ以外の端末は手元に Nerd Font を入れる。化けたら下の「トラブルシューティング: 文字化け」。
- 元に戻すには、`~/.zsh-west-backup/` の最初の日時のディレクトリから dotfiles を戻す。

## トラブルシューティング: 文字化け（プロンプトや `ls` に □ ? 豆腐などが出る）

**原因はほぼ必ず「手元の端末に Nerd Font が無い」こと。** zsh-west は Nerd Font の文字（OS アイコン、矢印型の区切りなど）を既定で出す。これらは Unicode の私用領域（PUA）の文字で、どう描くかは手元の端末のフォントだけで決まる。

**やってはいけないこと**（2026-11-15 に実際にやってしまい、何度やっても直らなかった）:
- SSH 先（このマニュアルを実行しているホスト）に Nerd Font を入れる。SSH 越しの表示には効かない。`fc-list | grep -i nerd` で見つかっても、手元にあることにはならない
- `echo -e "\xee\x82\xa0"` などが表示されないのを見て、SSH 先のフォントやロケールを直そうとする
- 画面を見ないまま設定を少しずつ変え、「直ったはず」と報告する
- 化けると言われて、このホストの既定を off（ASCII 表示）に戻す。Nerd Font 表示は必須で、直すのは手元のフォント

**手順:**
1. 接続元を調べる: `echo $SSH_CONNECTION`（先頭が手元の IP）。手元の OS と端末アプリ（Windows Terminal / RLogin / Tera Term / iTerm2 / Ghostty など）を確かめる。端末アプリはこのホストからは分からないことが多いので、分からなければユーザーに聞く
2. 「5. 検証」の `zw_pua` と `zw_sep` を実行する。`zw_pua` が既定で 1 以上、`ZW_NERDFONT=0` で 0、`zw_sep` が U+E0B0 と U+E0D7 だけなら、このホストは正しい文字を送っている。化けの原因は手元の端末にある
3. それでも化けると言われたら `exec zsh` してもらう（古いシェルが残っている）。tmux のペインごとに必要
4. **手元で** Nerd Font を入れる:
   - Windows: https://github.com/ryanoasis/nerd-fonts/releases/latest から `JetBrainsMono.zip` をダウンロードして展開する。.ttf を全部選んで右クリックし、「インストール」（または「すべてのユーザーにインストール」）。端末のフォントを「JetBrainsMono Nerd Font Mono」にする（Windows Terminal は 設定 → プロファイル → 外観 → フォント フェイス。Tera Term・RLogin・MobaXterm は各アプリのフォント設定）
   - macOS: `brew install --cask font-jetbrains-mono-nerd-font` を実行し、iTerm2 / Terminal.app のプロファイルでフォントを指定する。Ghostty・WezTerm は不要
   - 入れたら SSH 先で `nerdfont test`。4 つとも記号に見えればよい。矢印の根元の切り欠き（U+E0D7）は 2022 年以降の Nerd Font にしかないので、古い Nerd Font なら最新版に入れ替える
5. フォントを入れられない端末から入ったときは、その場で `nerdfont off` を実行する（そのシェルだけ ASCII 表示になる。保存しない）。その端末からいつも入るなら、その端末側の `~/.ssh/config`（Windows は `%USERPROFILE%\.ssh\config`）に次を書くと、その端末から入ったときだけ off になる。サーバー側の sshd に `AcceptEnv LANG LC_*` が要る（Ubuntu は既定で入っている）。tmux の中では、tmux を起動したときの値のままになる
   ```
   Host *
       SetEnv LC_NERDFONT=0
   ```

判定の優先順（先に決まったものが勝つ）: `ZW_NERDFONT`（`nerdfont on` / `off` がそのシェルに設定する）→ `LC_NERDFONT`（フォントの無い端末の ssh_config）→ on。ホストの `~/.zshenv` や `~/.zshrc.local` に `ZW_NERDFONT=0` を書いて、ホストごと off にはしない。

## 付録: install.sh

~~~~zsh
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
#    ~/.config/starship.toml         プロンプト・Nerd Font 版 = 既定 (毎回上書き)
#    ~/.config/starship-plain.toml   プロンプト・ASCII 版。nerdfont off のシェルだけ (毎回上書き)
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

# ---- Nerd Font (アイコン・矢印型の区切り) -------------------------------------------
# 既定は Nerd Font 表示 (2026-11-21〜。必須)。アイコンは私用領域 (PUA) の文字で、描くのは「手元の端末」の
# フォント。手元に無いと □ や ? に化けるので、手元に Nerd Font を入れる (SSH 先に入れても効かない)。
# 決め方 (先勝ち): ZW_NERDFONT (nerdfont on/off がこのシェルに設定) > LC_NERDFONT (フォントの無い
#   端末の ssh_config の SetEnv) > on
if   [[ -n ${ZW_NERDFONT:-} ]]; then ZW_NF=$ZW_NERDFONT
elif [[ -n ${LC_NERDFONT:-} ]]; then ZW_NF=$LC_NERDFONT
else ZW_NF=1; fi
if [[ $ZW_NF == (0|off) ]]; then ZW_NF=0 ZW_ICONS=never ZW_ICONS_PV=never
else ZW_NF=1 ZW_ICONS=auto ZW_ICONS_PV=always; fi
nerdfont() {
  case ${1:-} in
    on|off) export ZW_NERDFONT=$1; exec zsh ;;   # このシェルだけ。保存しない
    test) print -r -- $'[] [] [] []  <- 4 つとも記号に見えれば手元の端末に Nerd Font がある。□ や ? なら無い' ;;
    *) print -r -- "nerdfont: いま ${${ZW_NF:#0}:+on}${${ZW_NF:#1}:+off}   使い方: nerdfont test | off (このシェルだけ ASCII 表示) | on" ;;
  esac
}

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
  export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons=$ZW_ICONS_PV --color=always {} | head -100'"
fi
# bindkey -e は fzf より前に置く。EDITOR=vim だと zsh は vi 用のキー表で始まり、fzf の
# Tab (** の後で fzf を開く) がそちらに付いて、後の bindkey -e で使われなくなるため
bindkey -e
if (( $+commands[fzf] )); then
  source <(fzf --zsh 2>/dev/null) 2>/dev/null
fi

# ---- キー -------------------------------------------------------------------
autoload -Uz edit-command-line; zle -N edit-command-line
bindkey '^X^E' edit-command-line                 # コマンドをエディタで編集
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[H'    beginning-of-line
bindkey '^[[F'    end-of-line
bindkey '^[[3~'   delete-char
bindkey '^[[Z'    reverse-menu-complete            # Shift-Tab (fzf-tab があれば下で fzf-tab に変える)

# ---- エイリアス ---------------------------------------------------------------
if (( $+commands[eza] )); then
  alias ls="eza --icons=$ZW_ICONS --group-directories-first"
  alias l='ls -1'
  alias ll='ls -lh --git --time-style=long-iso'
  alias la='ll -a'
  alias lt="eza --tree --level=2 --icons=$ZW_ICONS --git-ignore"
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
  # Nerd Font off なら ASCII 版。~/.zshrc.local で別の STARSHIP_CONFIG を指定していればそれを尊重
  if (( ZW_NF )); then
    [[ ${STARSHIP_CONFIG:-} == */starship-plain.toml ]] && unset STARSHIP_CONFIG
  elif [[ -z ${STARSHIP_CONFIG:-} || $STARSHIP_CONFIG == */starship-plain.toml ]]; then
    export STARSHIP_CONFIG=$HOME/.config/starship-plain.toml
  fi
  eval "$(starship init zsh)"
elif (( ZW_NF )); then   # starship が無いとき。区切りは starship と同じ矢印型
  PROMPT=$'%F{#1e2f5a}%K{#1e2f5a}%F{#ffffff} %n%F{#ffd042}@%m %k%F{#1e2f5a}%F{#0e7c7b}%K{#0e7c7b}%F{#ffffff} %~ %k%F{#0e7c7b}%f\n%(?.%F{#ffd042}.%F{red})❯%f '
else
  PROMPT=$'%K{#1e2f5a}%F{#ffffff} %n%F{#ffd042}@%m %K{#0e7c7b}%F{#ffffff} %~ %k%f\n%(?.%F{#ffd042}.%F{red})>%f '
fi

# ---- プラグイン (fzf-tab → autosuggest → syntax-highlight → substring-search の順) --
if (( $+commands[fzf] )) && [[ -r $ZW/plugins/fzf-tab/fzf-tab.plugin.zsh ]]; then
  source $ZW/plugins/fzf-tab/fzf-tab.plugin.zsh
  # fzf-tab は Shift-Tab のときだけ使う。Tab / Ctrl-I は zsh 標準の補完のまま。
  # (有効のままだと Tab を奪い、候補が複数あるたびに fzf の画面に切り替わる)
  disable-fzf-tab
  zw-fzf-tab() {
    local -a _m; zstyle -g _m ':completion:*' menu
    zstyle ':completion:*' menu no             # fzf-tab が共通部分を拾うのに要る。この間だけ
    enable-fzf-tab
    { zle fzf-tab-complete } always {
      disable-fzf-tab
      if (( $#_m )); then zstyle ':completion:*' menu $_m; else zstyle -d ':completion:*' menu; fi
    }
  }
  zle -N zw-fzf-tab
  bindkey -M emacs '^[[Z' zw-fzf-tab; bindkey -M viins '^[[Z' zw-fzf-tab
  zstyle ':fzf-tab:*' use-fzf-default-opts yes
  zstyle ':fzf-tab:*' switch-group '<' '>'
  if (( $+commands[eza] )); then
    zstyle ':fzf-tab:complete:(cd|z|ls|ll|eza|lt):*' fzf-preview "eza -1 --icons=$ZW_ICONS_PV --color=always \$realpath"
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

# 11/15 版の nerdfont on/off の保存先。Nerd Font 表示が既定・必須になったので読まない。残っていれば消す
if [[ -e "$ZW/nerdfont" ]]; then
  say "旧版の nerdfont 設定 ($(<"$ZW/nerdfont")) を消しました。表示は Nerd Font が既定です"
  rm -f "$ZW/nerdfont"
fi

# -----------------------------------------------------------------------------
# 5. starship (navy → teal → gold のセグメント。区切りは矢印型 > host > path > git > 言語 >)
# -----------------------------------------------------------------------------
cat > "$HOME/.config/starship.toml" <<'EOF'
# zsh-west starship theme (Nerd Font 版 = 既定) — navy #1e2f5a / teal #0e7c7b / gold #ffd042
# 区切りは矢印型 (> host > path > git > 言語 >)。各部品は U+E0D7 (根元の切り欠き) で始まり
# U+E0B0 (矢印の先) で終わる。部品が出たり出なかったりしても形が崩れないよう、部品ごとに閉じる
"$schema" = 'https://starship.rs/config-schema.json'
add_newline = true
command_timeout = 800
palette = "west"

format = """
[](fg:navy)$os$username$hostname\
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
format = "[ $symbol]($style)"
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
format = "[@$hostname$ssh_symbol ]($style)[](fg:navy)"

[directory]
style = "fg:white bg:teal bold"
read_only = " "
read_only_style = "fg:gold bg:teal"
format = "[](fg:teal)[ $path ]($style)[$read_only]($read_only_style)[](fg:teal)"
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
format = "[](fg:gold)[ $symbol $branch ]($style)"
truncation_length = 28

[git_status]
style = "fg:ink bg:gold"
format = "[($all_status$ahead_behind )]($style)[](fg:gold)"
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
format = "[](fg:gold)[ $state $progress_current/$progress_total ]($style)[](fg:gold)"

[python]
symbol = ""
style = "fg:teal_light bg:panel"
format = "[](fg:panel)[ $symbol $version(\\($virtualenv\\)) ]($style)[](fg:panel)"
version_format = "${major}.${minor}"

[conda]
symbol = "\U000f1052"
style = "fg:teal_light bg:panel"
format = "[](fg:panel)[ $symbol $environment ]($style)[](fg:panel)"
ignore_base = true

[nodejs]
symbol = ""
style = "fg:teal_light bg:panel"
format = "[](fg:panel)[ $symbol $version ]($style)[](fg:panel)"
version_format = "${major}.${minor}"

[rust]
symbol = ""
style = "fg:teal_light bg:panel"
format = "[](fg:panel)[ $symbol $version ]($style)[](fg:panel)"

[golang]
symbol = ""
style = "fg:teal_light bg:panel"
format = "[](fg:panel)[ $symbol $version ]($style)[](fg:panel)"

[java]
symbol = ""
style = "fg:teal_light bg:panel"
format = "[](fg:panel)[ $symbol $version ]($style)[](fg:panel)"

[c]
symbol = ""
style = "fg:teal_light bg:panel"
format = "[](fg:panel)[ $symbol $version ]($style)[](fg:panel)"

[docker_context]
symbol = ""
style = "fg:teal_light bg:panel"
format = "[](fg:panel)[ $symbol $context ]($style)[](fg:panel)"

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

# ASCII 版 (nerdfont off のシェルだけ)。Nerd Font の文字を一つも使わない。手元の端末のフォントを問わず化けない
cat > "$HOME/.config/starship-plain.toml" <<'EOF'
# zsh-west starship theme (ASCII 版) — nerdfont off のシェルだけで使う。手元に Nerd Font が無くても化けない
# 既定は Nerd Font 版の starship.toml。切替は nerdfont off / on (そのシェルだけ)
"$schema" = 'https://starship.rs/config-schema.json'
add_newline = true
command_timeout = 800
palette = "west"

format = """
$username$hostname\
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

[username]
show_always = true
style_user = "fg:white bg:navy"
style_root = "fg:#ff6b6b bg:navy bold"
format = "[ $user]($style)"

[hostname]
ssh_only = false
ssh_symbol = ""
style = "fg:gold bg:navy bold"
format = "[@$hostname ]($style) "

[directory]
style = "fg:white bg:teal bold"
read_only = " RO"
read_only_style = "fg:gold bg:teal"
format = "[ $path ]($style)[$read_only]($read_only_style) "
truncation_length = 4
truncation_symbol = ".../"
truncate_to_repo = false
home_symbol = "~"

[git_branch]
style = "fg:ink bg:gold bold"
format = "[ git:$branch ]($style)"
truncation_length = 28
truncation_symbol = "..."

[git_status]
style = "fg:ink bg:gold"
format = "[($all_status$ahead_behind )]($style) "
conflicted = "=$count "
ahead = "^$count "
behind = "v$count "
diverged = "^$ahead_count v$behind_count "
untracked = "?$count "
stashed = "s$count "
modified = "!$count "
staged = "+$count "
renamed = "r$count "
deleted = "x$count "

[git_state]
style = "fg:ink bg:gold bold"
format = "[ $state $progress_current/$progress_total ]($style) "

[python]
style = "fg:teal_light bg:panel"
format = "[ py $version(\\($virtualenv\\)) ]($style) "
version_format = "${major}.${minor}"

[conda]
style = "fg:teal_light bg:panel"
format = "[ conda $environment ]($style) "
ignore_base = true

[nodejs]
style = "fg:teal_light bg:panel"
format = "[ node $version ]($style) "
version_format = "${major}.${minor}"

[rust]
style = "fg:teal_light bg:panel"
format = "[ rs $version ]($style) "

[golang]
style = "fg:teal_light bg:panel"
format = "[ go $version ]($style) "

[java]
style = "fg:teal_light bg:panel"
format = "[ java $version ]($style) "

[c]
style = "fg:teal_light bg:panel"
format = "[ C $version ]($style) "

[docker_context]
style = "fg:teal_light bg:panel"
format = "[ docker $context ]($style) "

[fill]
symbol = " "

[cmd_duration]
min_time = 2000
style = "fg:gold"
format = "[ took $duration ]($style)"

[jobs]
symbol = "jobs:"
style = "fg:teal_light"
format = "[$symbol$number ]($style)"

[status]
disabled = false
symbol = "ERR "
style = "fg:#ff6b6b"
format = "[$symbol$status ]($style)"

[time]
disabled = false
time_format = "%H:%M"
style = "fg:mist"
format = "[$time]($style)"

[character]
success_symbol = "[>](bold gold)"
error_symbol = "[>](bold #ff6b6b)"
vimcmd_symbol = "[<](bold teal_light)"
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
say "新しいシェルを開くか exec zsh で反映。表示は Nerd Font (OS アイコン・矢印型の区切り) が既定"
say "記号が □ や ? に化けたら「手元の端末」に Nerd Font を入れる (SSH 先に入れても効かない)。確認は nerdfont test、入れるまでの間は nerdfont off (そのシェルだけ ASCII 表示)"
~~~~

## 対象ホストと配布

この設定（このマニュアルと、それで入れる zsh-west）は、普段よく使う次のホストすべてで共通である。マニュアルを改訂したら全ホストに配り、それぞれで「更新手順」（`~/.config/zsh-west` が無いホストでは「実行手順」）を行う。原本は pegasus の `~/zsh-west-manual.md`。

| ホスト | 備考 |
|---|---|
| `west.sd.keio.ac.jp` | |
| `west.west.sd.keio.ac.jp` | |
| `prism.west.sd.keio.ac.jp` | |
| `class.west.sd.keio.ac.jp` | access1 と同じサーバー（131.113.98.81） |
| `hostm.iee.or.jp` | |
| `workshop.iee.or.jp` | |
| `e-west.info` | pegasus 自身（研究室の内側からは 10.1.1.2）。原本を置くホストなので、配らずにその場で更新する |
| `whitewhale.west` | 研究室の LAN と VPN の内側からだけ届く |

### 配布の手順（原本のあるホストの LLM 向け）

コマンドは bash でも zsh でも動くように書いてある。

1. ログインできるか確かめる。各ホストには鍵を登録してある。どの鍵を使うかは `~/.ssh/config` で決まる（`ssh -G <ホスト> | grep -i '^identityfile'` で分かる）。
   ```sh
   H="west.sd.keio.ac.jp west.west.sd.keio.ac.jp prism.west.sd.keio.ac.jp class.west.sd.keio.ac.jp hostm.iee.or.jp workshop.iee.or.jp whitewhale.west"
   for h in $(echo $H); do printf '%-28s ' $h; ssh -o BatchMode=yes -o ConnectTimeout=10 $h 'echo ok $(uname -sm)' 2>&1 | tail -1; done
   ```
2. `Permission denied` のホストは、鍵にパスフレーズが付いていて、LLM のシェルからは使えない。LLM はパスフレーズを入力できないので、ユーザーにログインを手伝ってもらう。ユーザーに、別の端末から原本のあるホストに入って次を実行してもらう（パスフレーズを聞かれる。`-t 4h` で、鍵は 4 時間後にエージェントから消える）。
   ```sh
   systemctl --user start ssh-agent.socket     # エージェントが無ければ
   SSH_AUTH_SOCK=/run/user/$(id -u)/openssh_agent ssh-add -t 4h ~/.ssh/<鍵ファイル> ...
   ```
   以降、LLM はコマンドの頭に `SSH_AUTH_SOCK=/run/user/$(id -u)/openssh_agent` を付けて ssh・scp を使う。終わったら `ssh-add -D` で鍵を消してよいか、ユーザーに聞く。
3. `Host key verification failed`（ホスト鍵が変わった）のホストは、`known_hosts` を勝手に書き換えない。指紋（`ssh-keyscan <ホスト> | ssh-keygen -lf -`）をユーザーに示して確認を取る。名前解決できないホストは、ホスト名をユーザーに確かめる。
4. ログインできたホストに配る。
   ```sh
   for h in $(echo $H); do scp -q ~/zsh-west-manual.md $h:zsh-west-manual.md && echo "$h: 配布済み"; done
   ```
5. ホストごとに「更新手順」の 1〜5（zsh-west が無いホストは「実行手順」）を、ssh でコマンドを送って行う。ログインシェルが bash や tcsh のホストもあるので、複数行のコマンドは `ssh <ホスト> bash -s <<'EOF'` … `EOF` の形で送る。sudo が要る操作（zsh・git・curl が無い、`chsh`）は、ユーザーにそのホストで実行してもらう。
6. 報告: ホストごとに「更新 7. 報告」の項目をまとめる。ログインできなかったホストは理由も書く。最後に、手元の端末から各ホストに入り直して「更新 6」を確かめてもらうよう、ユーザーに頼む。
