# 我实际在用的 Clawd 设置

`install.sh` **不会**动这些——它们是个人口味，改起来也就是在 Clawd 设置面板里点几下。
下面是我跑了三个月之后留下的配置，附上为什么。

配置文件位置（想直接看/改的话）：
`~/Library/Application Support/clawd-on-desk/clawd-prefs.json`
改之前先退出 Clawd，否则会被内存里的状态覆盖回去。

## 值得开的

| 设置 | 值 | 为什么 |
|---|---|---|
| `permissionBubblesEnabled` | `true` | 整套配置的核心。不开的话 `PermissionRequest` 那条 hook 就白配了 |
| `manageClaudeHooksAutomatically` | `true` | Clawd 升级后会自动修正 hook 路径。**强烈建议开** |
| `sessionHudEnabled` | `true` | 多会话并行时，HUD 是唯一能一眼看清谁在跑的东西 |
| `sessionHudShowContextUsage` | `true` | 上下文用量。快满了能提前收尾，别等它自动压缩 |
| `flashTaskbarOnComplete` | `true` | 任务完成闪一下 Dock，切出去干别的也不会错过 |
| `soundMuted` | `false` | 配合下面的通知脚本，声音是最省心的信号 |

## 关键的超时参数

| 设置 | 我的值 | 说明 |
|---|---|---|
| `permissionBubbleAutoCloseSeconds` | `0` | **0 = 永不自动关闭**。权限卡片自己消失是最坑的——你以为拒绝了，其实是超时回落 |
| `notificationBubbleAutoCloseSeconds` | `6` | 普通通知 6 秒够看清了 |
| `sessionStaleMs` | `600000`（10 分钟） | 超过这个时间没信号就标记为陈旧 |
| `workingStaleMs` | `300000`（5 分钟） | 「工作中」状态卡死超过 5 分钟基本就是真卡了 |

## 快捷键

```json
"shortcuts": {
  "togglePet":        "CommandOrControl+Shift+Alt+C",
  "permissionAllow":  "CommandOrControl+Shift+Y",
  "permissionDeny":   "CommandOrControl+Shift+N"
}
```

`Cmd+Shift+Y` / `Cmd+Shift+N` 是提效关键——权限卡片弹出来时手不用离开键盘，
也不用把鼠标移过去点。用熟了之后确认一次操作大概半秒。

## 多 agent 并存

Clawd 不只认 Claude Code。我同时开了：

```json
"agents": {
  "claude-code": { "enabled": true, "permissionsEnabled": true, "subagentPermissionsEnabled": true },
  "codex":       { "enabled": true, "permissionsEnabled": true, "permissionMode": "intercept" }
}
```

`subagentPermissionsEnabled` 值得单独说：Claude Code 的子 agent 也会要权限，
不开这个的话子 agent 的请求不会弹卡片，你会莫名其妙地卡住。

其余十几个（gemini-cli、cursor-agent、copilot-cli……）我全关了。
只开你真在用的，宠物的状态才有信噪比。

## v1.0.0 之后新增的

升到 1.0.0 会多出一批配置项，几个值得看的：

- `recapEnabled` — 会话回顾
- `sessionHudShowQuota` / `quotaRingDisplayMode` — HUD 上显示额度环
- `claudeQuotaCollectionEnabled` — 默认 `false`，要显示额度得手动开
- `permissionAutomationMode` — 默认 `"off"`。**建议保持 off**，权限自动化听着香，
  但把「确认」这一步交给规则引擎，等于放弃了这套配置最大的价值
- `freeRoam` / `fullscreenOverlay` — 宠物自由移动、全屏时是否浮在最上层
- `petTint` / `petAccessory` — 换色和配饰
- Footprints — 本地活动统计，纯本地存储，不联网
