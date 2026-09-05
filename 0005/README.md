# 0005 — WPR 低区锚定（GSP 固件搬家）

## 解决什么错误

unlock 后 WPR（GSP 固件镜像+堆）被布局到 79.4GB 高地址，高负载下不可靠：

```
Xid 1  : GSP task exception: illegal instruction (cause:0x2) @ pc:0x5b2b940
Xid 119: Timeout after 45s waiting for RPC response from GPU0 GSP
Xid 154: GPU recovery action -> OS Reboot
```

## 方法

`src/kernel/gpu/gsp/arch/turing/kernel_gsp_tu102.c` 的
`kgspPopulateWprMeta_TU102()`：布局从 `pWprMeta->fbSize` 向下生长——
**布局开始前把 fbSize 临时改成 40GB，算完还原真实值**：

```c
NvU64 _cmpRealFbSize = pWprMeta->fbSize;
if (_cmpRealFbSize > (40ULL << 30)) { pWprMeta->fbSize = (40ULL << 30); }
/* ...原有布局计算不动... */
pWprMeta->fbSize = _cmpRealFbSize;   /* 还原，GSP 知道真实 FB 大小 */
```

## 验证

```
CMP80_WPR_LOW: WPR laid out in low half: wprStart=0x9f2a00000 wprEnd=0x9fff00000
               heapOff=0x9f2b00000 heapSize=0xb800000
```
WPR 全落在 [~38.8G, 40G) 且 `heapSize=0xb800000`(184MB)。

## 依赖

- **0002**。

## 坑（全部实测踩过，别再试）

| 事项 | 结果 |
|---|---|
| 还原 `vgaWorkspaceOffset` 指回 80G 顶部 | ❌ `Xid 1 store access fault @ pc:0x4bff594` |
| 锚点 43.79G | ❌ 90 秒内硬崩（机器自重启） |
| 锚点 51.79G | ❌ Xid 62 PMU halt @90s |
| 锚点 **40G** | ✅ 采用 |
| 锚点 38G | ✅ 可用但浪费 ~2GiB（nvidia-smi 少 ~1.5G） |
| **堆 >184MB**（含 `RmGspFirmwareHeapSizeMB>184`、PER_GB 调大溢出 264MB） | ❌ **Booter 0x29 拒启**，GSP 4 连败→`No devices were found` |
| 源码公式与 modprobe 的 `RmGspFirmwareHeapSizeMB=184` 冲突 | 184 会**压住**公式，公式改了白改——两处必须一致 |
