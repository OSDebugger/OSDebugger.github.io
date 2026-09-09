---
title: 调试 xv6
weight: 11
bookToc: true
---

# 调试 xv6

<!-- 开篇一句话：本文档说明如何用 OSGDB 调试 xv6（C 语言操作系统） -->

## 1. 使用目标

<!-- 完成本文档后，使用者能做到什么（3-4 条 bullet） -->

## 2. 前置条件

<!-- 与 usage-rcore 公共部分一致：插件获取与编译（clone osgdb → npm install → npm run compile → F5 扩展开发宿主）、GDB、QEMU。可简述并链接到 usage-rcore -->

## 3. 获取 xv6

<!-- 用哪个 xv6 仓库/版本，是否需要改动 -->

## 4. launch.json 配置

<!-- xv6 特有的配置点（素材：roadmap 第二阶段 C 节）：
- QEMU 启动参数：virt 机器、128M 内存、2 SMP 核心、virtio 块设备
- 用户程序命名规则：编译后格式为 _filename
- 多边界断点：usys.S 中有多个 ecall 指令（多个用户态出口），边界断点需要配多个
- 钩子断点：设在 sysfile.c 的 exec 函数处 -->

## 5. 调试流程

<!-- 与 usage-rcore 相同的流程：启动 QEMU → F5 attach → 加载边界/Hook 断点 → 设断点 -->

## 6. 常见问题

<!-- xv6 特有的坑 -->
