# 0012 — 开机 gate 哈希维护

## 解决什么错误

```
CMP170HX_POSTBOOT_GATE_FAIL: production module hash mismatch
```

## 方法

换模块后必须更新 **systemd 实际运行的那份**：

```
/usr/local/sbin/cmp170hx-postboot-gate      ← systemd 跑这份（改这份！）
~/tests/cmp170hx-postboot-gate.sh ← 只是副本，改它无效
```

```bash
NEW=$(sudo sha256sum /lib/modules/7.0.0-30-generic/updates/cmpunlocker/nvidia.ko | cut -d' ' -f1)
sudo sed -i "s/^PRODUCTION_SHA256=.*/PRODUCTION_SHA256=\"$NEW\"/" /usr/local/sbin/cmp170hx-postboot-gate
```

## 验证

```
systemctl status cmp170hx-postboot-gate        # active (exited) 0/SUCCESS
journalctl -u cmp170hx-postboot-gate | tail    # CMP170HX_POSTBOOT_GATE_OK ... memory_total_mib=81920 pcie_gen=2
```

完整全绿链（2026-09-01 04:57 实例）：

```
CMP170HX_POSTBOOT_GATE_HOT_CORRECTED
CMP170HX_POSTBOOT_GATE_LINK endpoint=1042 bridge=3042      ← Gen2
CMP170HX_POSTBOOT_GATE_CUDA_OK NVIDIA CMP 170HX ...
CMP170HX_POSTBOOT_GATE_OK memory_total_mib=81920 pcie_gen=2
```

## 依赖

无。

## 坑

- **两份脚本、不同 inode**——只改 tests 副本 = 白改（本次就是踩了这个）。
- gate 日志里 `LnkSta 2.5GT/s x4 downgraded` 是驱动加载前快照，gate retrain
  后才判 Gen2，不是失败。


## 2026-09-01 通用化验证（47 机裸部署发现的问题，已全部修复）

Mac 里的 gate/hot-load 原版在 47 机上连续暴露 5 处机器绑定，全部改为通用逻辑：

| 问题 | 修复 |
|---|---|
| `GPU_BDF="0000:81:00.0"` 写死 | `lspci -D -d 10de:2082` 自动探测 |
| 桥地址写死 80:03.0 | sysfs 亲缘推导：`basename $(dirname $(readlink -f /sys/bus/pci/devices/$GPU_BDF))` |
| `uname -r = 7.0.0-30-generic` 写死 | 模块路径用 `$(uname -r)` 拼，vermagic 动态比对 |
| 桥子设备数=1 写死（130 桥专用） | sysfs 枚举真实功能设备 + 检查全部属于 GPU 本设备 |
| IOMMU 隔离检查强制 | 有 iommu_group 才查（BIOS 未开 IOMMU 属正常） |
| fail() 定义在使用之后 | 移到脚本头部 |

验证结果：47 机 `GATE_OK memory_total_mib=81920 pcie_gen=2`（20:24:55）。
修改后的脚本在 Mac `deploy/` 目录，130/47 通用。
