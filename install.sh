#!/bin/sh
# 安装 mini-polkit + 选择密码提示后端（默认 dmenu）
#   ./install.sh
#   ./install.sh --prompt=dmenu
#   ./install.sh --prompt=rofi
#   POLKIT_PROMPT=rofi ./install.sh
# 父仓: ./install.sh mini-polkit [--prompt=…] 或 desktop:suckless --polkit
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
PROMPT="${POLKIT_PROMPT:-dmenu}"
DO_BUILD=1

usage() {
	cat <<'EOF'
用法: ./install.sh [选项]

安装 mini-polkit 二进制，并写入用户配置选择密码框后端。

选项:
  --prompt=dmenu   用 dmenu -P（默认；不依赖 rofi）
  --prompt=rofi    用 rofi-askpass（需已 ./install.sh x11:rofi）
  --prompt dmenu|rofi
                   同上（分两个参数）
  --no-build       不编译，只写 prompt 配置 / 安装 agent 脚本
  -h, --help       显示本说明

环境变量:
  POLKIT_PROMPT=dmenu|rofi   与 --prompt 相同（命令行优先）

落地:
  /usr/bin/mini-polkit              （make install，需提权）
  ~/.local/bin/mini-polkit-agent    按配置启动 agent
  ~/.config/mini-polkit/prompt      当前后端名（dmenu|rofi）

会话里（dwm-session）应启动:
  mini-polkit-agent &

测: pkexec echo ok
同一会话不要再起其它 polkit agent。Hyprland 请用 hyprpolkitagent，不要装本 agent。

示例:
  ./install.sh
  ./install.sh --prompt=rofi
  ./install.sh --prompt dmenu --no-build
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
	--prompt=*)
		PROMPT="${1#--prompt=}"
		;;
	--prompt)
		shift
		PROMPT="${1:-}"
		[ -n "$PROMPT" ] || { echo "缺少 --prompt 值" >&2; usage >&2; exit 1; }
		;;
	--no-build) DO_BUILD=0 ;;
	-h|--help) usage; exit 0 ;;
	-*)
		echo "未知选项: $1" >&2
		usage >&2
		exit 1
		;;
	*)
		echo "未知参数: $1" >&2
		usage >&2
		exit 1
		;;
	esac
	shift
done

case "$PROMPT" in
dmenu|rofi) ;;
*)
	echo "无效 --prompt=$PROMPT（仅 dmenu|rofi）" >&2
	usage >&2
	exit 1
	;;
esac

run_root() {
	if [ "$(id -u)" -eq 0 ]; then
		"$@"
	elif command -v doas >/dev/null 2>&1; then
		doas "$@"
	elif command -v sudo >/dev/null 2>&1; then
		sudo "$@"
	else
		echo "需要 root（doas/sudo）" >&2
		exit 1
	fi
}

if [ "$PROMPT" = rofi ]; then
	if ! command -v rofi >/dev/null 2>&1; then
		echo "警告: 未找到 rofi，仍写入 prompt=rofi；请先 ./install.sh x11:rofi" >&2
	fi
	if ! command -v rofi-askpass >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/rofi-askpass" ]; then
		echo "警告: 未找到 rofi-askpass（x11:rofi 会安装到 ~/.local/bin）" >&2
	fi
	_theme="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/cde-dwm-password.rasi"
	if [ ! -f "$_theme" ]; then
		echo "警告: 缺少 $_theme" >&2
	fi
fi

if [ "$DO_BUILD" = 1 ]; then
	echo "==== mini-polkit（build） ===="
	(
		cd "$ROOT"
		make
		run_root make install
		make clean 2>/dev/null || true
	)
fi

BIN_DIR="${MINI_POLKIT_BIN:-$HOME/.local/bin}"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mini-polkit"
mkdir -p "$BIN_DIR" "$CFG_DIR"
install -m755 "$ROOT/mini-polkit-agent" "$BIN_DIR/mini-polkit-agent"
printf '%s\n' "$PROMPT" >"$CFG_DIR/prompt"
echo "prompt ← $CFG_DIR/prompt ($PROMPT)"
echo "agent  ← $BIN_DIR/mini-polkit-agent"
echo "完成。会话中运行: mini-polkit-agent &"
echo "切换后端: $0 --prompt=rofi --no-build   # 或 dmenu"
