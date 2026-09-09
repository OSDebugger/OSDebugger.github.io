---
title: 开发环境搭建
weight: 10
bookToc: true
---

# 开发环境搭建

本文档说明如何获取插件源码并跑起来，面向想参与插件开发的开发者。

## 1. 前置依赖

插件开发需要以下环境：

```shell
# 使用命令检查是否安装成功：
npm -v  # 版本在 9 以上
node -v # 版本在 18 以上
```

如果不存在，按以下提示安装：

```shell
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

## 2. 获取代码

各仓库及其关系：

| 仓库 | 说明 |
| --- | --- |
| [OSDebugger/osgdb](https://github.com/OSDebugger/osgdb) | 跨特权级调试插件（当前主线，插件代码在 `code-debug/` 目录下） |
| [OSDebugger/async-debug](https://github.com/OSDebugger/async-debug) | 异步调试插件 |
| [WebFreak001/code-debug](https://github.com/WebFreak001/code-debug) | 上游项目（开源的 GDB/LLDB 调试前端），OS Debug 在其基础上 fork 而来 |

以 osgdb 为例：

```shell
git clone https://github.com/OSDebugger/osgdb.git
cd osgdb/code-debug
npm install
npm run compile
```

## 3. 构建与调试插件

1. 用 VS Code 打开 osgdb 仓库目录（仓库已内置 `.vscode/launch.json`，配置了 Extension Development Host 启动方式，并带有 `npm: compile` 前置任务）
2. 按 `F5`，VS Code 会编译插件并弹出一个新的「扩展开发宿主」窗口
3. 之后的调试操作都在「扩展开发宿主」窗口中进行：打开调试目标工程（如 rCore-Tutorial-v3），按 `F5` 即可开始调试

## 4. 打包 vsix

```shell
npm install -g @vscode/vsce
cd osgdb/code-debug
vsce package
```

打包时会按 `.vscodeignore` 排除 `docs/` 等大型文件。

## 5. 常见问题

- **F5 没有弹出扩展开发宿主窗口**：确认在 osgdb 仓库根目录（而非 code-debug 子目录）打开的 VS Code；重新执行 `npm install && npm run compile`
- **构建报错**：确认 node/npm 版本满足要求（node 18+、npm 9+）
