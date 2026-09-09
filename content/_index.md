---
title: OS Debug
titleOnly: true
weight: 1
bookToc: false
---

# OS Debug

**适用于操作系统开发的源代码级调试工具**

在 VS Code 中像调试普通程序一样调试操作系统内核：跨内核态/用户态的源代码级调试，覆盖 QEMU 虚拟机与真实 RISC-V 硬件，支持 Rust 与 C。

## 核心功能

### OSGDB：跨特权级源代码单步调试

在常规 GDB 中，当特权级切换时，原特权级代码中设置的断点会失效，也无法在一个特权级运行时给另一个特权级代码设置断点。OSGDB 通过断点组机制自动处理地址空间切换，可以在内核代码和用户程序中同时设置断点。

- **完成情况**：支持 QEMU 虚拟机与 JTAG+昉·星光 2 开发板调试；已适配 rCore、xv6 与 StarryOS。

### Async-Debuger：Rust 异步（协程）程序调试

在异步执行逻辑中，常规 GDB 给出的物理调用栈无法完整反映异步函数之间的调用关系：异步函数调用时只创建异步实例，真正的执行发生在实例被 poll 时；poll 返回后本次的物理栈帧即被销毁，实例可能在其他协程上被继续执行，此前的逻辑调用关系随之丢失。Async-Debuger 在物理调用栈的基础上重建异步调用逻辑，给出异步函数、同步函数的逻辑调用栈。

与需要依赖特定异步运行时或修改源代码的常见方案不同，Async-Debuger 直接在调试器中从 GDB 动态获取协程信息，不依赖特定运行时，通常无需修改源代码。对于被编译优化掉、但又比较重要的函数，可以为其添加禁止编译优化的属性，以保证协程信息完整可见。

- **完成情况**：已在 embassy（面向嵌入式设备的 Rust 异步运行时）上进行了验证；实现了调试插件与界面。

在异步调试与跨特权级调试的基础上，我们将两个功能融合，实现了对 Rust 异步操作系统的调试：在调试异步内核时，既可以跨内核态/用户态设置断点与单步调试，也可以查看异步任务的逻辑调用栈。跨特权级异步跟踪的功能已基本实现，但由于调试方案的设计，跟踪的时间消耗很大，后续会进行优化。

### eBPF 动态调试

结合 GDB 断点与插桩的方式，设计基于白名单的动态函数调用跟踪方法。

- **完成情况**：规划中。

## 快速上手

跟随[调试 rCore](docs/usage-rcore)教程，完成插件的安装与调试环境配置，即可在 VS Code 中设置断点调试操作系统内核。

## 支持矩阵

| 操作系统 | 语言 | 运行环境 | 状态 |
| --- | --- | --- | --- |
| rCore-Tutorial | Rust | QEMU（RISC-V） | 已支持 |
| rCore-Tutorial | Rust | 昉·星光 2 开发板（RISC-V） | 已支持 |
| xv6 | C | QEMU（RISC-V） | 已支持 |
| StarryOS | Rust | QEMU（RISC-V） | 已支持 |
| Async-os | Rust | QEMU（RISC-V） | 已支持 |

## 最新动态

- **2025-2026**：完成对组件化 Rust 操作系统（StarryOS）的适配（[osgdb](https://github.com/OSDebugger/osgdb)）；优化异步跟踪方案，实现调试插件与界面，并融合异步跟踪与跨特权级调试（[async-debug](https://github.com/OSDebugger/async-debug)），实现对 Rust 异步操作系统的调试
- **2024-2025**：完成 Rust 异步跟踪方案的设计与实现（[code-debug_Asynchronous-trace](https://github.com/OSDebugger/code-debug_Asynchronous-trace)）
- **2023-2024**：完善调试器功能，支持 C 语言操作系统（xv6）与真实硬件（昉·星光 2）调试，发布 v2.0.0（[code-debug](https://github.com/chenzhiy2001/code-debug)）
- **2022-2023**：从零构建操作系统源代码级调试工具，打通内核/用户态联合调试基本链路（[code-debug](https://github.com/chenzhiy2001/code-debug)）

完整的项目历程见[路线图](dev/roadmap)。

## 快速链接

### 使用教程

- [调试 rCore](docs/usage-rcore) — 含星光 2 真实硬件调试
- [调试 xv6](docs/usage-xv6)
- [调试 StarryOS](docs/usage-starryos)
- [调试 Rust 异步程序](docs/usage-async-program)
- [调试异步操作系统](docs/usage-async-os)
- [功能介绍](docs/features) — 了解插件的全部功能

### 开发者文档

- [项目全景](dev/) — 三条线的分工与项目目标
- [路线图](dev/roadmap) — 项目的开发历程与未来规划

### 代码仓库

- [OSGDB（跨特权级调试插件）](https://github.com/OSDebugger/osgdb)
- [Async-Debuger（异步调试插件）](https://github.com/OSDebugger/async-debug) — 融合与跟踪优化工作在此仓库进行
- [异步跟踪方案仓库](https://github.com/OSDebugger/code-debug_Asynchronous-trace) — 2024-2025 年方案的设计与实现
- 旧代码仓库（<https://github.com/chenzhiy2001/code-debug>）目前已停止更新
