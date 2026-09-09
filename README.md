# clawd-conduit

> 让桌面宠物真正「懂」你的 Claude Code 会话——15 个 hook 事件的完整接线方案。

[English](./README.en.md) · macOS · MIT

<p align="center">
  <img src="assets/elicitation-with-pet.png" alt="中文追问卡片与桌宠" width="330">
  <img src="assets/elicitation-with-pet-en.png" alt="英文追问卡片与桌宠" width="330">
</p>
<p align="center">
  <sub>Claude Code 让你在几个方案里挑一个时，卡片直接弹在桌面上——桌宠同时切换成举灯泡的「等待输入」姿态。<br>
  界面语言跟随 Clawd 设置，中英文皆可</sub>
</p>

## 这是什么

[Clawd on Desk](https://github.com/rullerzhou-afk/clawd-on-desk) 是一只会盯着
AI 编程 agent 的桌面宠物。它自带 Claude Code 集成，装完开箱可用。

这个仓库是**在它之上的一层完整接线**：把 Claude Code 生命周期里的 15 个 hook
事件一次性全部接通，配上一个自写的系统通知脚本、一套幂等的安装/卸载工具，
以及三个月日常使用后沉淀下来的参数取舍。

差别在信息粒度：接得少时，宠物大致知道你「在忙 / 不忙」；接满 15 个之后，
它区分得出你是在**调工具**、**工具失败了**、**子 agent 在并行**、
**上下文正在压缩**，还是**卡在一个确认上等你点头**。

**最值钱的是最后一个。**

## 它真正解决的问题

Claude Code 干长任务时，你会离开终端——去看文档、回消息、倒杯水。
然后回来发现它在三分钟前就停下了，等你点一个「允许」。

这套配置把那三分钟压成零：

- 权限请求直接弹成桌面卡片，`Cmd+Shift+Y` 允许、`Cmd+Shift+N` 拒绝，**不用切窗口**
- 卡片**永不自动消失**（`permissionBubbleAutoCloseSeconds: 0`）——超时自动关闭是最坑的默认值，
  你以为拒绝了，其实只是回落到了终端提示
- 任务完成闪 Dock + 提示音，人在别的窗口也接得住
- 工具失败当场变脸，不用回头翻 scrollback 找哪一步炸了

<p align="center">
  <img src="assets/permission-bubble.png" alt="带破坏性操作警告的权限卡片" width="300">
</p>
<p align="center">
  <sub>命令里有 <code>rm -rf</code> 时，卡片会自己亮出 <b>Destructive action</b> 警告条</sub>
</p>

## 工作原理

Claude Code 在会话生命周期的关键节点会触发 hook。这套配置把其中 **14 个**用
`command` 类型转发给 Clawd 随附的 `clawd-hook.js`，另外 **1 个**（权限请求）
走 `http` 类型直连 Clawd 的本地端口。

```
Claude Code                          Clawd on Desk
    │
    ├─ SessionStart ─┐
    ├─ PreToolUse  ──┤  command hook
    ├─ Stop        ──┼─→ clawd-hook.js ──→ POST 127.0.0.1:23333/state ──→ 改变宠物状态
    ├─ …（共 14 个）─┘        (async, 5s 超时，不阻塞会话)
    │
    └─ PermissionRequest ─→ HTTP hook ──→ POST 127.0.0.1:23333/permission
                                              (阻塞，600s 超时)
                                                    │
                                          弹出卡片 ─┴─→ 你点 Allow / Deny
                                                         └─→ 决定回传，会话继续
```

两条通道的区别是**要不要等你**。状态事件是单向广播，发完就走；
权限请求要停下来等一个人类决定，所以它是唯一阻塞的一条。

### 事件与宠物状态的对应

下表取自 Clawd 的 `clawd-hook.js`（`EVENT_TO_STATE`），不是猜的：

| 事件 | 宠物状态 | 触发时机 |
|---|---|---|
| `SessionStart` | `idle` | 会话开始。本配置额外挂了 `open -ga` 顺手拉起 app |
| `UserPromptSubmit` | `thinking` | 你按下回车提交 |
| `PreToolUse` | `working` | 每次调用工具前 |
| `PostToolUse` | `working` | 工具成功返回 |
| `PostToolUseFailure` | `error` | 工具报错 |
| `SubagentStart` | `juggling` | 子 agent 启动——字面意义上开始「杂耍」 |
| `SubagentStop` | `working` | 子 agent 结束 |
| `PreCompact` | `sweeping` | 上下文压缩前，宠物开始「打扫」 |
| `PostCompact` | `thinking` | 压缩完成。注意**不是** `attention`——压缩不等于任务完成 |
| `Stop` | `attention` | 主回合正常结束，来叫你 |
| `StopFailure` | `error` | 回合异常终止 |
| `Notification` | `notification` | Claude 需要你注意 |
| `Elicitation` | `notification` | Claude 反过来问你问题（就是首图那张卡片） |
| `SessionEnd` | `sleeping` | 会话结束，宠物去睡 |
| `PermissionRequest` | —— | 走 HTTP 通道，直接弹卡片 |

有个细节值得一提：Claude Code 启动子 agent 时，某些版本只发
`PreToolUse(Task)` 而不发 `SubagentStart`。Clawd 对此做了兼容，
识别到 `Task` / `Agent` 工具名就切 `juggling`——所以并行任务的状态不会漏。

### 为什么模板里写绝对路径

```json
"command": "\"/opt/homebrew/bin/node\" \"/Applications/Clawd on Desk.app/…/clawd-hook.js\" Stop"
```

hook 由 Claude Code 在**非登录 shell** 里执行，`PATH` 可能不含 Homebrew 目录。
写成 `node` 会直接 command not found，而且因为配了 `async: true`，
你连报错都看不到——表现就是宠物安静地不动了。`install.sh` 会自动探测并填好路径。

路径里有空格（`Clawd on Desk.app`），所以命令里每一段都必须带引号。

## 快速开始

```bash
# 1. 先装 Clawd on Desk 本体（本仓库不含它，也不重新分发它）
#    https://github.com/rullerzhou-afk/clawd-on-desk/releases

# 2. 套上这份配置
git clone https://github.com/ssssssanjiu/clawd-conduit.git
cd clawd-conduit
bash install.sh
```

新开一个 Claude Code 会话即可生效。

### install.sh 做了什么

1. **定位 Clawd** —— 依次查 `/Applications`、`~/Applications`，
   再兜底用 `mdfind` 按 bundle id `com.clawd.on-desk` 搜。找不到会明确报错并给下载链接。
2. **定位 node** —— 依次查 `/opt/homebrew/bin/node`、`/usr/local/bin/node`、`command -v node`。
3. **备份** —— 把现有 `settings.json` 复制成 `settings.json.bak.<时间戳>`。
4. **合并 hook 配置** —— 用占位符模板填入真实路径后写入。
   **逐事件保留你原有的其他 hook**，只覆盖本仓库自己写过的条目。
5. **安装通知脚本** —— 复制到 `~/.claude/hooks/` 并挂到 `Notification` 事件（可跳过）。
6. **校验** —— 用 `python3 -c "json.load(...)"` 确认写出来的 JSON 语法没坏。

**可以重复运行。** 第二次执行是覆盖而不是叠加，`clawd-hook.js` 的出现次数恒为 14。

### 验证是否生效

```bash
# 1. 15 个事件都挂上了吗
python3 -c "import json;h=json.load(open('$HOME/.claude/settings.json'))['hooks'];\
print(len([k for k,v in h.items() if 'clawd' in json.dumps(v).lower() or '23333' in json.dumps(v)]),'个事件')"

# 2. Clawd 的本地服务在监听吗
lsof -nP -iTCP:23333 -sTCP:LISTEN

# 3. hook 脚本路径是真的吗
ls -l "/Applications/Clawd on Desk.app/Contents/Resources/app.asar.unpacked/hooks/clawd-hook.js"
```

第 1 条应输出 `15 个事件`，第 2 条应看到 `Clawd on Desk` 进程。
都对上之后，新开一个会话随便发一句话，宠物应当从 `idle` 变 `thinking`。

## 常见问题与排查

<details>
<summary><b>宠物完全没反应</b></summary>

按顺序查三件事：

1. **node 路径错了。** 这是最常见的原因。hook 是 `async` 的，失败不会有任何提示。
   直接手动跑一次看报错：
   ```bash
   echo '{"session_id":"t","hook_event_name":"Stop"}' | \
     /opt/homebrew/bin/node "/Applications/Clawd on Desk.app/Contents/Resources/app.asar.unpacked/hooks/clawd-hook.js" Stop
   ```
2. **Clawd 没在跑。** `pgrep -f "Clawd on Desk"` 应有输出。
3. **配置没重新加载。** hook 在会话启动时读取，改完要**新开会话**，
   当前这个不会热更新。
</details>

<details>
<summary><b>权限卡片不弹</b></summary>

- Clawd 设置里 `permissionBubblesEnabled` 要为 `true`
- `hideBubbles` 要为 `false`
- 端口 23333 要在监听（见上面验证第 2 条）
- 如果你在用 Claude Code 的 `--dangerously-skip-permissions` 或已把该操作加进
  allowlist，压根不会产生权限请求——这不是故障
</details>

<details>
<summary><b>通知气泡不弹，但权限卡片正常</b></summary>

八成是把 `notificationBubbleAutoCloseSeconds` 设成了 `0`。

**这两种气泡的 `0` 含义相反**：权限气泡的 `0` 是「永不自动关闭」，
通知气泡的 `0` 是 `enabled: false`，也就是**功能直接关掉**。
想让通知气泡久留，应该往大了设（上限 3600），不是设 0。

细节见 [docs/recommended-prefs.md](./docs/recommended-prefs.md)。
</details>

<details>
<summary><b>装完之后我原来的 hook 没了</b></summary>

不应该发生——合并逻辑逐事件保留非本仓库的条目，卸载往返测试也验证过
能完整还原。真出现了，用安装时自动生成的备份恢复：

```bash
ls -t ~/.claude/settings.json.bak.* | head -1   # 找最近一份
```

并且请开个 issue 附上你原来的配置结构。
</details>

<details>
<summary><b>我同时在用 Codex / 其他 agent</b></summary>

不冲突。Clawd 按 agent 分别跟踪会话，本仓库只写 Claude Code 这一侧的
`~/.claude/settings.json`，不碰 `~/.codex/` 之类的其他配置。

Claude Code 的**子 agent 也会要权限**——记得把 Clawd 设置里的
`subagentPermissionsEnabled` 打开，否则子 agent 的请求不弹卡片，你会莫名其妙卡住。
</details>

## 兼容性

| 项 | 要求 |
|---|---|
| 系统 | macOS（通知脚本依赖 `osascript`；hook 配置本身跨平台，但未在 Windows/Linux 验证） |
| Clawd on Desk | v0.10.0 起验证过，v1.0.0 为当前测试版本 |
| Claude Code | 需支持 `PermissionRequest` 的 `http` 类型 hook |
| node | 任意版本，仅用于执行 Clawd 自带的 hook 脚本 |
| python3 | 系统自带即可（安装脚本与通知脚本使用） |

> Clawd 设置里的 `manageClaudeHooksAutomatically` 建议保持开启——
> Clawd 升级后会自动修正 hook 里的 app 路径，省得每次升级都要重跑 `install.sh`。

## 里面有什么

```
├── install.sh                        # 自动探测路径 + 幂等合并配置
├── uninstall.sh                      # 干净摘除，保留你其他的 hook
├── settings/
│   └── clawd-hooks.template.json     # 15 个事件的配置模板（路径用占位符）
├── hooks/
│   └── notify-input-needed.py        # macOS 横幅 + Glass 提示音
└── docs/
    ├── hook-events.md                # 15 个事件逐条解释，含为什么用绝对路径
    └── recommended-prefs.md          # 实际在用的 Clawd 设置及理由
```

## 关于那个通知脚本

`hooks/notify-input-needed.py`，20 行：

Claude Code 触发 `Notification` 事件时，它从 stdin 读事件 JSON，取出 message，
用 `osascript` 弹一条系统横幅并播放 Glass 提示音。

它和 Clawd 的气泡是**互补**关系，不是替代：Clawd 的气泡在屏幕上、能交互；
系统横幅会进通知中心，你在全屏应用里也能收到。两个都开，漏掉的概率最低。

之所以需要它，是因为 Clawd 的「被动通知气泡」只服务 Codex / Kimi 这类
无决策通道的 agent（见 `passive-notify-entry.js`）。Claude Code 走的是带决策通道的
路径，屏幕上只会出现权限卡片和追问卡片两种——纯状态变化不会有气泡。
这个脚本补的就是那个缺口。

`INSTALL_NOTIFY=0 bash install.sh` 可以跳过它。

## 卸载

```bash
bash uninstall.sh
```

只摘 hook 配置，不动 Clawd 这个 app 本身。执行前也会自动备份。
往返测试验证过：卸载后 `settings.json` 与安装前**逐字节一致**。

## 环境变量

| 变量 | 默认 | 用途 |
|---|---|---|
| `CLAWD_APP` | 自动探测 | Clawd.app 路径 |
| `NODE_BIN` | 自动探测 | node 可执行文件路径 |
| `CLAUDE_SETTINGS` | `~/.claude/settings.json` | 换个 settings 文件（便于试） |
| `CLAUDE_HOOK_DIR` | `~/.claude/hooks` | 换个 hook 目录 |
| `INSTALL_NOTIFY` | `1` | 设 `0` 跳过通知脚本 |

## 上游项目

宠物本体是 **[Clawd on Desk](https://github.com/rullerzhou-afk/clawd-on-desk)**
（[@rullerzhou-afk](https://github.com/rullerzhou-afk)，AGPL-3.0-only）。
用这套配置前需要先装它。觉得好用的话，去给上游点个 star。

本仓库不包含也不重新分发 Clawd 的任何代码或二进制，只有配置模板、安装脚本和文档。

## 许可

MIT。详见 [LICENSE](./LICENSE) 与 [NOTICE.md](./NOTICE.md)。
