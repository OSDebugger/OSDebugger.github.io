---
title: 调试异步操作系统
weight: 14
bookToc: true
---

# 调试异步操作系统

本文档说明如何调试 Rust 异步操作系统——这是异步调试（async-debug）与跨特权级调试（osgdb 系列能力）融合后的功能。

## 1. 使用目标

调试异步操作系统时，需要同时面对两个难点：

1. **跨特权级调试**：内核态与用户态使用不同的符号表和断点集合。CPU 每次在两种特权级之间切换，调试器都必须自动切换符号表、重建断点，否则断点会命中错误的地址。
2. **异步逻辑不可见**：内核协程与用户协程的 poll 执行流在物理调用栈上不可见，开发者无法回答「这个协程在等谁、控制流怎么走到这里」。

本文档完成后，你将能够：在异步内核上跨内核态/用户态设置断点与单步调试，断点组随特权级自动切换；在 Async Inspector 面板中查看异步任务的逻辑调用栈——一棵调用树同时包含内核协程与用户协程，协程实例编号与 poll 次数跨越多次特权级切换连续累积。

## 2. 前置条件

**环境要求**（与跨特权级调试教程相同，另需 async-debug 插件）：

| 环境 | 要求 |
| ---- | ---- |
| 操作系统 | Ubuntu 24.04 LTS（x86_64） |
| VS Code | 1.80 及以上 |
| Node.js | 20 及以上 |
| Rust | nightly-2026-05-26（被调试目标需要） |
| GDB | gdb-multiarch 15.x（需支持 Python 扩展） |
| QEMU | qemu-system-riscv64（8.2 及以上） |

**获取插件：**

```bash
git clone https://github.com/OSDebugger/async-debug.git
cd async-debug
npm install
npm run compile
```

在 VS Code 中打开 async-debug 目录，按 `F5` 启动扩展开发宿主（Extension Development Host），插件即在其中生效。

## 3. 准备调试目标

