---
title: 调试 Rust 异步程序
weight: 13
bookToc: true
---

# 调试 Rust 异步程序

本文档说明如何用 async-debug 插件调试 Rust 异步（协程）程序。注意：本文档针对 OSDebugger/async-debug 仓库的 VS Code 插件（调试类型 `ardb`），不涉及 osgdb 及跨特权级操作系统调试（attach 模式）。

## 1. 使用目标

Rust 的 async 函数会被编译器转成状态机：只有被执行器反复调用 `poll` 才推进一步，遇到未就绪的 `.await` 就暂停。这给调试带来一个难题：程序停住时，GDB 原生调用栈只显示当前这一次 poll 的物理栈帧，看不出「这个协程正在等谁」「执行流是怎样走到这里的」。

async-debug 通过 GDB Python 脚本在运行时追踪协程的 poll 事件，恢复两类关系：

- **等待边（await edge）**：协程 A 在 `.await` 协程 B，即「谁在等谁」；
- **调用边（call edge）**：协程内部同步函数之间的调用关系，即「控制流怎么走到这里」。

两者合在一起构成**逻辑调用栈**，以树形图展示在 Async Inspector 面板中。

完成本文档后，你将能够：启动一个 async-debug 调试会话；生成并应用白名单（允许追踪的函数列表）；设置追踪根（树的起点）；在 Async Inspector 面板中查看异步程序的逻辑调用栈，并读懂每个协程节点的含义。

## 2. 前置条件

**环境要求：**

| 环境 | 要求 |
| ---- | ---- |
| VS Code | 1.80 及以上 |
| Node.js | 20 及以上 |
| GDB | 需支持 Python 扩展（`gdb --configuration` 输出含 `--with-python`）。async-debug 通过 GDB Python 脚本收集异步信息，缺 Python 支持的 GDB 无法工作 |
| Rust 工具链 | 用于编译测试用例（`rustc`、`cargo`） |

插件在 Ubuntu 24.04 上完成测试；macOS 需自行安装 GDB（`brew install gdb`）并完成代码签名授权。

**获取与编译：**

```bash
git clone https://github.com/OSDebugger/async-debug.git
cd async-debug
npm install
npm run compile
```

**运行插件：** 在 VS Code 中打开 async-debug 目录，按 `F5` 启动扩展开发宿主（Extension Development Host），插件即在其中生效。

## 3. 准备调试目标

本文以仓库自带的测试用例 `testcases/minimal` 为例。它是一个不依赖外部运行时的小型异步程序：用标准库手写了一个最简执行器，驱动 4 段异步代码。

源码位于 `testcases/minimal/src/main.rs`，结构如下：

- `nonleaf`（async fn）`.await` 了 `async_fn_leaf`，并直接 `.await` 手写 Future `Manual`；
- `async_fn_leaf` 又 `.await` 了 `another_branch`；
- `another_branch` `.await` 了 `Manual`；
- `Manual` 是手工实现的 Future（非 async fn），第一次 poll 返回 Pending、第二次返回 Ready，是这条等待链真正的异步叶子；
- `sync_a`、`sync_b` 是普通同步函数，被上面的协程调用；
- `main` 依次阻塞执行 `async_fn_leaf`、`nonleaf`、一个 async 块和 `Manual`。

**编译：**

```bash
make compile TESTCASE=minimal
```

即在该测试用例目录下执行 `cargo build`。其 dev 编译配置已包含完整调试信息（`opt-level = 0`、`debug = 2`）。

**打开调试目标：** 本仓库 `.vscode/launch.json` 已预置配置「Extension Development Host (with testcase)」——在 async-debug 目录按 `F5` 并选择该配置，扩展开发宿主将直接打开 `testcases/minimal` 作为工作区，可在其中开始调试。

测试用例还自带一份预生成的白名单 `testcases/minimal/temp/poll_functions.txt`（含 5 个可追踪符号），首次使用可跳过白名单生成步骤。

## 4. launch.json 配置

