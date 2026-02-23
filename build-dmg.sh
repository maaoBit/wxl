#!/bin/bash

# WXL DMG 打包脚本 (Swift Package)
# 用法: ./build-dmg.sh [版本号]
# 示例: ./build-dmg.sh 1.0.0

set -e

# 配置
APP_NAME="WXL"
VERSION="${1:-1.0.0}"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/arm64-apple-macosx/release"
DMG_TEMP_DIR="$PROJECT_DIR/.build/dmg-temp"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
OUTPUT_DIR="$PROJECT_DIR/release"

echo "========================================"
echo "  $APP_NAME DMG 打包工具"
echo "  版本: $VERSION"
echo "========================================"

# 清理并创建目录
echo "[1/5] 准备构建目录..."
rm -rf "$DMG_TEMP_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$DMG_TEMP_DIR"
mkdir -p "$OUTPUT_DIR"

# 构建 Release 版本
echo "[2/5] 构建 Release 版本..."
swift build -c release --product WXL

# 创建 .app 包
echo "[3/5] 创建应用包..."
EXECUTABLE_PATH="$BUILD_DIR/$APP_NAME"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

if [ ! -f "$EXECUTABLE_PATH" ]; then
    echo "错误: 找不到可执行文件 $EXECUTABLE_PATH"
    exit 1
fi

# 创建 .app 结构
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# 复制可执行文件
cp "$EXECUTABLE_PATH" "$APP_PATH/Contents/MacOS/"

# 复制应用图标
if [ -f "$PROJECT_DIR/WXL.icns" ]; then
    cp "$PROJECT_DIR/WXL.icns" "$APP_PATH/Contents/Resources/"
    echo "已复制应用图标"
fi

# 创建 Info.plist
cat > "$APP_PATH/Contents/Info.plist" << 'EOF'
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
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
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

echo "应用包创建完成: $APP_PATH"

# 复制 .app 到临时目录
echo "[4/5] 准备 DMG 内容..."
cp -R "$APP_PATH" "$DMG_TEMP_DIR/"

# 创建 Applications 快捷方式
ln -s /Applications "$DMG_TEMP_DIR/Applications"

# 创建 DMG
echo "[5/5] 创建 DMG 安装包..."
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

# 显示文件大小
ls -lh "$OUTPUT_DIR/$DMG_NAME"