本文以 [Async-os](https://github.com/AsyncModules/async-os)（Rust 异步微内核）为例，调试其管道读写测试 pipetest：它 spawn 出 reader 与 writer 两个用户协程，`sys_read`/`sys_write` 是异步系统调用，等待边天然跨越内核态与用户态。

async-os 自身的构建流程（依赖仓库、vDSO 预编译等）请见其仓库文档，本文假设目标本身能正常构建运行，此外，为了能够被调试编译方式和源代码需要做一定的修改。

### 3.1 内核：为调试保留符号信息

**必须用 release 构建**：RISC-V 的 JAL 指令跳转范围只有 ±1MB，debug 模式代码膨胀后，裸汇编中的短跳转会超出范围导致链接失败。因此采用「release + 调试信息」——附加 `-g` 嵌入调试信息、`-C strip=none` 防止 release 默认剥除：

```bash
make build ARCH=riscv64 BLK=n \
  RUSTFLAGS="-C link-arg=-T$PWD/linker_riscv64-qemu-virt.lds -C link-arg=-no-pie -C force-frame-pointers=yes -g -C strip=none"
```

注意 `RUSTFLAGS` 必须完整带上 `-T`（链接脚本）、`-no-pie`、`force-frame-pointers`——只传 `-g` 会覆盖这些预定义参数导致链接失败。

### 3.2 用户程序：为调试调整编译选项

pipetest 用户程序需按以下要求修改编译配置（在 `user_apps/` 下）：

- **`+crt-static` 静态化**：动态链接的 PIE 程序会被内核加载器重映射，符号基址全部错位，断点无法命中；
- **`opt-level = 0`**：`O3` 优化会吞掉行号表，断点全部变为 pending 状态无法命中。

将 `user_boot` 的 TESTCASES 设为 `"pipetest"`，然后编译用户程序并打包进磁盘镜像：

```bash
cd user_apps && make build_uapps && cd ..
sh ./build_img.sh -a riscv64
```

### 3.3 Hook 目标函数：禁止内联

内核以 LTO 编译时，短小的函数会被内联进调用点、从符号表中消失。用作 Hook 断点的目标函数（如 `init_user`）需添加 `#[inline(never)]` 属性保护，否则 Hook 断点永远不命中。

## 4. launch.json 配置

在 async-os 工作区新建 `.vscode/launch.json`：

```json
{
    "version": "0.2.0",
    "configurations": [{
        "type": "ardb",
        "request": "attach",
        "name": "async-os pipetest debug",
        "cwd": "${workspaceFolder}",
        "target": ":1234",
        "gdbpath": "gdb-multiarch",
        "executable": "${workspaceFolder}/apps/user_boot/user_boot_riscv64-qemu-virt.elf",
        "qemuPath": "qemu-system-riscv64",
        "qemuArgs": [
            "-m", "2G", "-smp", "1",
            "-machine", "virt", "-bios", "default",
            "-kernel", "${workspaceFolder}/apps/user_boot/user_boot_riscv64-qemu-virt.bin",
            "-device", "virtio-blk-pci,drive=disk0",
            "-drive", "id=disk0,if=none,format=raw,file=${workspaceFolder}/disk.img",
            "-device", "virtio-net-pci,netdev=net0",
            "-netdev", "user,id=net0",
            "-nographic", "-s", "-S"
        ],
        "first_breakpoint_group": "kernel",
        "second_breakpoint_group": "pipetest",
        "stopAtConnect": true,
        "program_counter_id": 32,
        "kernel_memory_ranges": [["0xffffffc000000000", "0xffffffffffffffff"]],
        "user_memory_ranges": [["0x0000000000000000", "0x0000004000000000"]],
        "border_breakpoints": [
            { "function": "<taskctx::arch::riscv::TrapFrame>::user_return", "direction": "kernel_to_user" },
            { "function": "trampoline::task_api::user_task_top::{async_fn#0}", "direction": "user_to_kernel" }
        ],
        "hook_breakpoints": [{
            "breakpoint": { "function": "trampoline::executor_api::init_user" },
            "behavior": {
                "functionArguments": "args",
                "functionBody": "try { await this.miDebugger.captureConsoleOutput('set language c'); const out = await this.miDebugger.captureConsoleOutput('x/s *((unsigned long long*)(args.buf.inner.ptr.pointer.pointer)+1)'); const m = /0x[0-9a-f]+:\\s*\"(.*)\"/.exec(out); return m ? m[1] : 'user'; } catch(e) { return 'user'; }",
                "isAsync": true
            }
        }],
        "filePathToBreakpointGroupNames": {
            "functionArguments": "filepath",
            "functionBody": "const m = /user_apps\\/([^\\/]+)\\//.exec(filepath); if (m) return [m[1]]; return ['kernel'];",
            "isAsync": false
        },
        "breakpointGroupNameToDebugFilePaths": {
            "functionArguments": "groupName",
            "functionBody": "if (groupName === 'kernel') return []; const fs = require('fs'); const path = require('path'); const dir = 'user_apps/target/riscv64gc-unknown-linux-musl/release/'; if (fs.existsSync(dir)) { const files = fs.readdirSync(dir).filter(f => f === groupName && !fs.statSync(path.join(dir, f)).isDirectory()); if (files.length > 0) return [path.join(dir, files[0])]; } return [path.join(dir, groupName)];",
            "isAsync": false
        }
    }]
}
```

关键配置项说明：

| 配置项 | 值 | 含义 |
| ------ | ---- | ---- |
| `border_breakpoints` | `user_return`（内核→用户）/ `user_task_top::{async_fn#0}`（用户→内核） | 边界断点，标记特权级切换位置，驱动断点组自动切换 |
| `hook_breakpoints` | `init_user` | Hook 断点：命中时执行 `behavior` 中的 JS 函数读取新启动的程序名，作为下一个断点组名，执行后自动继续 |
| `first/second_breakpoint_group` | `kernel` / `pipetest` | 初始断点组与默认目标断点组 |
| `kernel/user_memory_ranges` | 地址范围对 | 按程序计数器地址判断当前所在特权级 |
| 三个可编程函数 | `functionBody` | 文件路径→断点组名、组名→符号文件路径的映射。三处组名必须一致，否则会切换到空组 |

## 5. 调试流程

1. **启动调试**：在 async-os 工作区按 `F5`。调试器自动拉起 QEMU（`-s -S` 开启 GDB 端口并暂停）、连接 GDB、加载内核符号，并打开 Async Inspector 面板。
2. **生成白名单**：面板点击 `Gen Whitelist`，按 crate 分组列出可追踪函数。切到用户态后白名单会自动重建（合并用户 crate 符号）。
3. **应用白名单**：勾选要追踪的 crate（本例勾选用户 crate），点击 `Apply Whitelist`。
4. **设置追踪根**：以 `trampoline::task_api::user_task_top::{async_fn#0}` 为追踪根点击 `Trace`。它是内核协程，其 poll 驱动用户任务直到完成——以它为根，一棵树才能贯穿两个特权级。
5. **设断点、继续执行**：在 `user_apps/pipetest/src/implementation/async_await.rs` 的 18、19、29、35 行（spawn reader、spawn writer、reader 入口、writer 入口）设断点，按 `F5` 继续。断点组随特权级切换自动重建，无需手动干预。
6. **查看调用树**：每次暂停，面板自动刷新快照。

树节点字段含义：CID 为协程实例编号（同一函数的不同实例各占一个），Poll 为该实例累计被 poll 的次数，红色节点是 async 协程、蓝色节点是同步函数。

## 6. 常见问题

**Q：Gen Whitelist 生成的白名单中没有异步函数。**
白名单通过分析调试符号生成。内核必须 release 构建并显式嵌入调试信息（`-g` + `-C strip=none`，完整编译参数见 3.1）。

**Q：为什么不能用 debug 模式编译内核？**
RISC-V 的 JAL 指令跳转范围只有 ±1MB，debug 模式代码膨胀后裸汇编短跳转超出范围、链接失败。所以内核必须 release 构建并附加 `-g`（见 3.1）。

**Q：用户程序断点全部是 pending（灰点），一直不命中。**
两种原因：
1. 动态链接 PIE 被内核加载器重映射，符号基址错位——用户程序需 `+crt-static` 静态链接；
2. `O3` 优化吞掉行号表——用户程序需 `opt-level = 0`。

**Q：边界断点/Hook 断点指定的函数断点不命中。**
LTO 会把短小的函数内联进调用点，从符号表中消失。需为 Hook 目标函数添加 `#[inline(never)]`；边界函数应选择未被内联的符号（如用 `into_user` 替代被完全内联的 `first_into_user`），并以 GDB 中实际渲染的符号名为准。

**Q：user_boot 启动后直接退出，所有断点都不命中。**
user_boot 需要磁盘镜像中的用户程序 ELF。请确认已执行 `user_apps/make build_uapps` 与 `build_img.sh` 打包磁盘镜像，且 QEMU 参数中包含 virtio-blk 设备。

**Q：面板上的树是空的，或部分节点 CID 为 null。**
树空通常是未设置追踪根，或停在协程尚未 poll 的位置（此时树空是语义正确的）。用户态帧 CID 为 null 是已知限制：musl 工具链默认不带栈展开表，读不到协程环境指针，真协程帧只能以物理地址呈现。

**Q：跨特权级调试时跟踪很慢。**
这是当前实现的已知限制：每次特权级切换都要保存/恢复跟踪状态并重建断点，切换方向判断还依赖逐指令单步，时间消耗很大。团队已在规划优化（用 GDB `finish` 替代逐指令单步、引入切换冷却期），后续版本会改进。
