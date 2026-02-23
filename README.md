# WXL - macOS 剪贴板历史管理器

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
</p>

一款使用 **Liquid Glass UI** 打造的优雅 macOS 剪贴板历史管理工具。WXL 让你能够轻松管理剪贴板历史、快速搜索、智能识别内容类型，并通过键盘快捷键高效操作。

## 功能特性

### 核心功能

- **剪贴板历史记录** - 自动记录所有复制的文本和图片内容
- **智能内容识别** - 自动识别 URL、邮箱、电话号码、文件路径、代码等
- **实时搜索** - 快速搜索历史记录中的任意内容
- **置顶功能** - 将重要内容置顶，永不自动清理
- **自动清理** - 可配置历史记录过期时间和最大条数
- **来源追踪** - 记录每条内容的来源应用

### 智能操作

根据内容类型提供不同的快捷操作：

| 内容类型 | 智能操作 (⌘+Enter) |
|---------|-------------------|
| URL | 在默认浏览器中打开 |
| 文件路径 | 在 Finder 中显示 |
| 邮箱 | 打开邮件客户端 |
| 电话号码 | 发起 FaceTime 通话 |

### 用户界面

- **Liquid Glass UI** - 现代化的毛玻璃效果界面
- **跟随鼠标位置** - 面板自动出现在鼠标附近
- **菜单栏图标** - 便捷的状态栏访问
- **深色模式支持** - 自动适配系统主题

### MCP 集成 (Model Context Protocol)

WXL 内置 MCP 服务器，支持与 Claude Code 等 AI 工具集成：

- **HTTP 传输** - 基于 HTTP 的 MCP 协议实现
- **剪贴板历史访问** - AI 可读取和搜索剪贴板历史
- **笔记生成** - 从剪贴板内容自动生成笔记

## 快捷键

### 全局快捷键

| 快捷键 | 功能 |
|-------|------|
| `⌘ ⇧ C` | 显示/隐藏剪贴板面板（可自定义） |

### 面板内快捷键

| 快捷键 | 功能 |
|-------|------|
| `↑` / `↓` | 上下选择项目 |
| `Enter` | 粘贴选中内容 |
| `⌘ Enter` | 执行智能动作 |
| `⌘ P` | 置顶/取消置顶 |
| `⌘ D` | 删除选中内容 |
| `Esc` | 关闭面板 |
| `输入字符` | 实时搜索过滤 |

## 系统要求

- macOS 14.0 (Sonoma) 或更高版本
- Apple Silicon 或 Intel 处理器

## 安装

### 从源码构建

```bash
# 克隆仓库
git clone https://github.com/maaoBit/wxl.git
cd wxl

# 使用 Swift Package Manager 构建
swift build -c release

# 或使用 Xcode 打开项目
open WXL.xcodeproj
```

### 下载发布版本

