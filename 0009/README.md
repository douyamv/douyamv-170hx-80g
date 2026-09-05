# 0009 — 页表池按实际页大小（2MB）预留

## 解决什么错误

RM 原逻辑「不管客户端要多大页，一律按 4KB 最坏情况算页表池」：

```c
pageSizeLockMask = RM_PAGE_SIZE;                        // ← 元凶
status = rmMemPoolReserve(pool, poolSize, flags);
if ((status == NV_ERR_NO_MEMORY) && bRetryInSys) { status = NV_OK; }  // ← 错误被吞
```

77GiB VA 按 4KB 要 ~154MB 页表预留 → 预留失败 → **被静默改 NV_OK** →
池子欠额 → 无效页目录项 → `Xid 31 FAULT_PDE`。

## 方法

`src/kernel/mem_mgr/gpu_vaspace.c` `gvaspaceReserveMempool_IMPL()`，把那行
`pageSizeLockMask = RM_PAGE_SIZE;` 换成（devId 0x2082/0x20C2 时）：

```c
pageSizeLockMask = RM_PAGE_SIZE_HUGE;   /* 按 2MB 算，小 512 倍 */
NV_PRINTF(LEVEL_ERROR, "CMP80_POOLMASK: VA size 0x%llx lockMask 0x%llx -> 0x%llx\n", ...);
```

## 验证

```
CMP80_POOLMASK: VA size 0x...  lockMask 0x1000 -> 0x200000
```
（实测触发 51 次；`0x1000→0x200000` 即 4KB→2MB）

## 依赖

- **0008**（映射真的用 2MB，池按 2MB 算才自洽）。

## 坑

- ⚠️ 必须**无条件强制** HUGE。第一版写成「非 4KB 才保留原值」，而传进来的本来
  就是 4KB，补丁一次都没触发。
- 0008/0009 是两个不同层面：0008 管"映射用什么页"，0009 管"池按什么页预留"，
  一起改才消 Xid 31。
