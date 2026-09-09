---
title: 调试 rCore
weight: 10
bookToc: true
---

# 调试 rCore

本文档说明如何用 OSGDB 调试 rCore-Tutorial-v3，涵盖 QEMU 虚拟机与星光 2 真实硬件两种环境

## 1. 使用目标

<!-- 完成本文档后，使用者能做到什么。参考 osgdb 仓库的 StarryOS 手册第 1 节写法（3-4 条 bullet） -->

## 2. 推荐环境

<!-- 表格：Ubuntu 版本 / QEMU 版本 / GDB 版本 / 工具链版本。可参考 StarryOS 手册第 2 节（QEMU 7.1.0、xPack riscv-none-elf-gdb 16.3，路径 /opt/qemu-7.1、/opt/riscv-xpack），如果 rCore 用同样环境就照搬，不同则按实际写 -->

## 3. 插件获取与编译

<!-- 公共流程，与 StarryOS 手册第 4 节一致：git clone osgdb → cd code-debug → npm install → npm run compile → VS Code 打开 osgdb 目录按 F5 启动扩展开发宿主窗口。可简要写出，完整说明链到 usage-starryos 或各自保留一份 -->

## 4. 准备 rCore-Tutorial-v3

<!-- 获取 rCore-Tutorial-v3 代码；如果现在还需要调试补丁，写补丁的获取与打补丁步骤（旧 usage.md 里的补丁 commit 在旧仓库，已过时，请按现状写） -->

## 5. launch.json 配置

<!-- 完整的 rCore launch.json 模板（type 为 "osdb"，配置项参考 StarryOS 手册第 6 节：gdbpath、qemuPath、executable、qemuArgs、kernel/user 内存地址范围、border_breakpoints、hook_breakpoints、断点组映射函数等）+ 关键配置说明。旧 usage.md 的配置链接指向旧仓库，勿用 -->

## 6. 调试流程

<!-- 流程：在扩展开发宿主窗口打开 rCore 工程 → F5 启动 → 命令面板执行 "OSDB: Set Border Breakpoints from launch.json" 和 "OSDB: Set Hook Breakpoints from launch.json" 加载边界/Hook 断点 → 在源码中设置断点调试。参考 StarryOS 手册第 7 节 -->

## 7. 进阶：星光 2 真实硬件调试

<!-- JTAG + OpenOCD 链路、U-Boot 加载、DCSR 寄存器限制的处理（边界断点设在 ecall 前一条指令）。素材：roadmap 第二阶段 D 节的技术描述；具体操作步骤按实际写 -->

## 8. 常见问题

<!-- 高频问题 3-5 条，每条 3-5 行。可参考 StarryOS 手册第 9 节的通用问题（命令面板没有 OSDB 命令、F5 后连不上、端口占用、工具链版本问题），再加上 rCore 特有的坑 -->
