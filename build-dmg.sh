#!/bin/bash

# WXL DMG 打包脚本
# 用法: ./build-dmg.sh [版本号]
# 示例: ./build-dmg.sh 1.0.0

set -e

# 配置
APP_NAME="WXL"
VERSION="${1:-1.0.0}"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
OUTPUT_DIR="$PROJECT_DIR/release"

echo "========================================"
echo "  $APP_NAME DMG 打包工具"
echo "  版本: $VERSION"
echo "========================================"

# 清理旧构建
echo "[1/4] 清理旧构建文件..."
rm -rf "$BUILD_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

# 构建 Release 版本
echo "[2/4] 构建 Release 版本..."
xcodebuild \
    -project "$PROJECT_DIR/WXL.xcodeproj" \
    -scheme WXL \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/derivedData" \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    archive \
    | xcpretty --color 2>/dev/null || xcodebuild \
    -project "$PROJECT_DIR/WXL.xcodeproj" \
    -scheme WXL \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/derivedData" \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    archive

# 导出 .app
echo "[3/4] 导出应用..."
APP_PATH="$BUILD_DIR/derivedData/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    # 尝试从 Archive 中查找
    APP_PATH=$(find "$BUILD_DIR/$APP_NAME.xcarchive" -name "$APP_NAME.app" | head -1)
fi

if [ ! -d "$APP_PATH" ]; then
    echo "错误: 找不到 $APP_NAME.app"
    exit 1
fi

echo "找到应用: $APP_PATH"

# 创建 DMG
echo "[4/4] 创建 DMG 安装包..."
DMG_TEMP="$BUILD_DIR/dmg-temp"
mkdir -p "$DMG_TEMP"

# 复制 .app 到临时目录
cp -R "$APP_PATH" "$DMG_TEMP/"

# 创建 Applications 快捷方式
ln -s /Applications "$DMG_TEMP/Applications"

# 使用 hdiutil 创建 DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$OUTPUT_DIR/$DMG_NAME"

# 清理临时文件
rm -rf "$BUILD_DIR"

echo ""
echo "========================================"
echo "  打包完成!"
echo "  输出: $OUTPUT_DIR/$DMG_NAME"
echo "========================================"

# 显示文件大小
ls -lh "$OUTPUT_DIR/$DMG_NAME"
