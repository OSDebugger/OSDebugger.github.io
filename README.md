# OSDebugger.github.io

OS Debug 项目的文档网站，基于 [Hugo](https://gohugo.io/) 与 [hugo-book](https://github.com/alex-shpak/hugo-book) 主题构建，自动部署到 GitHub Pages。

在线访问：<https://osdebugger.github.io/>

## 本地预览

克隆时记得带上主题子模块：

```sh
git clone --recursive https://github.com/OSDebugger/OSDebugger.github.io.git
```

已经 clone 过的补一下：

```sh
git submodule update --init --recursive
```

启动本地服务：

```sh
make serve
```

默认监听 `http://0.0.0.0:3001`，改端口：`make serve PORT=1313`。

## 目录结构

- `content/` — Markdown 文档
- `layouts/` — 覆盖主题的布局片段
- `assets/` — SCSS 等需要 Hugo 处理的资源
- `static/` — 直接复制到站点根目录的静态资源
- `themes/hugo-book/` — 主题子模块
- `.github/workflows/hugo.yml` — GitHub Pages 自动部署
