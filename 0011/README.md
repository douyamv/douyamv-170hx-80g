# 0011 — sysmembar A/B 定案（保留真 bar）

## 结论（2026-09-01 定案）

stub 与真 sysmembar 在 >40G 行为上**完全相同**——sysmembar 不是 >40G 故障的根因。

| 构建 | sysmembar | 35G | 38G |
|---|---|---|---|
| ed15e0e1（旧二进制） | stub | ✅ PASS | ❌ FAULT_PDE |
| 8ee80770（干净构建） | **真 RPC** | ✅ PASS Xid=0 | ❌ FAULT_PDE (GRAPHICS @0xc5a000000) |

**决定：保留真 sysmembar**。stub 属"假成功"（返回 OK 但 bar 没发，CE/GFX 视图不一致
风险），无任何收益，已从源码移除。

## 当初为什么卡了这么久（与 0015 联动）

- 源码早已恢复真 bar，但部署的二进制一直是旧 stub → 归因于"构建缓存"
- 真相（0015）：干净重建的模块在**被遮蔽的 conf** 下 Booter 0x29 拒启，
  于是旧二进制被反复回deploy，看起来像"构建缓存"
- conf 唯一化后，干净构建（8ee80770）立即正常启动

## 验证方法

```
strings nvidia.ko | grep -c SYSMEMBAR_SKIP   # 构建/部署后必须=0
sudo dmesg | grep -c SYSMEMBAR_SKIP          # 开机后必须=0
```

## 依赖

无。影响 0005/0013 的症状判定（Xid 119 超时已由 0005 WPR低区解决，与 bar 无关）。