在扩展开发宿主窗口（工作区为 `testcases/minimal`）中新建 `.vscode/launch.json`：

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "ardb",
            "request": "launch",
            "name": "Debug minimal",
            "program": "${workspaceFolder}/target/debug/minimal"
        }
    ]
}
```

launch 模式配置项：

| 配置项 | 必填 | 含义 |
| ------ | ---- | ---- |
| `type` | 是 | 固定为 `ardb` |
| `request` | 是 | 固定为 `launch`（本地调试） |
| `program` | 是 | 被调试的 Rust 可执行文件路径，默认为 `${workspaceFolder}/target/debug/${workspaceFolderBasename}`，在 minimal 工作区下恰好等于 `${workspaceFolder}/target/debug/minimal` |
| `args` | 否 | 传给程序的命令行参数 |
| `cwd` | 否 | 程序工作目录，默认 `${workspaceFolder}` |
| `env` | 否 | 传给程序的环境变量 |

`request: "attach"` 用于 QEMU 远程调试（跨特权级操作系统调试），不在本文档范围内。

## 5. 调试流程

### 5.1 六步工作流

1. **启动调试**：在 `testcases/minimal` 工作区按 `F5`。插件自动启动 GDB 并打开 Async Inspector 面板（也可通过命令面板「Open Async Inspector」手动打开）。
2. **生成白名单**：点击面板右侧白名单区的 `Gen Whitelist`，按 crate 分组列出可追踪函数。minimal 已自带白名单，此步可跳过——白名单文件变化时插件会自动重新加载。
3. **应用白名单**：勾选要追踪的 crate（本例勾选 `minimal`），点击 `Apply Whitelist`。
4. **设置追踪根**：在白名单区对目标符号点击 `Trace` 按钮（推荐，符号名完整准确）。追踪根是逻辑调用树的起点：插件从该协程的状态机字段出发，顺藤摸瓜发现被它等待的子协程，并自动为它们安装追踪断点。也可在源码中将光标放在函数名上，右键选择「Trace Function」（需与白名单中的完整符号名一致），或在调试控制台直接输入 `ardb-trace <符号>`。
5. **设断点、继续执行**：在源码中你想观察的位置设置普通断点（例如 `main` 中的打印语句处），按 `F5` 继续执行。
6. **查看调用树**：程序每次暂停，面板自动刷新快照并显示逻辑调用树。

### 5.2 面板读法

面板左侧是逻辑调用树：红色节点是 async 协程，蓝色节点是同步函数；实线是等待边（谁在等谁），虚线是调用边（同步调用）。每个协程节点标注：

- **CID**：协程实例编号。同一函数的多个实例各占一个编号；
- **Poll**：该实例被 poll 的次数；
- **State**：状态机判别值（0 表示尚未挂起）。

树是本次调试会话中多次暂停累积合并的结果，而不是某一次暂停的物理栈。

以 `nonleaf` 为追踪根时，可以看到：树根为 `nonleaf`，等待边连向 `async_fn_leaf` 与 `Manual::poll`；`async_fn_leaf` 再连向 `another_branch`，并穿插 `sync_a`、`sync_b` 同步节点——这就是 GDB 原生调用栈看不到的逻辑调用关系。


### 5.3 其他操作

- **自动推断追踪根**：在调试控制台执行 `ardb-infer-trace-root`，从当前物理调用栈向外回溯，自动找到最外层的 async 函数作为追踪根。
- **重置**：点击面板 `Reset` 按钮，或在调试控制台执行 `ardb-reset`，清除全部追踪状态，从头再来。

## 6. 常见问题

**Q：调试会话一启动就出错，GDB 没有输出。**
GDB 需支持 Python 扩展（`gdb --configuration` 输出中应有 `--with-python`）。async-debug 启动 GDB 时会自动加载 Python 脚本 `async_rust_debugger`，无 Python 支持的 GDB 会直接失败。macOS 用户请用 Homebrew 安装 GDB 并完成签名授权。

**Q：Gen Whitelist 生成的白名单是空的。**
白名单通过分析调试符号生成。请确认使用 debug 构建（`opt-level = 0`、`debug = 2`）；release 或 LTO 构建会内联、剥离 poll 符号，导致白名单为空、断点不命中。

**Q：面板上的树是空的。**
两种常见原因：

1. 忘了设置追踪根。面板 Trace Root 区域显示「No trace root set」时即为未设置；也可以用 `ardb-infer-trace-root` 自动推断。
2. 停在协程尚未 poll 的位置（例如 Future 构造处）。此时树为空是语义正确的，继续执行到协程被 poll 后即可看到树。

**Q：Trace 时提示「root not in whitelist」。**
该警告不阻止追踪，但建议先在白名单区勾选对应 crate 并点击 `Apply Whitelist`。

**Q：报「No program specified」或程序不启动。**
确认 `program` 指向存在的可执行文件。cargo 项目编译产物默认位于 `target/debug/<项目名>`。
