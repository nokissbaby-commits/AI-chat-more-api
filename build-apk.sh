#!/bin/bash

# Claude Chat App - 自动 APK 打包脚本
# 使用方法: bash build-apk.sh

echo "=========================================="
echo "  Claude Chat App - APK 自动打包"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查环境
echo "🔍 检查环境..."
echo ""

# 检查 Java
if ! command -v java &> /dev/null; then
    echo -e "${RED}❌ 错误: 未找到 Java${NC}"
    echo "请先安装 Java JDK 11+"
    exit 1
fi
JAVA_VERSION=$(java -version 2>&1 | grep -oP 'version "\K[^"]+')
echo -e "${GREEN}✓ Java 已安装: $JAVA_VERSION${NC}"

# 检查 Android SDK
if [ -z "$ANDROID_HOME" ]; then
    echo -e "${YELLOW}⚠ 未设置 ANDROID_HOME${NC}"
    if [ -d "$HOME/Android/Sdk" ]; then
        export ANDROID_HOME="$HOME/Android/Sdk"
        echo -e "${GREEN}✓ 自动检测到 Android SDK${NC}"
    else
        echo -e "${RED}❌ 未找到 Android SDK${NC}"
        echo "请设置 ANDROID_HOME 环境变量"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Android SDK: $ANDROID_HOME${NC}"
fi

# 检查 Node
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ 错误: 未找到 Node.js${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Node.js 已安装$(node -v)${NC}"

echo ""
echo "=========================================="
echo "  第 1 步: 生成签名密钥"
echo "=========================================="
echo ""

KEYSTORE_FILE="claude-chat-app.keystore"

if [ -f "$KEYSTORE_FILE" ]; then
    echo -e "${GREEN}✓ 签名密钥已存在: $KEYSTORE_FILE${NC}"
    read -p "是否使用现有密钥? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        rm "$KEYSTORE_FILE"
        echo "已删除旧密钥，重新生成..."
    fi
fi

if [ ! -f "$KEYSTORE_FILE" ]; then
    echo "📝 生成新的签名密钥..."
    echo "（所有提示都按 Enter，最后输入密码）"
    echo ""
    
    keytool -genkey -v -keystore "$KEYSTORE_FILE" \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -alias claude-key \
        -storepass 123456 \
        -keypass 123456 \
        -dname "CN=Claude Chat,OU=Development,O=Claude,L=Shanghai,S=Shanghai,C=CN"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 签名密钥生成成功${NC}"
    else
        echo -e "${RED}❌ 签名密钥生成失败${NC}"
        exit 1
    fi
fi

echo ""
echo "=========================================="
echo "  第 2 步: 配置签名信息"
echo "=========================================="
echo ""

BUILD_GRADLE="android/app/build.gradle"

if [ ! -f "$BUILD_GRADLE" ]; then
    echo -e "${RED}❌ 找不到 $BUILD_GRADLE${NC}"
    exit 1
fi

echo "📝 检查签名配置..."

# 检查是否已配置
if grep -q "signingConfigs" "$BUILD_GRADLE"; then
    echo -e "${GREEN}✓ 已配置签名信息${NC}"
else
    echo "⚙️ 添加签名配置到 build.gradle..."
    
    # 备份原文件
    cp "$BUILD_GRADLE" "$BUILD_GRADLE.bak"
    
    # 找到 android { 并在其后插入签名配置
    sed -i '/^android {/a\
    signingConfigs {\
        release {\
            keyAlias "claude-key"\
            keyPassword "123456"\
            storeFile file("../claude-chat-app.keystore")\
            storePassword "123456"\
        }\
    }' "$BUILD_GRADLE"
    
    # 确保 release 构建使用签名配置
    if grep -q "signingConfig signingConfigs.release" "$BUILD_GRADLE"; then
        echo -e "${GREEN}✓ 签名配置已添加${NC}"
    else
        echo -e "${YELLOW}⚠ 请手动检查 build.gradle 中的签名配置${NC}"
    fi
fi

echo ""
echo "=========================================="
echo "  第 3 步: 清理项目"
echo "=========================================="
echo ""

echo "🧹 清理缓存..."
cd android
./gradlew clean --quiet
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 清理成功${NC}"
else
    echo -e "${YELLOW}⚠ 清理时出现问题，继续构建...${NC}"
fi

echo ""
echo "=========================================="
echo "  第 4 步: 构建 Release APK"
echo "=========================================="
echo ""

echo "🔨 编译 APK（这可能需要 5-15 分钟）..."
echo ""

./gradlew assembleRelease

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ APK 构建成功！${NC}"
else
    echo ""
    echo -e "${RED}❌ APK 构建失败${NC}"
    echo "请查看上面的错误信息"
    exit 1
fi

cd ..

echo ""
echo "=========================================="
echo "  第 5 步: 验证 APK 文件"
echo "=========================================="
echo ""

APK_FILE="android/app/build/outputs/apk/release/app-release.apk"

if [ -f "$APK_FILE" ]; then
    APK_SIZE=$(du -h "$APK_FILE" | cut -f1)
    echo -e "${GREEN}✓ APK 文件已生成${NC}"
    echo "📦 文件路径: $APK_FILE"
    echo "📊 文件大小: $APK_SIZE"
    echo ""
else
    echo -e "${RED}❌ 找不到 APK 文件${NC}"
    exit 1
fi

echo ""
echo "=========================================="
echo "  ✅ APK 打包完成！"
echo "=========================================="
echo ""
echo "📱 安装到手机:"
echo "  adb install $APK_FILE"
echo ""
echo "📤 复制 APK 到桌面:"
echo "  cp $APK_FILE ~/Desktop/"
echo ""
echo "💾 APK 文件位置:"
echo "  $APK_FILE"
echo ""
echo "🎉 现在可以分享这个 APK 给朋友了！"
echo ""
