#!/bin/bash

# WXL App 图标生成脚本
# 从 icon.png 生成 macOS .icns 图标文件

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_ICON="$PROJECT_DIR/icon.png"
ICONSET_DIR="$PROJECT_DIR/WXL.iconset"
OUTPUT_ICNS="$PROJECT_DIR/WXL.icns"

echo "========================================"
echo "  WXL App 图标生成工具"
echo "========================================"

# 清理旧的图标文件
echo "[1/4] 清理旧文件..."
rm -rf "$ICONSET_DIR"
rm -f "$OUTPUT_ICNS"

# 创建 iconset 目录
echo "[2/4] 创建 iconset 目录..."
mkdir -p "$ICONSET_DIR"

# 生成正方形基础图标（取中间部分或缩放到正方形）
# 原始尺寸：956x1122，我们缩放到 1024x1024
BASE_SQUARE="$PROJECT_DIR/icon-square.png"
sips -z 1024 1024 "$SOURCE_ICON" --out "$BASE_SQUARE" > /dev/null

# 生成所有需要的尺寸
echo "[3/4] 生成不同尺寸的图标..."

# macOS 需要的图标尺寸
# icon_name size
declare -a SIZES=(
    "icon_16x16 16"
    "icon_32x32 32"
    "icon_128x128 128"
    "icon_256x256 256"
    "icon_512x512 512"
    "icon_1024x1024 1024"
)

for size_info in "${SIZES[@]}"; do
    read -r name size <<< "$size_info"
    echo "  生成 ${size}x${size}..."

    # 生成 1x 版本
    sips -z $size $size "$BASE_SQUARE" --out "$ICONSET_DIR/${name}.png" > /dev/null

    # 生成 2x 版本（除了最大尺寸）
    if [ $size -lt 1024 ]; then
        double_size=$((size * 2))
        sips -z $double_size $double_size "$BASE_SQUARE" --out "$ICONSET_DIR/${name}@2x.png" > /dev/null
    fi
done

# 使用 iconutil 创建 .icns 文件
echo "[4/4] 创建 .icns 文件..."
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

# 清理临时文件
rm -f "$BASE_SQUARE"
rm -rf "$ICONSET_DIR"

echo ""
echo "========================================"
echo "  图标生成完成!"
echo "  输出: $OUTPUT_ICNS"
echo "========================================"

ls -lh "$OUTPUT_ICNS"
