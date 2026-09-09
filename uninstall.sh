#!/usr/bin/env bash
# 从 ~/.claude/settings.json 里摘掉 Clawd 相关的 hook，保留你其他的配置。
set -euo pipefail
GREEN=$'\033[32m'; DIM=$'\033[2m'; RESET=$'\033[0m'
SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
HOOK_DIR="${CLAUDE_HOOK_DIR:-$HOME/.claude/hooks}"
[[ -f "$SETTINGS" ]] || { echo "没有 $SETTINGS，无事可做。"; exit 0; }

cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d-%H%M%S)"
SETTINGS="$SETTINGS" python3 - <<'PY'
import json, os, collections
p = os.environ['SETTINGS']
s = json.load(open(p), object_pairs_hook=collections.OrderedDict)
hooks = s.get('hooks', {})

def is_ours(e):
    t = json.dumps(e)
    return ('clawd-hook.js' in t or 'Clawd on Desk' in t or '127.0.0.1:23333' in t
            or 'notify-input-needed.py' in t)

removed = 0
for event in list(hooks):
    entries = hooks[event]
    if not isinstance(entries, list): continue
    keep = [e for e in entries if not is_ours(e)]
    removed += len(entries) - len(keep)
    if keep: hooks[event] = keep
    else:    del hooks[event]
if not hooks: s.pop('hooks', None)

json.dump(s, open(p, 'w'), indent=2, ensure_ascii=False); open(p, 'a').write('\n')
print(f'   移除 {removed} 条 hook 条目')
PY
rm -f "$HOOK_DIR/notify-input-needed.py"
echo "${GREEN}已卸载。${RESET}${DIM}Clawd on Desk 这个 app 本身没有动，要删请自行拖进废纸篓。${RESET}"
