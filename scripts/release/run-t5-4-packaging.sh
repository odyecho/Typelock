#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCHEME="${SCHEME:-Typelock}"
CONFIGURATION="${CONFIGURATION:-Release}"
PRODUCT_NAME="${PRODUCT_NAME:-Typelock}"
DIST_DIR="${DIST_DIR:-$PROJECT_ROOT/dist/release}"
ARCHIVE_PATH="$DIST_DIR/$PRODUCT_NAME.xcarchive"
EXPORT_DIR="$DIST_DIR/export"
APP_PATH="$EXPORT_DIR/$PRODUCT_NAME.app"
PKG_UNSIGNED_PATH="$DIST_DIR/$PRODUCT_NAME-unsigned.pkg"
PKG_PATH="$DIST_DIR/$PRODUCT_NAME.pkg"
REPORT_PATH="$DIST_DIR/t5-4-validation-report.txt"
PROJECT_PATH="${PROJECT_PATH:-}"
WORKSPACE_PATH="${WORKSPACE_PATH:-}"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-}"
PKG_SIGN_IDENTITY="${PKG_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
VALIDATE_EXISTING=false
SIMULATE_INSTALL_CHECK=false
APP_PATH_SET=false
PKG_PATH_SET=false
ALLOW_ASSESS_FAIL=false

usage() {
    cat <<EOF
用法:
  $(basename "$0") [--project <path>] [--workspace <path>] [--scheme <name>] [--product-name <name>] [--dist <path>] [--sign-app "<Developer ID Application: ...>"] [--sign-pkg "<Developer ID Installer: ...>"] [--notary-profile <profile>] [--validate-existing] [--app <path>] [--pkg <path>] [--simulate-install-check] [--allow-assess-fail]

环境变量:
  SCHEME / PRODUCT_NAME / DIST_DIR / APP_SIGN_IDENTITY / PKG_SIGN_IDENTITY / NOTARY_PROFILE
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project)
            PROJECT_PATH="$2"
            shift 2
            ;;
        --workspace)
            WORKSPACE_PATH="$2"
            shift 2
            ;;
        --scheme)
            SCHEME="$2"
            shift 2
            ;;
        --product-name)
            PRODUCT_NAME="$2"
            shift 2
            ;;
        --dist)
            DIST_DIR="$2"
            shift 2
            ;;
        --sign-app)
            APP_SIGN_IDENTITY="$2"
            shift 2
            ;;
        --sign-pkg)
            PKG_SIGN_IDENTITY="$2"
            shift 2
            ;;
        --notary-profile)
            NOTARY_PROFILE="$2"
            shift 2
            ;;
        --validate-existing)
            VALIDATE_EXISTING=true
            shift
            ;;
        --app)
            APP_PATH="$2"
            APP_PATH_SET=true
            shift 2
            ;;
        --pkg)
            PKG_PATH="$2"
            PKG_PATH_SET=true
            shift 2
            ;;
        --simulate-install-check)
            SIMULATE_INSTALL_CHECK=true
            shift
            ;;
        --allow-assess-fail)
            ALLOW_ASSESS_FAIL=true
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

DIST_DIR="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$DIST_DIR")"
ARCHIVE_PATH="$DIST_DIR/$PRODUCT_NAME.xcarchive"
EXPORT_DIR="$DIST_DIR/export"
if [[ "$APP_PATH_SET" == false ]]; then
    APP_PATH="$EXPORT_DIR/$PRODUCT_NAME.app"
elif [[ "${APP_PATH:0:1}" != "/" ]]; then
    APP_PATH="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$APP_PATH")"
fi
PKG_UNSIGNED_PATH="$DIST_DIR/$PRODUCT_NAME-unsigned.pkg"
if [[ "$PKG_PATH_SET" == false ]]; then
    PKG_PATH="$DIST_DIR/$PRODUCT_NAME.pkg"
