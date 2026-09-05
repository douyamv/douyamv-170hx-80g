# 9999 — 硬件层操作规程

## MMU fault 风暴后的恢复

**症状**：`nvidia-smi` 报 `Unable to determine the device handle / No devices
were found`；dmesg 有 Xid 45（GPU fallen off bus）+ Xid 154（recovery=OS Reboot）。

**规程**：

1. 先试一次软 reboot（`sudo reboot`）——轻度残留有效；
2. 软 reboot 后仍 `No devices were found` → **必须物理断电**：
   拔电源线 ≥30 秒（放电）再上电；
3. 上电后等 ~3-5 分钟（GSP 初始化慢），SSH 连不上就再等，别连续重启。

**为什么 reboot 不够**：GPU 的 PCIe 辅助供电在软重启中不断，GSP/MMU 内部
状态（SRAM、TLB、FLR 覆盖不到的寄存器）残留——只有整机断电能清。

## 已确认的硬件事实（写死，别再重新验证）

- 卡：GA100 [CMP 170HX]，devId **0x2082**（变体 0x20C2 同套补丁）
- HBM：Samsung XA2-8HI 16Gb 物理 die，**熔丝降级为 8Gb 寻址**（→0013）
- 20 FBPA × 4096 MiB = 80.00 GiB（几何已开满）
- PCIe：x16 物理链路，实跑 Gen2（gate 保它）
- 47 机（<LAN-B>）同卡同补丁可复现大部分行为，但**4KB override 等
  个别补丁两机不通用**——换机器验证前先读本库对应编号的"坑"。

## 支撑文件

- `hotreset.sh` — 热复位辅助脚本
