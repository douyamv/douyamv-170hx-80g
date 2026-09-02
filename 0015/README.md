# 0015 — conf 遮蔽：所有配置/内核/模块必须全局唯一（先清理再干活）

## 解决什么错误

多个 conf 文件同时写 `options nvidia NVreg_RegistryDwords=`——同一个 charp 参数
被传两遍，互相遮蔽，**实际生效的配置和我们以为的不一样**：

| 机器 | 遮蔽现场 | 后果 |
|---|---|---|
| 130 | `cmp-pcie-gen2.conf`（仅4键） vs `cmpunlocker.conf`（全量） | 生效集不确定 |
| 47 | `zz-cmp170hx-80g.conf`（字母序最后，**实际生效**）：`RmCmpRevThresholdMB=3072`、`RmCmpWirBit5Mode=0`、多 `RMInstLoc` | **反向分配实际被关成 3GB 阈值**、WirBit5=0——47 上"测过的"行为全部存疑 |

直接恶果：干净重建的模块（正确的 184MB 堆公式）在遮蔽 conf 下 Booter 0x29 拒启，
而旧二进制碰巧能启——**导致 0x29 被误归因于源码改动（PER_GB/Fix3），浪费了多轮排查**。

## 改动

1. **单一权威 conf**（Mac `deploy/cmpunlocker.conf`，两台机字节一致）：
   - 规则：任何 `options nvidia ...` 只允许出现在 `/etc/modprobe.d/cmpunlocker.conf` 一个文件
   - 其他 conf（`cmp-pcie-gen2.conf`、`zz-cmp170hx-80g.conf`、
     `nvidia-graphics-drivers-kms.conf` 等）中的 nvidia 主模块行全部删除
     （`nvidia_drm`/`nvidia_uvm` 行不冲突，保留）
2. **版本动物园清除**（`deploy/purge-versions.sh`，两台机已执行）：
   - 删 `~/tests/hs-lmr-shadow/`（几十个历史 .ko）
   - 删 tests 下散落 .ko、/tmp 模块副本
   - 删旧源码树 `cmpunlocker-80exp-20260824/`（**Mac 的 `deploy/src-tree-610.43.02-cmp80.tgz` 为唯一权威源码**）
   - 校验：`grep -l "^\s*options\s+nvidia\s" /etc/modprobe.d/*.conf` 必须只返回 1 个文件
3. **Mac 唯一模块制**：`deploy/` 里只留一个当前权威 .ko（换版必须删旧）

## 验证

```
130: PURGE_OK, 唯一conf=cmpunlocker.conf → 干净构建模块(8ee80770)首次正常启动(之前0x29)
47:  PURGE_OK, zz遮蔽消除
```

## 规则（今后执行）

**改任何东西之前，先确认环境唯一**：
```bash
grep -lE "^\s*options\s+nvidia(\s|$)" /etc/modprobe.d/*.conf /lib/modprobe.d/*.conf 2>/dev/null | wc -l   # 必须=1
ls /lib/modules/$(uname -r)/updates/cmpunlocker/*.ko | wc -l                                              # 主模块=1
```
不满足就先跑 `purge-versions.sh` + 重装权威 conf，再继续实验——否则结论全部作废。

## 依赖

无。

## 坑

- modprobe 对重复 `options nvidia` 的合并规则是"后到覆盖"，按文件名字母序——
  `zz-*` 天然压过一切，起这种名字等于埋雷。
- 备份在 Mac `deploy/backup-confs/confs-{130,47}.tgz`（清理前的全部 conf 原样）。
