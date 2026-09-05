# 0003 — BAR1 64GB 窗口

## 解决什么错误

BAR1 默认 256MB，CPU 侧映射不了大显存区间，大块操作无从谈起。

## 方法（开机早期由驱动改写，日志可见前后对比）

```
CMP BAR1: before CYA=0x00000026 CFG=0x80000000 CAP=0x00000400
CMP BAR1: after  CYA=0x00000030 CFG=0x8000000a CAP=0x001ffc00
CMP BAR1: resize enabled, will attempt up to 64 GB
CMP BAR1: final size = 65536 MB
```

| 寄存器 | 前 | 后 | 作用 |
|---|---|---|---|
| CYA | 0x26 | 0x30 | BAR1 尺寸允许位 |
| CFG | 0x80000000 | 0x8000000a | 窗口大小编码 |
| CAP | 0x400 | 0x1ffc00 | 能力上限（64GB） |

## 验证

dmesg 出现 `CMP BAR1: final size = 65536 MB`；`lspci -vvv` 里 endpoint BAR1 报 64GB。

## 依赖

- **0002**（几何先开，窗口才有意义）。

## 坑

- gate 里 PCIe 抓的 `LnkSta: 2.5GT/s x4 (downgraded)` 是**驱动加载前**快照，
  gate 自己 retrain 后按 Gen2 判定——不是故障，别误判。


## ⚠️ 平台依赖（2026-09-01 在 目标机B实测）

模块侧改动（CYA/CFG/CAP）在目标机B上同样生效（日志 `after CYA=0x30 CFG=0x8000000a CAP=0x001ffc00`
与 130 完全一致），但**最终 BAR1 = 512MB**——47 的消费级主板（Intel Raptor Lake PEG）
BIOS 没有预留足够的 64 位 MMIO 窗口给 64GB BAR。

要 64GB BAR1 需要 BIOS 打开 `Above 4G Decoding`（+ Resizable BAR）。
GPU 侧推理不受影响（走 GPU VA，不用 CPU BAR1）；只影响 CPU 直接 mmap 大段显存的场景。
目标机A（服务器板）默认就给了 65536MB。
