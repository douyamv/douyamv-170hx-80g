# 0002 — 80G 几何解锁（CFG1 / LMR / SS / CSTATUS）

## 解决什么错误

出厂把 80G 物理 HBM2e 降级成 10G 上限（后经寄存器恢复到可显示 40G）。
`nvidia-smi` 只见 81920 之外的小数字；CSTATUS 每 FBPA 报 8Gb die。

## 方法（经 0001 的 HS fire 写 BAR0 寄存器）

| 寄存器 | BAR0 地址 | 40G 值 | **80G 值** | 含义 |
|---|---|---|---|---|
| CFG1 | `0x9A0204` | 0x02669000 | **0x02779000** | HBM 地址译码几何（差异位 0x110000，打开全部 FBPA 高位寻址） |
| LMR | — | — | **0x28B** | Local Memory Range，物理内存顶 |
| SS0 / SS1 | — | — | 0x88888888 / 0x00000008 | stack 尺寸/步进 |
| CSTATUS | `0x9A020C` 等逐 FBPA | 0x800 | **0x1000** | 每 FBPA 容量 4096 MiB；20 × 4GiB = 80GiB |

## 验证

- gate：`POST-WRITE ... CFG1=0x02779000 LMR=0x0000028b`
- `nvidia-smi --query-gpu=memory.total` → **81920 MiB**
- 逐 FBPA 读容量：`cstatus.c`（见本目录）

## 依赖

- **0001**（HS 通道）——没有它寄存器写不进去。

## 坑

- 只改 CFG1 不改 LMR：几何开了但范围没跟上，高区不可达。
- 写完必须整机重启让驱动按新几何枚举，热加载不生效。

## 支撑文件

- `cstatus.c` — 逐 FBPA 容量寄存器读取工具
