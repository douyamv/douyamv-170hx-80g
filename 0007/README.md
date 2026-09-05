# 0007 — 反向分配（大块高→低）

## 解决什么错误

```
Xid 13: Graphics SM Warp Exception: Illegal Instruction Encoding
        ESR 0x504728=0xc81eb60   ← PC 恒定：SM 取指读到被覆盖的内容
```

RM/GSP 自己的结构（实例块、页表、context buffer，KB~几 MB）和客户大块混在
一起从低往高填，客户数据压到系统结构上。

## 方法

`src/kernel/mem_mgr/video_mem.c` `vidmemAllocResources()`，在**所有 caller flag
和 address-range 处理完之后、算 pageCount 之前**插入（不会被下游覆盖）：

```c
#define CMP170_REVERSE_ALLOC_THRESHOLD  0x0000000080000000ULL  /* 2GiB 默认 */
#define CMP170_REVERSE_ALLOC_CEILING    0x0000001380000000ULL  /* 78GiB */

size >= threshold → allocOptions.flags |= PMA_ALLOCATE_REVERSE_ALLOC（高→低搜索）
且（无 FIXED_ADDRESS 时）physEnd = NV_ALIGN_DOWN(78GiB, pageSize) - 1
```

registry 可调不重编：`RmCmpRevThresholdMB` / `RmCmpRevCeilingMB`。

## 阈值必须按负载实际块尺寸定（最容易设错）

vLLM 实测块分布（CMP_PMA_POLICY 统计）：544MB×63、272MB×46、2.64GB×17、
170MB×10、2.43GB×4、128MB×3、256MB×2。

| 阈值 | 触发 | 结论 |
|---|---|---|
| 2GiB（默认） | 0 次 | 完全无效 |
| 128MB | 149 次 | 抓住主力块 |
| **32MB**（当前） | 351 次 | 更全 |

原则：**高于 RM 内部结构（KB~几 MB），低于负载最小工作块**。

## 验证

dmesg `CMP_PMA_POLICY: high-first size=... range=[0x0,0x...]` 按预期次数出现；
Xid 13 消失。

## 依赖

- **0006**（高区先注册进 PMA 才有得反向搜）。

## 坑

- ⚠️ codex 评估（2026-09-01）：32MB 阈值**太宽**，可能把驱动内部对象也搬进
  危险高区（误伤）。若再出诡异高区故障，先试着把阈值调回 128MB 对照。
