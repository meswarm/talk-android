# Talk

Talk 是一个基于 Matrix 协议的移动端聊天客户端，面向个人工作流和 AI Agent 对话场景。当前重点是移动端消息体验、Markdown/R2 媒体渲染、快捷提取、语音播报和本地化配置。

## 功能概览

- Matrix 登录、会话列表、聊天消息收发。
- Markdown 消息渲染，支持表格、代码块、链接和富媒体引用。
- R2 媒体附件：图片、视频、音频和文件通过 Markdown 引用渲染。
- 图片/视频全屏预览，聊天内媒体尺寸可在个人资料页配置。
- 移动端 Markdown 输入器，支持媒体选择、相机拍摄和源码编辑。
- DeepSeek 快速提取：按房间提示词从最近一条对方文本消息中生成可复制候选项。
- 豆包语音播报：本地保存鉴权信息，用于新消息语音提醒 MVP。
- R2、DeepSeek、豆包 TTS 等密钥仅保存在本机安全存储，不上传到 Talk 服务端。

## 环境要求

- Flutter SDK，Dart SDK 版本需满足 `pubspec.yaml` 中的约束。
- Android Studio 或 Xcode，用于移动端构建和调试。
- 一个可用的 Matrix homeserver。
- 可选：Cloudflare R2、DeepSeek API、豆包语音合成 API。

## 本地运行

```bash
flutter pub get
flutter run
```

## 验证

```bash
flutter test
flutter analyze
```

## 文档

- [R2 房间目录与 MIME 对齐](docs/r2-room-prefix-and-mime-alignment.md)
- [移动端 Markdown 输入器设计](docs/superpowers/specs/2026-04-17-mobile-markdown-composer-design.md)
- [全屏图片查看器设计](docs/superpowers/specs/2026-04-20-fullscreen-image-viewer-design.md)
- [全屏视频播放器设计](docs/superpowers/specs/2026-04-20-fullscreen-video-player-design.md)
- [语音播报 MVP 设计](docs/superpowers/specs/2026-04-27-voice-announcement-mvp-design.md)

更多历史计划与设计记录见 [docs](docs/README.md)。

## 隐私与配置

- API Key、Access Token、R2 Secret Key 等敏感信息应只通过应用设置页写入本机安全存储。
- 不要把 `.env`、签名证书、Google/Firebase 配置、构建产物或本地 agent 状态提交到仓库。
- 上传 GitHub 前建议执行一次敏感信息扫描。
