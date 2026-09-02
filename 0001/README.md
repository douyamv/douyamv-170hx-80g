# 0001 — HS ROP fire 通道（基础设施）

## 解决什么错误

GA100 的关键寄存器（CFG1/LMR/PLM 等）在 Booter 起来后处于 HS（高安全）锁定，
普通 BAR0 写入被丢弃。**没有这条通道，后面所有寄存器修改都无从谈起。**

## 方法

复用 SEC2/Booter 已验证的 HS ROP 链做 **refire**：在受控时机重放载荷，
借 HS 上下文的写权限把目标寄存器写掉。fire 由内核模块在早期完成，
开机 gate（`/usr/local/sbin/cmp170hx-postboot-gate`）负责时序和校验。

## 验证

gate 日志（journalctl -u cmp170hx-postboot-gate）出现：

```
SEC2_DEBUG: POST-BooterLoad verify PLM=0xffffffff SS0=0x88888888 SS1=0x00000008 CFG1=0x02779000 LMR=0x0000028b
```

以及热加载证据行 `CURRENT_..._HOT_LOAD_OK`。

## 依赖

无（根节点）。

## 坑

- **PROM 影子窗（BAR0 0x300000）写入不会落 SPI flash**——它只是只读映射的影子，
  写它不等于刷 vBIOS。全程**没有刷写过 vBIOS**。
- 直接往 HS 锁定寄存器裸写会被静默忽略，别用 `mmap resource0` 硬写来"验证"。

## 支撑文件

- gate 脚本本体在目标机：`/usr/local/sbin/cmp170hx-postboot-gate`
  （systemd unit：`cmp170hx-postboot-gate.service`）
