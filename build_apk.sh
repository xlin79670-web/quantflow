#!/bin/bash
# QuantFlow Android APK 一键构建脚本
# 用法: chmod +x build_apk.sh && ./build_apk.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   QuantFlow APK 构建脚本             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
echo ""

# 检查 Flutter
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter 未安装${NC}"
    echo ""
    echo "安装 Flutter:"
    echo "  macOS:  brew install flutter"
    echo "  Linux:  snap install flutter --classic"
    echo "  Win:    https://docs.flutter.dev/get-started/install"
    echo ""
    echo "或手动下载: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo -e "${GREEN}✅ Flutter $(flutter --version | head -1)${NC}"

# 检查 Android SDK
if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
    echo -e "${RED}❌ Android SDK 未找到${NC}"
    echo ""
    echo "请安装 Android Studio 或 Android SDK:"
    echo "  https://developer.android.com/studio"
    echo ""
    echo "安装后设置环境变量:"
    echo "  export ANDROID_HOME=\$HOME/Android/Sdk"
    echo "  export PATH=\$PATH:\$ANDROID_HOME/tools:\$ANDROID_HOME/platform-tools"
    exit 1
fi

echo -e "${GREEN}✅ Android SDK${NC}"

# 进入 mobile 目录
cd "$(dirname "$0")/mobile"

# 获取依赖
echo ""
echo -e "${BLUE}📦 获取依赖...${NC}"
flutter pub get

# 构建 APK
echo ""
echo -e "${BLUE}🔨 构建 APK...${NC}"
flutter build apk --release

# 检查结果
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    SIZE=$(du -h "$APK_PATH" | cut -f1)
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✅ APK 构建成功!                   ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  📁 路径: $(pwd)/$APK_PATH"
    echo -e "  📦 大小: $SIZE"
    echo ""
    echo "  安装到手机:"
    echo "    adb install $APK_PATH"
    echo ""
    echo "  或直接将 APK 文件传到手机安装"
else
    echo -e "${RED}❌ 构建失败，请检查错误信息${NC}"
    exit 1
fi
