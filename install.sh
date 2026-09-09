#!/usr/bin/env bash
# 把 Clawd on Desk 接进 Claude Code：15 个 hook 事件 + 权限拦截 + 系统通知
# 幂等：重复运行只会覆盖自己写的条目，不会重复叠加。
set -euo pipefail

BLUE=$'\033[34m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
info() { echo "${BLUE}==>${RESET} $*"; }
ok()   { echo "${GREEN} ✓${RESET} $*"; }
warn() { echo "${YELLOW} !${RESET} $*"; }
die()  { echo "${RED} ✗${RESET} $*" >&2; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
HOOK_DIR="${CLAUDE_HOOK_DIR:-$HOME/.claude/hooks}"
INSTALL_NOTIFY="${INSTALL_NOTIFY:-1}"

[[ "$(uname -s)" == "Darwin" ]] || die "这套配置目前只适配 macOS（notify hook 依赖 osascript）。"

# ---------- 1. 定位 Clawd ----------
info "定位 Clawd on Desk"
CLAWD_APP="${CLAWD_APP:-}"
if [[ -z "$CLAWD_APP" ]]; then
  for c in "/Applications/Clawd on Desk.app" "$HOME/Applications/Clawd on Desk.app"; do
    [[ -d "$c" ]] && CLAWD_APP="$c" && break
  done
fi
if [[ -z "$CLAWD_APP" ]]; then
  CLAWD_APP="$(mdfind "kMDItemCFBundleIdentifier == 'com.clawd.on-desk'" 2>/dev/null | head -1 || true)"
fi
[[ -n "$CLAWD_APP" && -d "$CLAWD_APP" ]] || die "没找到 Clawd on Desk。先装它：https://github.com/rullerzhou-afk/clawd-on-desk/releases"

HOOK_JS="$CLAWD_APP/Contents/Resources/app.asar.unpacked/hooks/clawd-hook.js"
[[ -f "$HOOK_JS" ]] || die "找到了 app 但缺 clawd-hook.js，安装可能不完整：$HOOK_JS"
CLAWD_VER="$(defaults read "$CLAWD_APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo '未知')"
ok "Clawd on Desk v$CLAWD_VER  ${DIM}$CLAWD_APP${RESET}"

# ---------- 2. 定位 node ----------
info "定位 node"
NODE_BIN="${NODE_BIN:-}"
if [[ -z "$NODE_BIN" ]]; then
  for c in /opt/homebrew/bin/node /usr/local/bin/node "$(command -v node 2>/dev/null || true)"; do
    [[ -n "$c" && -x "$c" ]] && NODE_BIN="$c" && break
  done
fi
[[ -n "$NODE_BIN" ]] || die "没找到 node。装一个：brew install node"
ok "node $("$NODE_BIN" -v)  ${DIM}$NODE_BIN${RESET}"
# hook 由 Claude Code 在非登录 shell 里执行，PATH 可能很干净，所以模板里写绝对路径。

# ---------- 3. 备份 ----------
mkdir -p "$(dirname "$SETTINGS")" "$HOOK_DIR"
if [[ -f "$SETTINGS" ]]; then
  BACKUP="$SETTINGS.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$SETTINGS" "$BACKUP"
  ok "已备份 ${DIM}$BACKUP${RESET}"
else
  echo '{}' > "$SETTINGS"
  ok "新建 $SETTINGS"
fi

# ---------- 4. 合并 hooks ----------
info "写入 hook 配置"
TEMPLATE="$HERE/settings/clawd-hooks.template.json" \
SETTINGS="$SETTINGS" NODE_BIN="$NODE_BIN" HOOK_JS="$HOOK_JS" \
python3 - <<'PY'
import json, os, sys, collections

tpl_path = os.environ['TEMPLATE']; settings_path = os.environ['SETTINGS']
node_bin = os.environ['NODE_BIN']; hook_js = os.environ['HOOK_JS']

def fill(o):
    if isinstance(o, str):
        return o.replace('{{NODE_BIN}}', node_bin).replace('{{CLAWD_HOOK_JS}}', hook_js)
    if isinstance(o, list):  return [fill(x) for x in o]
    if isinstance(o, dict):  return {k: fill(v) for k, v in o.items()}
    return o

tpl = fill(json.load(open(tpl_path)))['hooks']

try:
    settings = json.load(open(settings_path), object_pairs_hook=collections.OrderedDict)
except (json.JSONDecodeError, FileNotFoundError) as e:
    sys.exit(f'settings.json 解析失败，已保留备份，未做改动：{e}')
if not isinstance(settings, dict):
    sys.exit('settings.json 顶层不是对象，已中止。')

hooks = settings.setdefault('hooks', collections.OrderedDict())

def is_ours(entry):
    s = json.dumps(entry)
    return 'clawd-hook.js' in s or 'Clawd on Desk' in s or '127.0.0.1:23333' in s

added = replaced = kept_foreign = 0
for event, entries in tpl.items():
    existing = hooks.get(event, [])
    if not isinstance(existing, list):
        existing = []
    foreign = [e for e in existing if not is_ours(e)]   # 别人的 hook 一律保留
    kept_foreign += len(foreign)
    if len(foreign) != len(existing):
        replaced += 1
    else:
        added += 1
    hooks[event] = foreign + entries

json.dump(settings, open(settings_path, 'w'), indent=2, ensure_ascii=False)
open(settings_path, 'a').write('\n')
print(f'   {len(tpl)} 个事件已写入（新增 {added} / 覆盖 {replaced}），保留了 {kept_foreign} 条你原有的其他 hook')
PY
ok "hook 配置完成"

# ---------- 5. 系统通知 hook（可选） ----------
if [[ "$INSTALL_NOTIFY" == "1" ]]; then
  info "安装系统通知 hook"
  cp "$HERE/hooks/notify-input-needed.py" "$HOOK_DIR/notify-input-needed.py"
  chmod +x "$HOOK_DIR/notify-input-needed.py"
  SETTINGS="$SETTINGS" python3 - <<'PY'
import json, os, collections
p = os.environ['SETTINGS']
s = json.load(open(p), object_pairs_hook=collections.OrderedDict)
entries = s.setdefault('hooks', {}).setdefault('Notification', [])
cmd = 'python3 ~/.claude/hooks/notify-input-needed.py'
if not any(cmd in json.dumps(e) for e in entries):
    entries.insert(0, {'hooks': [{'type': 'command', 'command': cmd}]})
    print('   已挂到 Notification 事件')
else:
    print('   已存在，跳过')
json.dump(s, open(p, 'w'), indent=2, ensure_ascii=False); open(p, 'a').write('\n')
PY
  ok "通知 hook 完成 ${DIM}（横幅 + Glass 提示音）${RESET}"
fi

# ---------- 6. 收尾 ----------
echo
python3 -c "import json;json.load(open('$SETTINGS'))" && ok "settings.json 语法校验通过"
open -ga "Clawd on Desk" 2>/dev/null || warn "Clawd 没能自动启动，手动开一下"
echo
echo "${GREEN}装好了。${RESET}新开一个 Claude Code 会话，宠物就会跟着你的操作动起来。"
echo "${DIM}回滚：bash uninstall.sh，或还原上面那份 .bak${RESET}"
