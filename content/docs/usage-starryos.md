---
title: 调试 StarryOS
weight: 12
bookToc: true
---

# 调试 StarryOS

本文档说明如何用 OSGDB 调试 [StarryOS](https://github.com/Starry-OS/StarryOS)（组件化 Rust 操作系统），涵盖环境配置、插件启动、`launch.json` 编写、调试流程与常见问题处理。

## 1. 使用目标

完成本文档的配置后，你可以在 VS Code 中通过 OSGDB：

- 启动 QEMU 并运行 StarryOS
- 通过 GDB 连接 QEMU 的 RISC-V 调试端口
- 实现 StarryOS 特权级切换的源码级调试

## 2. 推荐环境

| 项目 | 版本 |
| --- | --- |
| 操作系统 | Ubuntu 24.04 |
| QEMU | qemu-system-riscv64 7.1.0 |
| GDB | riscv64-unknown-elf-gdb 16.x |

> QEMU 与 GDB 的版本建议保持一致，工具链版本不兼容是很多调试问题的根源。

## 3. 插件获取与编译

1. 拉取 osgdb：

```shell
git clone https://github.com/OSDebugger/osgdb.git
```

2. 编译插件：

```bash
cd osgdb/code-debug
npm install
npm run compile
```

3. 在 VS Code 中打开 osgdb 目录，按 `F5` 启动一个新的「扩展开发宿主」窗口。后续所有调试操作都在这个窗口中进行。

## 4. 准备 StarryOS

按 StarryOS 官方文档完成编译后，确认以下产物存在：

```bash
ls StarryOS_riscv64-qemu-virt.bin
ls target/riscv64gc-unknown-none-elf/release/starryos
```

| 文件 | 用途 |
| --- | --- |
| `StarryOS_riscv64-qemu-virt.bin` | QEMU 启动用的内核镜像 |
| `target/riscv64gc-unknown-none-elf/release/starryos` | GDB 加载用的 ELF，包含调试符号 |

## 5. launch.json 配置

在 StarryOS 工程目录下创建 `.vscode/launch.json`，内容如下：

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "osdb",
      "request": "attach",
      "name": "StarryOS Debug (riscv64)",
      "cwd": "${workspaceFolder}",
      "target": ":1234",
      "gdbpath": "/opt/riscv/bin/riscv64-unknown-elf-gdb",
      "executable": "${workspaceFolder}/target/riscv64gc-unknown-none-elf/release/starryos",
      "qemuPath": "/usr/local/bin/qemu-system-riscv64",
      "qemuArgs": [
        "-L",
        "/usr/share/qemu",
        "-m",
        "1G",
        "-smp",
        "1",
        "-machine",
        "virt",
        "-bios",
        "default",
        "-kernel",
        "${workspaceFolder}/StarryOS_riscv64-qemu-virt.bin",
        "-nographic",
        "-device",
        "virtio-blk-pci,drive=disk0",
        "-drive",
        "id=disk0,if=none,format=raw,file=${workspaceFolder}/make/disk.img",
        "-device",
        "virtio-net-pci,netdev=net0",
        "-netdev",
        "user,id=net0,hostfwd=tcp::5555-:5555,hostfwd=udp::5555-:5555",
        "-s",
        "-S"
      ],
      "first_breakpoint_group": "kernel",
      "stopAtConnect": true,
      "program_counter_id": 32,
      "kernel_memory_ranges": [
        [
          "0xffffffc000000000",
          "0xffffffffffffffff"
        ]
      ],
      "user_memory_ranges": [
        [
          "0x0000000000001000",
          "0x0000004000000000"
        ]
      ],
      "border_breakpoints": [
        {
          "function": "enter_user",
          "direction": "kernel_to_user"
        },
        {
          "function": "starry_kernel::syscall::handle_syscall",
          "direction": "user_to_kernel"
        }
      ],
      "hook_breakpoints": [
        {
          "breakpoint": {
            "file": "${workspaceFolder}/kernel/src/syscall/task/execve.rs",
            "line": 65
          },
          "behavior": {
            "functionArguments": "",
            "functionBody": "const p = await this.getStringVariable('path'); const name = p.replace('./','').split('/').pop(); return '/path/to/StarryOS/user_apps/' + name + '.c';",
            "isAsync": true
          }
        }
      ],
      "filePathToBreakpointGroupNames": {
        "isAsync": false,
        "functionArguments": "filePathStr",
        "functionBody": "if (filePathStr.includes('kernel/src') || filePathStr.includes('.cargo/registry')) { return ['kernel']; } else { return [filePathStr]; }"
      },
      "breakpointGroupNameToDebugFilePaths": {
        "isAsync": false,
        "functionArguments": "groupName",
        "functionBody": "if (groupName === 'kernel') { return ['${workspaceFolder}/target/riscv64gc-unknown-none-elf/release/starryos']; } else { return [groupName.replace('.c', '')]; }"
      }
    }
  ]
}
```

### 关键配置说明

- `gdbpath` / `qemuPath`：指向你的 RISC-V GDB 与 QEMU 的**实际安装路径**（上面的示例路径是我们的环境，按你的机器修改）
- `executable`：带调试符号的内核 ELF
- `qemuArgs` 中的 `-kernel`：QEMU 启动用的裸二进制镜像
- `-s`：开启 QEMU 的 GDB stub（默认监听 1234 端口）；`-S`：启动后暂停，等待 GDB 连接
- `program_counter_id: 32`：RISC-V 架构中 PC 寄存器编号
- `border_breakpoints`：标记内核态与用户态的切换位置（`enter_user` 出内核、`handle_syscall` 进内核）
- `hook_breakpoints`：Hook 断点设在 `execve` 处，触发时读取即将执行的用户程序路径，据此切换到对应的用户程序源码与 ELF。`functionBody` 中返回路径的规则按你的目录结构修改
- `filePathToBreakpointGroupNames` / `breakpointGroupNameToDebugFilePaths`：文件路径 → 断点组、断点组 → 符号文件的映射规则

## 6. 调试流程

调试涉及两个 VS Code 窗口：

| 窗口 | 作用 |
| --- | --- |
| osgdb 扩展开发窗口 | 运行插件 |
| 扩展开发宿主窗口 | 实际调试 StarryOS |

1. 在「扩展开发宿主」窗口中打开 StarryOS 工程，按 `F5` 启动调试，程序停在入口位置
2. 通过命令面板加载特殊断点：
   - `Ctrl+Shift+P` → **OSDB: Set Border Breakpoints from launch.json** —— 加载边界断点，用于识别内核态与用户态的切换
   - `Ctrl+Shift+P` → **OSDB: Set Hook Breakpoints from launch.json** —— 加载 Hook 断点，用于在 `execve` 处读取即将执行的用户程序路径
3. 在需要调试的源码中直接设置断点，之后可以像调试普通程序一样使用 OSGDB

> 注意：Hook 断点依赖特权级切换。我们测试用的 StarryOS 版本中，用户态没有现成的测试程序（调试器适配阶段在用户态添加了测试程序）。如果你使用这份配置调试 StarryOS，请确保 StarryOS 用户态中存在测试程序，准备方法见下一节。

## 7. 用户程序准备

如果你的 StarryOS 已经有需要调试的用户态程序，跳过本节。StarryOS 的终端不能直接编译 C 程序，用户程序需要在 Ubuntu 宿主机中交叉编译为 RISC-V ELF，再放入磁盘镜像。

1. 在宿主机建立用户程序目录，编写示例：

```c
// 例如保存为 /path/to/StarryOS/user_apps/test_user.c
#include <stdio.h>
#include <unistd.h>