前往 [Releases](https://github.com/maaoBit/wxl/releases) 页面下载最新版本的 `.app` 文件。

## 配置

首次运行后，点击菜单栏图标选择"设置"进行配置：

### 通用设置

- **自动清理时间** - 设置历史记录的保留时间（6小时 ~ 7天）
- **最大历史条数** - 限制保存的历史记录数量（100 ~ 2000条）
- **登录时自动启动** - 开机自动运行

### 快捷键设置

- 自定义全局快捷键以显示/隐藏面板

## MCP 集成

WXL 内置 MCP (Model Context Protocol) 服务器，允许 AI 工具（如 Claude Code）访问你的剪贴板历史。

### 启动 MCP 服务器

MCP 服务器在 WXL 应用启动时自动运行在 `http://127.0.0.1:9527`

### 在 Claude Code 中配置

1. 确保 WXL 应用正在运行

2. 添加 MCP 服务器到 Claude Code：
   ```bash
   claude mcp add --transport http wxl http://127.0.0.1:9527/mcp
   ```

3. 验证连接：
   ```bash
   # 在 Claude Code 中运行
   /mcp
   ```

### MCP API 端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/mcp` | POST | JSON-RPC 2.0 端点 |
| `/health` | GET | 健康检查 |
| `/` | GET | 服务器信息 |

### 可用的 MCP 工具

| 工具名 | 说明 | 参数 |
|--------|------|------|
| `get_clipboard_history` | 获取剪贴板历史 | `limit` (可选), `contentType` (可选), `search` (可选) |
| `search_clipboard` | 搜索剪贴板内容 | `query` (必需), `sourceApp` (可选) |
| `generate_note` | 从剪贴板生成笔记 | `itemIds` (必需), `title` (可选) |

### 可用的 MCP 资源

| 资源 URI | 说明 |
|----------|------|
| `wxl://clipboard/history` | 完整剪贴板历史 |
| `wxl://clipboard/pinned` | 固定的剪贴板项目 |

### 使用示例

在 Claude Code 中，你可以这样使用：

```
# 获取最近的剪贴板历史
请使用 get_clipboard_history 工具查看我最近复制的 10 条内容

# 搜索特定内容
请搜索我剪贴板中包含 "API" 的内容

# 生成笔记
请根据我选中的剪贴板项目生成一份整理笔记
```

### 测试 MCP 服务器

```bash
# 健康检查
curl http://127.0.0.1:9527/health

# 获取服务器信息
curl http://127.0.0.1:9527/

# 测试 initialize 方法
curl -X POST http://127.0.0.1:9527/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
```

## 技术架构

```
WXL/
├── Sources/WXL/
│   ├── Models/
│   │   └── ClipboardItem.swift      # 数据模型和内容类型检测
│   ├── Services/
│   │   ├── ClipboardStorage.swift   # SQLite 持久化存储
│   │   ├── ClipboardMonitor.swift   # 剪贴板监听和 OCR
│   │   ├── IntelligentActionService.swift  # 智能操作服务
│   │   └── MCP/                     # MCP HTTP 服务器 (Claude Code 兼容)
│   ├── ViewModels/
│   │   └── ClipboardViewModel.swift # 业务逻辑层
│   ├── Views/
│   │   ├── PanelView.swift          # 主面板视图
│   │   ├── SettingsView.swift       # 设置界面
│   │   └── LiquidGlassView.swift    # Liquid Glass UI 组件
│   └── Utils/
│       └── KeyboardShortcuts+Name.swift
└── Tests/                           # 单元测试
    ├── ClipboardItemTests.swift
    ├── ClipboardItemCodableTests.swift
    ├── ClipboardStorageTests.swift
    └── IntelligentActionServiceTests.swift
```

### 技术栈

- **UI 框架**: SwiftUI
- **数据库**: SQLite (via SQLite.swift)
- **快捷键**: KeyboardShortcuts
- **加密**: CryptoKit (用于内容哈希)

## 开发

### 环境准备

```bash
# 安装 Xcode 命令行工具
xcode-select --install

# 克隆项目
git clone https://github.com/maaoBit/wxl.git
cd wxl
```

### 运行测试

```bash
swift test
```

### 构建

```bash
# Debug 构建
swift build

# Release 构建
swift build -c release
```

## 贡献

欢迎贡献代码！请查看 [CONTRIBUTING.md](CONTRIBUTING.md) 了解详情。

### 贡献方式

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

### 代码规范

- 遵循 Swift 代码规范
- 为新功能编写单元测试
- 更新相关文档

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 致谢

- [SQLite.swift](https://github.com/stephencelis/SQLite.swift) - 优雅的 SQLite 封装
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - macOS 全局快捷键支持

## 反馈与支持

- **问题反馈**: [GitHub Issues](https://github.com/maaoBit/wxl/issues)
- **功能建议**: [GitHub Discussions](https://github.com/maaoBit/wxl/discussions)

---

<p align="center">
  Made with ❤️ for macOS
</p>
