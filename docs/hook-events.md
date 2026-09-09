# 15 个 hook 事件都在干什么

Claude Code 在生命周期的关键节点会触发 hook。这套配置把其中 14 个用
`command` 类型转发给 Clawd 随附的 `clawd-hook.js`，另外 1 个（权限请求）
走 `http` 类型直连 Clawd 的本地端口。

事件越全，宠物的状态就越贴近你终端里真正发生的事——这也是这套配置和
「装完就完事」的区别。

## 命令型：14 个

| 事件 | 触发时机 | 对宠物意味着什么 |
|---|---|---|
| `SessionStart` | 会话开始 | 唤醒宠物；这一条还额外挂了 `open -ga` 顺手把 app 拉起来 |
| `UserPromptSubmit` | 你按下回车提交 | 从待机切到「在干活」 |
| `PreToolUse` | 每次调用工具前 | 工具活动的开始信号 |
| `PostToolUse` | 工具成功返回 | 工具活动的结束信号 |
| `PostToolUseFailure` | 工具报错 | 出错状态——不用盯屏幕也知道翻车了。**瞬时**，约一秒后自动回落 |
| `Notification` | Claude 需要你注意 | 冒泡提醒；本仓库的通知脚本也挂在这里 |
| `Elicitation` | Claude 反过来问你问题 | 提示你去回答 |
| `Stop` | 主回合正常结束 | 完成状态 + 可选的任务栏闪烁和提示音 |
| `StopFailure` | 回合异常终止 | 失败状态 |
| `SubagentStart` | 子 agent 启动 | 并行任务开始 |
| `SubagentStop` | 子 agent 结束 | 并行任务收尾 |
| `PreCompact` | 上下文压缩前 | 压缩前的状态切换 |
| `PostCompact` | 上下文压缩后 | 压缩完成 |
| `SessionEnd` | 会话结束 | 回到待机 |

全部配置为 `"async": true` + `"timeout": 5`：hook 在后台跑，不阻塞你的会话，
5 秒不返回就放弃。宠物再怎么样也不该拖慢 Claude Code。

## HTTP 型：权限请求

```json
"PermissionRequest": [
  { "matcher": "", "hooks": [
      { "type": "http", "url": "http://127.0.0.1:23333/permission", "timeout": 600 }
  ]}
]
```

这条是整套配置里最有价值的一个，也是唯一不走 `command` 的。

Claude Code 要执行敏感操作时，会把权限请求 POST 到 `127.0.0.1:23333`——
Clawd 在本地监听的端口。宠物弹出一张卡片，你直接点「允许 / 拒绝」，
或者用全局快捷键，**不用切回终端窗口**。

`timeout` 是 **600 秒**（其余都是 5 秒）：这条要等真人做决定，得给足时间。
超时后 Claude Code 回落到终端里的原生权限提示，不会卡死。

端口是本机回环地址，不出网。

## 为什么写绝对路径

模板里 node 和 hook 脚本都是绝对路径：

```json
"command": "\"/opt/homebrew/bin/node\" \"/Applications/Clawd on Desk.app/.../clawd-hook.js\" Stop"
```

hook 由 Claude Code 在非登录 shell 里执行，`PATH` 可能不含 Homebrew 目录，
写 `node` 会直接 command not found，而且因为是 `async` 你根本看不到报错——
宠物只是安静地不动了。`install.sh` 会自动探测并填好这两个路径。

路径里有空格（`Clawd on Desk.app`），所以命令里的每一段都必须带引号。
