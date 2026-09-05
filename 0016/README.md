# 0016 — 64KB 页提升：GSP 页表层死线从 37G 推到 38.75G（全量校验级）

## 解决什么错误

那两个 RM 内部全 FB 大映射（`memmgrAllocResources_IMPL`，0x9dd7d0000/0xa0d700000）
显式 4KB → PTE 需求 ~168MB > GSP 堆 184MB 可用 → `Xid 31 FAULT_PDE` → 37-38G 必崩。

## 改动

`mem_mgr.c memmgrDeterminePageSize_IMPL`（overlay，v2 准源已并入）：

```c
if ((devId==0x2082||0x20C2) && pageSizeAttr==RM_ATTR_PAGE_SIZE_4KB &&
    addrSpace==ADDR_FBMEM && memSize >= (1ULL<<30) && pageSize < RM_PAGE_SIZE_64K)
{
    pageSize = RM_PAGE_SIZE_64K;   // 不用2MB: 2MB提升触发Booter 0x29(0008坑)
}
```

**为什么 64KB 而不是 2MB**：PTE 降 16 倍（168MB→10.5MB，轻松入堆），
对齐要求仅 64KB（区域边界 1MB 粒度天然满足，WPR 耦合布局零扰动）。

## 验证（目标机B，模块 72630e19）

```
CMP80_64K: promoted explicit-4KB size=0x9dd7d0000 -> 64KB
CMP80_64K: promoted explicit-4KB size=0xa0d700000 -> 64KB
boot: 81920 MiB, 0x29=0, gate GATE_OK
vmmfull 38: bad=0 ALL PASSED, Xid=0   ← 历史死线(38G必崩)破解
```

## 附带定案的另一层（重要）

38.75G 以上**物理折叠**被精确量化（vmmchunk 分块工具，每块 256MB）：

| 总量 | 溢出 | 坏块 |
|---|---|---|
| 38G | 0 | 无 ✅ |
| 39G | 0.25G | 恰好 chunks 0..0（0.25G）|
| 45G | 6.25G | 恰好 chunks 0..24（6.25G）|

**公式：可用物理内存 = 38.75G（155×0.25G）；超出部分按模 38.75G 绕回踩掉低区。**
零 Xid、纯静默——这是 HBM logic die 行寻址层的折叠（Samsung 8Gb 降级寻址），
GSP/页表/驱动层已全部排除（0005-0016 全部生效后的剩余真墙）。

## 依赖

0006（高区注册）+ 0008（页大小机制）+ 0015（唯一 conf——当初 0x29 误诊的根源）。

## 坑

- 2MB 版提升 = Booter 0x29（0008，两次确认）。
- 构建管线必须内容自检（本方案曾因 overlay 静默丢失构建出带 2MB 提升的坏模块）。

## 支撑文件

- `../0004-folding-prebootstrap/vmmchunk.cu` — 分块 VA 预留 + 每块坏图工具
