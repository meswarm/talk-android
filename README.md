# talk-android

`talk-android` 是一个基于 Matrix 协议的 Flutter 移动端聊天客户端，面向个人工作流、AI Agent 对话和带语音提醒的消息处理场景。项目当前聚焦 Android 侧体验，包含 Markdown/R2 媒体渲染、快捷提取、语音播报、实时语音秘书和 FCM 推送接入。

## 当前能力

- Matrix 登录、会话列表、消息收发和本地通知。
- Markdown 消息渲染，支持代码块、表格、链接和富媒体引用。
- R2 媒体附件渲染与全屏预览，覆盖图片、视频、音频和文件。
- 移动端 Markdown 输入器，支持媒体选择、相机拍摄和源码编辑。
- DeepSeek 快速提取，可按房间提示词整理最近一条远端文本消息。
- 语音播报：
  - 基础房间提醒。
  - 使用 Qwen 整理消息后再播报摘要。
  - 使用豆包实时语音大模型做低延迟播报整理。
- 实时语音秘书：
  - 独立设置页与 Android 前台服务。
  - 支持暗号唤醒或直接进入上下文对话。
  - 调试面板可显示当前会话状态与对话内容。
- FCM 推送通知设置页，可查看设备 Token 并做本机通知测试。

## 环境要求

- Flutter SDK 与 `pubspec.yaml` 中声明的 Dart SDK 版本。
- Android Studio 或 Xcode。
- 一个可用的 Matrix homeserver。
- 可选：
  - Cloudflare R2
  - DeepSeek API
  - 豆包语音 / 实时语音大模型
  - Firebase Cloud Messaging

## 本地运行

```bash
flutter pub get
flutter run
```

## 验证

```bash
flutter test
flutter analyze
flutter build apk --debug
```

## 项目文档

- [文档索引](docs/README.md)
- [R2 房间目录与 MIME 对齐](docs/r2-room-prefix-and-mime-alignment.md)
- [语音播报 MVP 设计](docs/superpowers/specs/2026-04-27-voice-announcement-mvp-design.md)
- [Android 常驻语音播报设计](docs/superpowers/specs/2026-05-04-android-keep-alive-voice-announcement-design.md)
- [FCM 推送通知 MVP 设计](docs/superpowers/specs/2026-05-04-fcm-push-notification-mvp-design.md)

## GitHub 上传说明

- API Key、Access Token、R2 Secret Key、Firebase 配置等敏感信息只应保存在本机安全存储或本地配置文件中。
- 不要提交 `.env`、签名证书、`google-services.json`、`GoogleService-Info.plist`、构建产物或本地 agent 状态。
- 根目录里的导出型参考 PDF 和本地 API 文档快照默认不应上传。
- 推送前建议至少执行：

```bash
git status --short
flutter test
flutter analyze
rg -n --hidden --glob '!.git' --glob '!node_modules' --glob '!dist' --glob '!build' '(api[_-]?key|secret|token|password|passwd|private[_-]?key|BEGIN (RSA|OPENSSH|PRIVATE)|AKIA|ghp_|github_pat_)' .
```
