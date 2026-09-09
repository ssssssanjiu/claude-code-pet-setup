# 截图

| 文件 | 用途 |
|---|---|
| `elicitation-with-pet-en.png` | 英文 README（落地页）首图：追问卡片 + 桌宠 |
| `elicitation-with-pet.png` | 同上的中文版，中文 README 首图 |
| `permission-bubble-en.png` | 权限卡片（英文），含破坏性操作警告 |
| `permission-bubble.png` | 同上的中文版 |
| `pet-states.png` | 桌宠四种可辨状态的图鉴 |

## 怎么拍的

卡片与桌宠均为**单窗口捕获**（`screencapture -l <windowID>`），只含窗口本身，
背景透明、不含任何桌面内容。首图是把卡片与桌宠两个窗口分别截图、
裁掉透明边后上下堆叠合成的——Clawd 原生只把卡片放在桌宠左右侧。

状态图鉴通过向 `127.0.0.1:23333/state` 投递状态后逐个截取宠物窗口得到。
只收录了静态帧下一眼可辨的四个状态：`thinking` / `working` / `juggling`
之间的差异主要在动效，静止画面几乎相同，列出来只会像凑数。

卡片里的项目名与会话短码来自真实运行，不含任何路径或个人信息。
