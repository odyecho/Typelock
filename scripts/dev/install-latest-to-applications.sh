#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_PATH="$PROJECT_ROOT/Typelock.xcodeproj"
SCHEME="${SCHEME:-Typelock}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SDK="${SDK:-macosx}"
INSTALL_PATH="${INSTALL_PATH:-/Applications/Typelock.app}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.typelock.macos}"
OPEN_APP=false

usage() {
    cat <<EOF
用法:
  $(basename "$0") [--open]

说明:
  基于当前源码编译最新版 Typelock，并安装到“应用程序”目录。
  这个脚本不会使用 dist/ 下的历史安装包，因此可避免把旧版本误装到 /Applications。

可选环境变量:
  SCHEME=Typelock
  CONFIGURATION=Debug
  SDK=macosx
  INSTALL_PATH=/Applications/Typelock.app
  APP_BUNDLE_ID=com.typelock.macos
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --open)
            OPEN_APP=true
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

for cmd in xcodebuild awk ditto rm /usr/libexec/PlistBuddy; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "缺少命令: $cmd"
        exit 1
    fi
done

if [[ ! -d "$PROJECT_PATH" ]]; then
    echo "未找到工程文件: $PROJECT_PATH"
    exit 1
fi

installed_version="未安装"
installed_build="未安装"
if [[ -d "$INSTALL_PATH" ]]; then
    installed_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INSTALL_PATH/Contents/Info.plist" 2>/dev/null || echo '未知')"
    installed_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INSTALL_PATH/Contents/Info.plist" 2>/dev/null || echo '未知')"
fi

echo "=== 编译当前源码 ==="
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

build_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"

echo "当前已安装版本: $installed_version ($installed_build)"
echo "本次将安装版本: $build_version ($build_number)"
echo "构建产物路径: $APP_PATH"

if pgrep -x "Typelock" >/dev/null 2>&1; then
    echo "检测到 Typelock 正在运行，先退出旧进程"
    osascript -e 'tell application id "'"$APP_BUNDLE_ID"'" to quit' >/dev/null 2>&1 || true
    sleep 1
    pkill -x "Typelock" >/dev/null 2>&1 || true
fi

echo "=== 安装到应用程序 ==="
rm -rf "$INSTALL_PATH"
ditto "$APP_PATH" "$INSTALL_PATH"

final_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INSTALL_PATH/Contents/Info.plist")"
final_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INSTALL_PATH/Contents/Info.plist")"

echo "安装完成: $INSTALL_PATH"
echo "已安装版本: $final_version ($final_build)"

if [[ "$OPEN_APP" == true ]]; then
    echo "=== 启动应用 ==="
    open "$INSTALL_PATH"
fi
