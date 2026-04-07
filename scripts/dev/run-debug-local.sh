#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_PATH="$PROJECT_ROOT/Typelock.xcodeproj"
SCHEME="${SCHEME:-Typelock}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SDK="${SDK:-macosx}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.typelock.macos}"
OPEN_APP=true

usage() {
    cat <<EOF
用法:
  $(basename "$0") [--no-open]

说明:
  编译最新版 Typelock 的 Debug 版本，并默认自动打开应用。

可选环境变量:
  SCHEME=Typelock
  CONFIGURATION=Debug
  SDK=macosx
  APP_BUNDLE_ID=com.typelock.macos
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-open)
            OPEN_APP=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            usage
            exit 1
            ;;
    esac
done

for cmd in xcodebuild awk open; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "缺少命令: $cmd"
        exit 1
    fi
done

if [[ ! -d "$PROJECT_PATH" ]]; then
    echo "未找到工程文件: $PROJECT_PATH"
    exit 1
fi

echo "=== 编译 Debug 版本 ==="
xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk "$SDK" \
    build

BUILD_SETTINGS="$(
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -sdk "$SDK" \
        -showBuildSettings
)"

TARGET_BUILD_DIR="$(printf '%s\n' "$BUILD_SETTINGS" | awk -F ' = ' '/TARGET_BUILD_DIR/ {print $2; exit}')"
FULL_PRODUCT_NAME="$(printf '%s\n' "$BUILD_SETTINGS" | awk -F ' = ' '/FULL_PRODUCT_NAME/ {print $2; exit}')"
APP_PATH="$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"

if [[ ! -d "$APP_PATH" ]]; then
    echo "编译完成，但未找到应用: $APP_PATH"
    exit 1
fi

echo "应用路径: $APP_PATH"

if [[ "$OPEN_APP" == true ]]; then
    # 避免旧进程残留，确保本次启动的是刚编译的新版本。
    if pgrep -x "Typelock" >/dev/null 2>&1; then
        echo "检测到 Typelock 正在运行，先尝试退出旧进程"
        osascript -e 'tell application id "'"$APP_BUNDLE_ID"'" to quit' >/dev/null 2>&1 || true
        sleep 1
    fi

    echo "=== 启动应用 ==="
    open "$APP_PATH"
    echo "已启动最新版 Debug 应用"
    echo "首次运行如未生效，请在“系统设置 -> 隐私与安全性 -> 辅助功能”中允许 Typelock。"
else
    echo "已跳过自动启动，可手动执行："
    echo "open \"$APP_PATH\""
fi
