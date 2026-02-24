#!/bin/bash

# WXL DMG 打包脚本 (Swift Package)
#
# 用法:
#   ./build-dmg.sh              # 优先使用 git tag，否则默认 1.0.0
#   ./build-dmg.sh 1.2.3        # 指定版本号
#   ARCH=arm64 ./build-dmg.sh   # 只构建 ARM64
#   ARCH=x86_64 ./build-dmg.sh  # 只构建 Intel
#
# 推荐的发布流程:
#   git tag v1.0.0
#   ./build-dmg.sh              # 自动构建 Universal Binary
#   git push origin v1.0.0

set -e

# 配置
APP_NAME="WXL"

# 架构配置: universal (默认), arm64, x86_64
ARCH="${ARCH:-universal}"

# 版本号优先级: git tag > 命令行参数 > 默认值
get_version() {
    # 尝试从 git tag 获取（去掉 v 前缀）
    if GIT_TAG=$(git describe --tags --exact-match 2>/dev/null); then
        echo "${GIT_TAG#v}"
        return
    fi

    # 使用命令行参数或默认值
    echo "${1:-1.0.0}"
}

VERSION=$(get_version "$1")
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
OUTPUT_DIR="$PROJECT_DIR/release"

# 根据架构设置 DMG 名称
case "$ARCH" in
    universal)
        DMG_NAME="${APP_NAME}-${VERSION}.dmg"
        ;;
    arm64)
        DMG_NAME="${APP_NAME}-${VERSION}-arm64.dmg"
        ;;
    x86_64)
        DMG_NAME="${APP_NAME}-${VERSION}-x86_64.dmg"
        ;;
    *)
        echo "错误: 不支持的架构 '$ARCH'，请使用 universal, arm64 或 x86_64"
        exit 1
        ;;
esac

DMG_TEMP_DIR="$BUILD_DIR/dmg-temp"

echo "========================================"
echo "  $APP_NAME DMG 打包工具"
echo "  版本: $VERSION"
echo "  架构: $ARCH"
echo "========================================"

# 清理并创建目录
echo "[1/6] 准备构建目录..."
rm -rf "$DMG_TEMP_DIR"
mkdir -p "$DMG_TEMP_DIR"
mkdir -p "$OUTPUT_DIR"

# 构建函数
build_arch() {
    local arch=$1
    echo "  编译 $arch..."
    swift build -c release --arch "$arch" --product WXL
}

# 根据架构编译
echo "[2/6] 编译 Release 版本..."
case "$ARCH" in
    universal)
        build_arch arm64
        build_arch x86_64
        ;;
    arm64|x86_64)
        build_arch "$ARCH"
        ;;
esac

# 创建 .app 包
echo "[3/6] 创建应用包..."
APP_PATH="$BUILD_DIR/$APP_NAME.app"

# 创建 .app 结构
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# 复制/合并可执行文件
case "$ARCH" in
    universal)
        echo "  合并 arm64 和 x86_64 为 Universal Binary..."
        lipo -create \
            "$BUILD_DIR/arm64-apple-macosx/release/$APP_NAME" \
            "$BUILD_DIR/x86_64-apple-macosx/release/$APP_NAME" \
            -output "$APP_PATH/Contents/MacOS/$APP_NAME"
        ;;
    arm64)
        cp "$BUILD_DIR/arm64-apple-macosx/release/$APP_NAME" "$APP_PATH/Contents/MacOS/"
        ;;
    x86_64)
        cp "$BUILD_DIR/x86_64-apple-macosx/release/$APP_NAME" "$APP_PATH/Contents/MacOS/"
        ;;
esac

# 复制应用图标
if [ -f "$PROJECT_DIR/WXL.icns" ]; then
    cp "$PROJECT_DIR/WXL.icns" "$APP_PATH/Contents/Resources/"
    echo "  已复制应用图标"
fi

# 创建 Info.plist
echo "[4/6] 生成 Info.plist..."
cat > "$APP_PATH/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>WXL</string>
    <key>CFBundleIdentifier</key>
    <string>com.maoBit.WXL</string>
    <key>CFBundleName</key>
    <string>WXL</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>WXL</string>
</dict>
</plist>
EOF

echo "  应用包创建完成: $APP_PATH"

# 复制 .app 到临时目录
echo "[5/6] 准备 DMG 内容..."
cp -R "$APP_PATH" "$DMG_TEMP_DIR/"

# 创建 Applications 快捷方式
ln -s /Applications "$DMG_TEMP_DIR/Applications"

# 创建 DMG
echo "[6/6] 创建 DMG 安装包..."
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP_DIR" \
    -ov -format UDZO \
    -imagekey zlib-level=9 \
    "$OUTPUT_DIR/$DMG_NAME"

# 清理临时文件
rm -rf "$DMG_TEMP_DIR"

echo ""
echo "========================================"
echo "  打包完成!"
echo "  输出: $OUTPUT_DIR/$DMG_NAME"
echo "========================================"

# 显示文件大小和架构信息
ls -lh "$OUTPUT_DIR/$DMG_NAME"
echo ""
echo "包含的架构:"
lipo -info "$APP_PATH/Contents/MacOS/$APP_NAME"