elif [[ "${PKG_PATH:0:1}" != "/" ]]; then
    PKG_PATH="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$PKG_PATH")"
fi
REPORT_PATH="$DIST_DIR/t5-4-validation-report.txt"

if [[ "$VALIDATE_EXISTING" == false ]]; then
    if [[ -z "$PROJECT_PATH" && -z "$WORKSPACE_PATH" ]]; then
        FIRST_PROJECT="$(find "$PROJECT_ROOT" -maxdepth 2 -name "*.xcodeproj" | head -n 1 || true)"
        FIRST_WORKSPACE="$(find "$PROJECT_ROOT" -maxdepth 2 -name "*.xcworkspace" | head -n 1 || true)"
        if [[ -n "$FIRST_WORKSPACE" ]]; then
            WORKSPACE_PATH="$FIRST_WORKSPACE"
        elif [[ -n "$FIRST_PROJECT" ]]; then
            PROJECT_PATH="$FIRST_PROJECT"
        else
            echo "未检测到 .xcodeproj 或 .xcworkspace，请先创建 Xcode 工程后重试。"
            exit 1
        fi
    fi

    if [[ -n "$PROJECT_PATH" && -n "$WORKSPACE_PATH" ]]; then
        echo "不能同时指定 --project 和 --workspace"
        exit 1
    fi

    if [[ -n "$PROJECT_PATH" ]]; then
        PROJECT_PATH="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$PROJECT_PATH")"
        CONTAINER_ARGS=(-project "$PROJECT_PATH")
    else
        WORKSPACE_PATH="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$WORKSPACE_PATH")"
        CONTAINER_ARGS=(-workspace "$WORKSPACE_PATH")
    fi
fi

for cmd in xcodebuild pkgbuild spctl codesign; do
    if [[ "$VALIDATE_EXISTING" == true ]]; then
        if [[ "$cmd" == "xcodebuild" || "$cmd" == "pkgbuild" ]]; then
            continue
        fi
    fi
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "缺少命令: $cmd"
        exit 1
    fi
done

if [[ "$VALIDATE_EXISTING" == false && -n "$PKG_SIGN_IDENTITY" ]]; then
    if ! command -v productsign >/dev/null 2>&1; then
        echo "启用 --sign-pkg 时缺少命令: productsign"
        exit 1
    fi
fi

mkdir -p "$DIST_DIR"
if [[ "$VALIDATE_EXISTING" == false ]]; then
    rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR" "$PKG_UNSIGNED_PATH" "$PKG_PATH" "$REPORT_PATH"
    mkdir -p "$EXPORT_DIR"

    echo "=== T5-4 打包开始 ==="
    echo "SCHEME=$SCHEME"
    echo "PRODUCT_NAME=$PRODUCT_NAME"
    echo "DIST_DIR=$DIST_DIR"

    xcodebuild archive \
        "${CONTAINER_ARGS[@]}" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -archivePath "$ARCHIVE_PATH" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES

    ARCHIVED_APP_PATH="$ARCHIVE_PATH/Products/Applications/$PRODUCT_NAME.app"
    if [[ ! -d "$ARCHIVED_APP_PATH" ]]; then
        echo "归档成功但未找到应用: $ARCHIVED_APP_PATH"
        exit 1
    fi

    cp -R "$ARCHIVED_APP_PATH" "$APP_PATH"

    if [[ -n "$APP_SIGN_IDENTITY" ]]; then
        codesign --force --deep --options runtime --sign "$APP_SIGN_IDENTITY" "$APP_PATH"
    fi

    pkgbuild --component "$APP_PATH" --install-location "/Applications" "$PKG_UNSIGNED_PATH"

    if [[ -n "$PKG_SIGN_IDENTITY" ]]; then
        productsign --sign "$PKG_SIGN_IDENTITY" "$PKG_UNSIGNED_PATH" "$PKG_PATH"
    else
        mv "$PKG_UNSIGNED_PATH" "$PKG_PATH"
    fi

    if [[ -n "$NOTARY_PROFILE" ]]; then
        if ! command -v xcrun >/dev/null 2>&1; then
            echo "启用公证时需要 xcrun 命令"
            exit 1
        fi
        xcrun notarytool submit "$APP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
        xcrun notarytool submit "$PKG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
        xcrun stapler staple "$APP_PATH"
        xcrun stapler staple "$PKG_PATH"
    fi
