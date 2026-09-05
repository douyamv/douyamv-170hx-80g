# 0006 — PMA 高区注册（FB region 三段拆分）

## 解决什么错误

WPR 搬到低区后，RM 把「WPR 之上到 FB 顶」整段标 reserved——几十 GB 白白丢掉，
`nvidia-smi` 只剩 1 GiB 可用。

## 方法

`src/kernel/gpu/mem_mgr/mem_mgr.c` `memmgrSec2DebugLateExtendHighPmaRegion()`
把大 reserved 描述符拆三段：

```
[base, 40GB)          → 缩回给 GSP WPR，保持 reserved
[40GB, 79.43GB)       → 新建 public region，注册进 PMA（performance=0 最低优先级）
[79.43GB, 顶]         → 顶部保留（VBIOS/VGA workspace）
```

要点：
- `pmaRegisterRegion` 和 **FB region 描述符必须同时改**，只改一边 → RM/PMA 视图
  不一致 → `unspecified launch failure`；
- `performance=0` 让 RM/UVM 内部结构继续留在低区，只有大块客户分配溢上高区。

**配套（GSP 侧）**：`src/kernel/gpu/gsp/kernel_gsp.c` `kgspInitRm_IMPL()` 里把
static-info 大 region 的 `reserved` 字段改小到 WPR 实际大小，否则 CE 一碰高区就
`Xid 31 FAULT_PDE`。

## 验证

```
CMP80_PMA_HI: FB regions updated:
  gsp   [0x9f2900000-0x9ffffffff]
  public[0xa00000000-0x13db7fffff]
  top   [0x13db800000-0x13ffffffff] numRegions=9
```
`nvidia-smi` 可用显存 1 GiB → **78.89 GiB**；`poolinfo`（本目录）报 deviceTotalMem。

## 依赖

- **0005**（WPR 先搬走才有这段可拆）。

## 坑

- ⚠️ 技术事实：往 GSP region 列表**加条目**会直接 `No devices were found`
  （GSP 重试 15 次后放弃）——因此本补丁只改已有条目的字段。
