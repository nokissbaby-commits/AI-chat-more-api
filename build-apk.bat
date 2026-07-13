@echo off
chcp 65001 >nul
REM Claude Chat App - Windows 自动 APK 打包脚本

setlocal enabledelayedexpansion

echo.
echo ==========================================
echo   Claude Chat App - APK 自动打包
echo ==========================================
echo.

REM 检查环境
echo 🔍 检查环境...
echo.

REM 检查 Java
where java >nul 2>nul
if errorlevel 1 (
    echo ❌ 错误: 未找到 Java
    echo 请先安装 Java JDK 11+
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('java -version 2^>^&1 ^| findstr "version"') do set JAVA_VERSION=%%i
echo ✓ Java 已安装: %JAVA_VERSION%

REM 检查 Android SDK
if "%ANDROID_HOME%"=="" (
    if exist "%USERPROFILE%\AppData\Local\Android\Sdk" (
        set "ANDROID_HOME=%USERPROFILE%\AppData\Local\Android\Sdk"
        echo ✓ 自动检测到 Android SDK
    ) else (
        echo ❌ 未找到 Android SDK
        echo 请设置 ANDROID_HOME 环境变量
        pause
        exit /b 1
    )
) else (
    echo ✓ Android SDK: %ANDROID_HOME%
)

REM 检查 Node
where node >nul 2>nul
if errorlevel 1 (
    echo ❌ 错误: 未找到 Node.js
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('node -v') do set NODE_VERSION=%%i
echo ✓ Node.js 已安装: %NODE_VERSION%

echo.
echo ==========================================
echo   第 1 步: 生成签名密钥
echo ==========================================
echo.

set KEYSTORE_FILE=claude-chat-app.keystore

if exist "%KEYSTORE_FILE%" (
    echo ✓ 签名密钥已存在: %KEYSTORE_FILE%
    set /p USE_EXISTING="是否使用现有密钥? (y/n): "
    if /i not "!USE_EXISTING!"=="y" (
        del "%KEYSTORE_FILE%"
        echo 已删除旧密钥，重新生成...
    )
)

if not exist "%KEYSTORE_FILE%" (
    echo 📝 生成新的签名密钥...
    echo.
    
    keytool -genkey -v -keystore "%KEYSTORE_FILE%" ^
        -keyalg RSA ^
        -keysize 2048 ^
        -validity 10000 ^
        -alias claude-key ^
        -storepass 123456 ^
        -keypass 123456 ^
        -dname "CN=Claude Chat,OU=Development,O=Claude,L=Shanghai,S=Shanghai,C=CN"
    
    if !errorlevel! equ 0 (
        echo ✓ 签名密钥生成成功
    ) else (
        echo ❌ 签名密钥生成失败
        pause
        exit /b 1
    )
)

echo.
echo ==========================================
echo   第 2 步: 配置签名信息
echo ==========================================
echo.

set BUILD_GRADLE=android\app\build.gradle

if not exist "%BUILD_GRADLE%" (
    echo ❌ 找不到 %BUILD_GRADLE%
    pause
    exit /b 1
)

echo 📝 检查签名配置...

findstr /M "signingConfigs" "%BUILD_GRADLE%" >nul
if !errorlevel! equ 0 (
    echo ✓ 已配置签名信息
) else (
    echo ⚙️  添加签名配置到 build.gradle...
    
    REM 备份原文件
    copy "%BUILD_GRADLE%" "%BUILD_GRADLE%.bak" >nul
    
    REM 创建临时文件，用于插入配置
    (
        echo android {
        echo     signingConfigs {
        echo         release {
        echo             keyAlias "claude-key"
        echo             keyPassword "123456"
        echo             storeFile file("../claude-chat-app.keystore"^)
        echo             storePassword "123456"
        echo         }
        echo     }
        echo.
        echo     buildTypes {
        echo         release {
        echo             signingConfig signingConfigs.release
        echo         }
        echo     }
        type "%BUILD_GRADLE%"
    ) > "%BUILD_GRADLE%.tmp"
    
    move /Y "%BUILD_GRADLE%.tmp" "%BUILD_GRADLE%" >nul
    echo ✓ 签名配置已添加
)

echo.
echo ==========================================
echo   第 3 步: 清理项目
echo ==========================================
echo.

echo 🧹 清理缓存...
cd android
call gradlew clean --quiet
if !errorlevel! equ 0 (
    echo ✓ 清理成功
) else (
    echo ⚠️  清理时出现问题，继续构建...
)

echo.
echo ==========================================
echo   第 4 步: 构建 Release APK
echo ==========================================
echo.

echo 🔨 编译 APK（这可能需要 5-15 分钟）...
echo.

call gradlew assembleRelease

if !errorlevel! equ 0 (
    echo.
    echo ✓ APK 构建成功！
) else (
    echo.
    echo ❌ APK 构建失败
    echo 请查看上面的错误信息
    cd ..
    pause
    exit /b 1
)

cd ..

echo.
echo ==========================================
echo   第 5 步: 验证 APK 文件
echo ==========================================
echo.

set APK_FILE=android\app\build\outputs\apk\release\app-release.apk

if exist "%APK_FILE%" (
    for %%A in ("%APK_FILE%") do set APK_SIZE=%%~zA
    echo ✓ APK 文件已生成
    echo 📦 文件路径: %APK_FILE%
    echo 📊 文件大小: %APK_SIZE% 字节
    echo.
) else (
    echo ❌ 找不到 APK 文件
    pause
    exit /b 1
)

echo.
echo ==========================================
echo   ✅ APK 打包完成！
echo ==========================================
echo.
echo 📱 安装到手机:
echo   adb install %APK_FILE%
echo.
echo 📤 复制 APK 到桌面:
echo   copy "%APK_FILE%" "%%USERPROFILE%%\Desktop\"
echo.
echo 💾 APK 文件位置:
echo   %APK_FILE%
echo.
echo 🎉 现在可以分享这个 APK 给朋友了！
echo.
pause