else
    APP_PATH="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$APP_PATH")"
    PKG_PATH="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$PKG_PATH")"
    if [[ ! -d "$APP_PATH" ]]; then
        echo "校验模式下未找到 .app: $APP_PATH"
        exit 1
    fi
    if [[ ! -f "$PKG_PATH" ]]; then
        echo "校验模式下未找到 .pkg: $PKG_PATH"
        exit 1
    fi
    rm -f "$REPORT_PATH"
    echo "=== T5-4 仅校验模式 ==="
    echo "APP=$APP_PATH"
    echo "PKG=$PKG_PATH"
fi

codesign --verify --deep --strict "$APP_PATH"
APP_ASSESS_RESULT="通过"
PKG_ASSESS_RESULT="通过"

if ! spctl --assess --type execute --verbose "$APP_PATH"; then
    APP_ASSESS_RESULT="失败"
    if [[ "$ALLOW_ASSESS_FAIL" == false ]]; then
        echo "Gatekeeper 执行校验失败: $APP_PATH"
        exit 1
    fi
fi

if ! spctl --assess --type install --verbose "$PKG_PATH"; then
    PKG_ASSESS_RESULT="失败"
    if [[ "$ALLOW_ASSESS_FAIL" == false ]]; then
        echo "Gatekeeper 安装校验失败: $PKG_PATH"
        exit 1
    fi
fi

APP_SHA="$(tar -cf - -C "$(dirname "$APP_PATH")" "$(basename "$APP_PATH")" | shasum -a 256 | awk '{print $1}')"
PKG_SHA="$(shasum -a 256 "$PKG_PATH" | awk '{print $1}')"

{
    echo "T5-4 安装包与分发验证报告"
    echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Scheme: $SCHEME"
    echo "Product: $PRODUCT_NAME"
    if [[ -n "$PROJECT_PATH" ]]; then
        echo "Project: $PROJECT_PATH"
    fi
    if [[ -n "$WORKSPACE_PATH" ]]; then
        echo "Workspace: $WORKSPACE_PATH"
    fi
    echo "Archive: $ARCHIVE_PATH"
    echo "App: $APP_PATH"
    echo "Pkg: $PKG_PATH"
    echo "NotaryProfile: ${NOTARY_PROFILE:-未启用}"
    echo "AppSHA256: $APP_SHA"
    echo "PkgSHA256: $PKG_SHA"
    echo "校验: codesign verify 通过"
    echo "校验: spctl execute $APP_ASSESS_RESULT"
    echo "校验: spctl install $PKG_ASSESS_RESULT"
    if [[ "$SIMULATE_INSTALL_CHECK" == true ]]; then
        echo "安装场景模拟: 已启用"
        echo "首次安装命令: sudo installer -pkg \"$PKG_PATH\" -target /"
        echo "覆盖安装命令: sudo installer -pkg \"$PKG_PATH\" -target /"
        echo "卸载重装步骤1: sudo rm -rf \"/Applications/$PRODUCT_NAME.app\""
        echo "卸载重装步骤2: sudo installer -pkg \"$PKG_PATH\" -target /"
    else
        echo "安装场景模拟: 未启用"
    fi
} > "$REPORT_PATH"

echo "=== T5-4 处理完成 ==="
echo "APP: $APP_PATH"
echo "PKG: $PKG_PATH"
echo "REPORT: $REPORT_PATH"