int add(int a, int b)
{
    return a + b;
}

int main()
{
    printf("user program start\n");
    int result = add(1, 2);
    printf("1 + 2 = %d\n", result);
    printf("user program end\n");
    return 0;
}
```

2. 用适配 StarryOS 用户态 ABI 的 RISC-V 交叉编译器编译。**建议保留调试信息并关闭优化**，便于源码级单步调试：

```bash
cd /path/to/StarryOS/user_apps
riscv64-unknown-elf-gcc -g -O0 -march=rv64gc -mabi=lp64d -static test_user.c -o test_user
```

编译后检查：

```bash
file test_user
# 应显示：ELF 64-bit LSB executable, UCB RISC-V, ... statically linked, with debug_info, not stripped
```

3. 将用户程序放入 StarryOS 磁盘镜像。StarryOS 启动后看到的是 `make/disk.img` 中的文件系统，不会看到宿主机目录。先确认镜像格式：

```bash
cd /path/to/StarryOS
file make/disk.img
# 应显示：Linux rev 1.0 ext4 filesystem data
```

挂载并复制：

```bash
sudo mkdir -p /mnt/starry_disk
sudo mount -o loop make/disk.img /mnt/starry_disk
sudo cp /path/to/StarryOS/user_apps/test_user /mnt/starry_disk/root/test_user
sudo chmod +x /mnt/starry_disk/root/test_user
sync
sudo umount /mnt/starry_disk
```

> **务必卸载镜像后再启动 QEMU**——镜像仍挂载在宿主机上时启动 QEMU，宿主机与 QEMU 会同时访问镜像，导致文件系统状态异常。

4. 启动 StarryOS，进入 shell 后运行：

```sh
cd /root
ls
./test_user
```

输出 `user program start`、`1 + 2 = 3` 即说明用户程序已放入 StarryOS 文件系统。

## 8. 常见问题

### 命令面板中没有 OSDB 命令

可能原因：当前窗口不是「扩展开发宿主」窗口 / 插件没有成功编译或启动 / `launch.json` 仍使用旧的 `type`（应为 `"osdb"`）。

处理：在 osgdb/code-debug 目录重新 `npm install && npm run compile`，按 `F5` 启动扩展开发宿主，并确认 `launch.json` 使用 `"type": "osdb"`。

### F5 后无法进入 StarryOS 终端

可能原因：QEMU 或 GDB 路径错误 / 1234 端口被旧 QEMU 占用 / 工具链版本不兼容 / `executable` 或 `kernel` 路径错误。

检查：

```bash
pkill -f qemu-system-riscv64   # 清理旧 QEMU
lsof -i :1234                  # 检查端口占用
```

### Hook 断点无法命中用户源码

确认 `user_apps` 目录下**源码和 ELF 都存在**（`.c` 文件与编译产物缺一不可），否则 Hook 只能完成配置，不能命中用户源码断点。

### 用户程序在 Ubuntu 中存在，但 StarryOS 中找不到

用户程序没有放进磁盘镜像。重新挂载 `make/disk.img`、复制用户程序、`umount` 后重启 StarryOS（步骤见第 7 节）。

### 调试控制台 PC 在内核地址反复单步

日志反复出现 `[osdb] check_stop_in_kernel ... isUserAddr = false` 且长期无法进入用户地址范围时，优先检查工具链版本，建议使用 QEMU 7.1.0 + GDB 16.x。

## 参考

本文档整理自 osgdb 仓库的 [StarryOS 调试操作手册](https://github.com/OSDebugger/osgdb/blob/main/docs/StarryOS%E8%B0%83%E8%AF%95%E6%93%8D%E4%BD%9C%E6%89%8B%E5%86%8C.md)。
