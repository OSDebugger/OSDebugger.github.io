---
title: 使用文档
weight: 1
bookToc: true
bookFlatSection: true
---

# 使用文档

OS Debug 提供三条调试能力线，按你的调试场景选择对应的教程：

## 普通操作系统调试（OSGDB）

在 VS Code 中跨内核态/用户态设置断点与单步调试，支持 QEMU 虚拟机与真实硬件。

- [调试 rCore](usage-rcore) — Rust 教学操作系统，含星光 2 真实硬件调试
- [调试 xv6](usage-xv6) — C 语言教学操作系统
- [调试 StarryOS](usage-starryos) — 组件化 Rust 操作系统

## Rust 异步程序调试（Async-Debuger）

异步执行中物理调用栈无法完整反映异步函数之间的调用关系。Async-Debuger 从 GDB 动态获取协程信息，重建异步函数、同步函数的逻辑调用栈。

- [调试 Rust 异步程序](usage-async-program)

## 异步操作系统调试

异步调试与跨特权级调试的融合能力：在调试 Rust 异步内核时，既可以跨内核态/用户态设置断点与单步调试，也可以查看异步任务的逻辑调用栈。

- [调试异步操作系统](usage-async-os)

## 其他

- [功能介绍](features) — 了解插件的全部功能
- [常见问题](faq) — 遇到问题先看这里
