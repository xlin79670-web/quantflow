# QuantFlow APK 构建指南

## 方案 A: 本地构建 (推荐)

### 前置条件

1. **安装 Flutter**
```bash
# macOS
brew install flutter

# Linux (snap)
sudo snap install flutter --classic

# 或手动下载
# https://docs.flutter.dev/get-started/install
```

2. **安装 Android Studio**
```
https://developer.android.com/studio
安装时勾选 Android SDK
```

3. **配置环境变量**
```bash
# 添加到 ~/.bashrc 或 ~/.zshrc
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools
```

### 构建步骤

```bash
cd quant-trading-app

# 一键构建
chmod +x build_apk.sh
./build_apk.sh

# APK 位置: mobile/build/app/outputs/flutter-apk/app-release.apk
```

### 手动构建

```bash
cd mobile

# 获取依赖
flutter pub get

# 构建 release APK
flutter build apk --release

# 构建 debug APK (带调试)
flutter build apk --debug
```

### 安装到手机

```bash
# 方式 1: ADB 安装
adb install mobile/build/app/outputs/flutter-apk/app-release.apk

# 方式 2: 直接传输
# 将 APK 文件发送到手机，点击安装
```

---

## 方案 B: GitHub Actions 自动构建

### 步骤

1. **推送到 GitHub**
```bash
git init
git add .
git commit -m "initial"
git remote add origin https://github.com/你的用户名/quantflow.git
git push -u origin main
```

2. **自动构建**
- 推送后 GitHub Actions 自动触发构建
- 进入 Actions 页面查看进度
- 构建完成后在 Artifacts 下载 APK

3. **下载 APK**
```
GitHub 仓库 → Actions → 最新构建 → Artifacts → quantflow-apk
```

---

## 方案 C: Codemagic / Appetize (在线构建)

如果不想装本地环境:

1. **Codemagic** (免费)
   - https://codemagic.io
   - 连接 GitHub 仓库
   - 自动构建 APK

2. **Appetize** (在线预览)
   - https://appetize.io
   - 上传 APK 在线运行

---

## 常见问题

**Q: 构建报错 "SDK not found"**
```bash
flutter doctor --android-licenses  # 接受许可
flutter doctor                      # 检查环境
```

**Q: 构建报错 "Gradle failed"**
```bash
cd mobile/android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --release
```

**Q: 安装时提示 "未知来源"**
```
手机设置 → 安全 → 允许安装未知来源应用
```

**Q: APK 连不上服务器**
```
1. 确保手机和服务器在同一网络
2. 在 App 设置中修改服务器地址为服务器 IP
3. 检查服务器防火墙是否放行端口
```
