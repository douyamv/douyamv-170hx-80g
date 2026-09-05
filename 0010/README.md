# 0010 — PTE 池最小预留（192MB）

## 解决什么错误

页表池按需增长（每次映射加一点）会在 **38-40GiB 边界附近把 GSP 拖死**
（增量 PMA 流量 + 池扩容竞争）。改成首次 reserve 就把整个池建满，
之后每次映射只是 free-list 查表，零 PMA 流量。

## 方法

`gpu_vaspace.c` `rmMemPoolReserve()` 调用前（devId 0x2082）：

```c
NvU32 mb = 0;
if (osReadRegistryDword(pGpu, "RmCmp170hxPtePoolReserveMB", &mb) == NV_OK && mb) {
    NvU64 bytes = (NvU64)mb << 20;
    if (poolSize < bytes) poolSize = bytes;
}
```

modprobe：`RmCmp170hxPtePoolReserveMB=192`（当前值）。

## 验证

（来自 v3-final 模块同源代码）`SEC2_DEBUG_PTE_POOL: begin/done bytes=... status=0x0`；
a95kqS 树上此路径静默生效，间接验证 = 大 VA reserve 后不再出现 38-40G 边界 Xid 119。

## 依赖

- **0009**（池的口径先改对，再谈总量）。

## 坑

- ⚠️ 192MB 是经验值不是推导值。**计算参考**（GA100，PTE/PDE 均 8B，页表页 64KB）：
  - 77G 按 2MB：39,424 PTE ≈ 0.3MB —— 理论极小；
  - 77G 按 4KB：20,185,088 PTE ≈ **154MB** —— 这才是预留必须盖住的量级；
  - GSP 堆上限 184MB（0005 的 Booter 0x29 边界）→ **靠 PER_GB 公式最多给到
    ~160MB，盖不住 154MB+开销的 4KB 密度**，所以 0008（映射改 2MB）才是主解，
    本条是保险。
- `RmGspFirmwareHeapSizeMB=184` 会压住堆公式——改公式前先确认这行没把值钉死。
