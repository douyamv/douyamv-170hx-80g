# 0008 — 2MB 大页（双侧同改）

## 解决什么错误

```
Xid 31: MMU Fault ... FAULT_PDE
```

GSP 的 PTE 页池在小页密度下装不下大范围映射：77GiB 按 64KB 算要 128 万个 PTE，
按 2MB 只要 4 万个（差 32 倍），溢出后管理写落到错误物理地址。

## 方法（两处，缺一不可）

**分配侧** `src/kernel/mem_mgr/video_mem.c`（紧接 4KB→64KB 提升之后）：

```c
if ((devId==0x2082||0x20C2) && pageSize < RM_PAGE_SIZE_2M && size >= RM_PAGE_SIZE_2M)
    pageSize = RM_PAGE_SIZE_2M;
```

**映射侧** `src/kernel/gpu/mem_mgr/mem_mgr.c` `memmgrDeterminePageSize_IMPL()`
（switch(pageSizeAttr) 的 default 之后）：

```c
if ((devId==0x2082||0x20C2) && pageSizeAttr == RM_ATTR_PAGE_SIZE_DEFAULT
    && addrSpace == ADDR_FBMEM && pageSize != 0 && pageSize < RM_PAGE_SIZE_HUGE
    && memSize >= RM_PAGE_SIZE_HUGE && kgmmuIsHugePageSupported(...))
    pageSize = RM_PAGE_SIZE_HUGE;
```

## 验证

```
CMP80_PGSIZE: size=0x... attr=0 addrSpace=2 bigOK=1 -> pageSize=0x200000
```
（0x200000 = 2MB）

## 依赖

- **0006**。

## 坑

- ⚠️ **只改分配侧天花板纹丝不动**——真正决定 PTE 密度的是映射侧的
  `_PAGE_SIZE` attr（它才传播到 memdesc 和 GMMU 映射）。
- ⚠️ **本机（130）不要把 `RM_ATTR_PAGE_SIZE_4KB` 加进条件**：那两个显式 4KB
  巨型分配（39.4/40.2 GiB）与 WPR 布局耦合，提升后 Booter 直接 `0x29` 起不来。
  （该改法在 目标机B上可行——别照搬，机器间不通用。）
- 一度加过的「外层 DEFAULT || 内层 4KB」条件组合是**互斥死分支**（外层要求
  DEFAULT、内层查 4KB，永不同真），后来又按上表收回——保留纯 DEFAULT 条件。

## 2026-09-01 二次确认与死分支记录（用户已批准的修正）

1. **坑确认为真**：conf 唯一化（0015）后重放 4KB 提升，promotion 生效
   （日志 `size=0x9dd7d0000 attr=1 → pageSize=0x200000`）但 Booter 0x29 ×14 拒启。
   该 39.4G 显式 4KB 分配与 WPR 的耦合是**真实约束**，非 conf 误诊。已回滚。

2. **死分支（GLM 实现错误，已记录在案）**：DEFAULT-only 外层条件内的
   `if (pageSizeAttr == RM_ATTR_PAGE_SIZE_4KB)` 永不可达——
   - DEFAULT 映射可提升为 2MiB；
   - **显式 4KB 映射永远进不来**，内层是死代码；
   - 日志字符串被编译器优化掉（二进制中无 `CMP_PGSIZE: OVERRIDE`）；
   - 运行证据：两个核心大映射始终 `attr=1 → pageSize=0x1000`：
     ```
     size=0x9dd7d0000 attr=1 → pageSize=0x1000   (≈39.4G, 疑似高区 public 映射)
     size=0xa0d700000 attr=1 → pageSize=0x1000   (≈40.4G)
     ```
   即"大映射必须 2MiB 否则 4KiB 页表爆炸"的核心问题**当前并未解决**。

3. **待验证的正确设计（未实现）**：整对象直接改 pageSize 不做头尾拆分会触发
   `Assertion failed: (rangeEnd + 1) % pageSize == 0 @ regmap.c:2088`。
   正确方向 = 头尾拆分（首尾不足 2MiB 部分留 4KB，中段对齐部分用 2MiB）
   + 阈值公式修正。**尚未编码，勿当作已解决方案引用。**
