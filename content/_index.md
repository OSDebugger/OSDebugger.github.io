---
title: OS Debug
titleOnly: true
weight: 1
bookToc: false
---

# OS Debug

**适用于操作系统开发的源代码级调试工具**

中长期目标：提供三项核心功能模块：
- 面向OS的跨特权级源代码单步调试（OSGDB项目）：在常规GDB中，当特权级切换时，原特权级代码中打的断点会失效，且无法在一个特权级运行时给另一个特权级代码打断点。
  - 完成情况：在内核代码和用户程序中同时设置断点，插件自动处理地址空间切换；支持Qemu、JTAG+星光2开发板调试；支持rCore和xv6，其他操作系统（如StarryOS、uCore等正在移植）
- 面向基于Rust语言开发的异步（协程）程序（OS）调试（Async-Debuger项目）：在异步执行逻辑中，常规GDB给出的物理调用栈相对异步函数的真实调用逻辑来说是乱序的。本工作旨在重建异步调用逻辑，在物理调用栈的基础上进一步给出异步函数、同步函数的逻辑调用栈
  - 完成情况：已实现基本功能，并在minimal-协程例子、以及linos（一种面向嵌入式设备的异步OS）上进行了测试和验证。
- 基于ebpf的动态调试：结合GDB断点与插桩的方式，设计基于白名单的动态函数调用跟踪方法
  - 规划中。



## 快速链接
- OSGDB项目文档：
  - [项目介绍](docs/) — 项目概述与背景
  - [安装与使用](docs/usage) — 插件安装、调试配置与开发环境搭建
  - [功能介绍](docs/features) — 了解插件的全部功能
  - [项目阶段工作](docs/roadmap) — 项目的开发历程
  - [代码仓库（跨特权级切换调试插件）](https://github.com/OSDebugger/osgdb) — GitHub 源代码
  - 旧代码仓库（https://github.com/chenzhiy2001/code-debug）目前已停止更新
- Async-Debuger项目文档：
  - 文档补全中
  - [代码仓库（异步调试插件）](https://github.com/OSDebugger/async-debug) — GitHub 源代码
