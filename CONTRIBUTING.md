# Contributing to WXL

感谢你考虑为 WXL 做出贡献！

## 目录

- [行为准则](#行为准则)
- [如何贡献](#如何贡献)
- [开发指南](#开发指南)
- [代码规范](#代码规范)
- [提交信息规范](#提交信息规范)
- [Pull Request 流程](#pull-request-流程)

## 行为准则

本项目采用贡献者公约作为行为准则。参与此项目即表示你同意遵守其条款。请阅读 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) 了解详情。

## 如何贡献

### 报告 Bug

如果你发现了 bug，请通过 [GitHub Issues](https://github.com/maaoBit/wxl/issues) 提交报告。提交前请：

1. 搜索现有的 issues，确认该问题尚未被报告
2. 收集以下信息：
   - macOS 版本
   - WXL 版本
   - 复现步骤
   - 预期行为
   - 实际行为
   - 截图（如果适用）

### 建议新功能

我们欢迎新功能建议！请通过 [GitHub Issues](https://github.com/maaoBit/wxl/issues) 提交，并使用 "enhancement" 标签。

### 提交代码

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 编写代码和测试
4. 提交更改 (`git commit -m 'Add some amazing feature'`)
5. 推送到分支 (`git push origin feature/amazing-feature`)
6. 创建 Pull Request

## 开发指南

### 环境要求

- macOS 14.0 (Sonoma) 或更高版本
- Xcode 15.0 或更高版本
- Swift 5.9

### 项目设置

```bash
# 克隆你的 fork
git clone https://github.com/YOUR_USERNAME/wxl.git
cd wxl

# 安装依赖（SPM 会自动处理）
swift package resolve

# 打开 Xcode 项目
open WXL.xcodeproj
```

### 项目结构

```
WXL/
├── Sources/WXL/
│   ├── Models/          # 数据模型
│   ├── Services/        # 业务服务（存储、监听、智能操作）
│   ├── ViewModels/      # 视图模型（MVVM）
│   ├── Views/           # SwiftUI 视图
│   └── Utils/           # 工具类
└── Tests/               # 单元测试
```

### 运行测试

```bash
# 运行所有测试
swift test

# 运行特定测试
swift test --filter ClipboardItemTests
```

### 构建项目

```bash
# Debug 构建
swift build

# Release 构建
swift build -c release
```

## 代码规范

### Swift 代码风格

- 遵循 [Swift API 设计指南](https://swift.org/documentation/api-design-guidelines/)
- 使用 4 空格缩进
- 文件末尾保留一个空行
- 使用有意义的变量和函数名

### 文档注释

为公共 API 添加文档注释：

```swift
/// 检测给定内容的类型
/// - Parameter content: 要检测的文本内容
/// - Returns: 检测到的内容类型
static func detectContentType(_ content: String) -> ContentType
```

### 测试要求

- 为新功能编写单元测试
- 确保所有测试通过后再提交 PR
- 测试应覆盖正常情况和边界情况

## 提交信息规范

使用清晰、描述性的提交信息：

### 格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

### 类型 (type)

- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式（不影响功能）
- `refactor`: 代码重构
- `test`: 测试相关
- `chore`: 构建/工具变更

### 示例

```
feat(detection): add support for detecting IP addresses

- Add IPv4 address detection pattern
- Add IPv6 address detection pattern
- Update ContentType enum with new type

Closes #123
```

## Pull Request 流程

1. **确保测试通过**
   ```bash
   swift test
   ```

2. **更新文档**
   - 更新 README.md（如有必要）
   - 更新 CHANGELOG.md（添加变更到 Unreleased 部分）

3. **创建 Pull Request**
   - 提供清晰的标题和描述
   - 关联相关的 issues
   - 等待代码审查

4. **代码审查**
   - 响应审查意见
   - 进行必要的修改
   - 保持讨论专业和友好

5. **合并**
   - PR 获得批准后将被合并
   - 你的贡献将出现在下一个版本中

## 获取帮助

如果你有任何问题，可以：

- 在 [GitHub Discussions](https://github.com/maaoBit/wxl/discussions) 提问
- 在 Issue 中提及 @maaoBit

---

再次感谢你的贡献！
