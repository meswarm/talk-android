# Talk 文档索引

这个目录保存 Talk 的设计记录、实施计划和功能说明。文档可能包含历史决策过程，上传公开仓库前应避免写入真实账号、密钥、本机路径和内网地址。

当前仓库的用户侧能力主要包括：

- Matrix 聊天、房间列表、本地通知与 FCM 推送接入。
- Markdown/R2 媒体渲染、全屏媒体预览与移动端 Markdown 输入器。
- DeepSeek 房间级快速提取、输入框上方候选结果面板。
- 房间级常用语面板，本地独立保存。
- 语音播报、实时语音秘书与 Android 常驻服务。

## 功能文档

- [R2 房间目录与 MIME 对齐](r2-room-prefix-and-mime-alignment.md)
- [Talk MVP 设计](plans/2026-04-03-talk-mvp-design.md)

## 设计记录

- [移动端 Markdown 输入器](superpowers/specs/2026-04-17-mobile-markdown-composer-design.md)
- [Markdown 媒体与相机](superpowers/specs/2026-04-18-markdown-media-camera-design.md)
- [全屏图片查看器](superpowers/specs/2026-04-20-fullscreen-image-viewer-design.md)
- [全屏视频播放器](superpowers/specs/2026-04-20-fullscreen-video-player-design.md)
- [房间自动折叠](superpowers/specs/2026-04-21-room-auto-collapse-design.md)
- [语音播报 MVP](superpowers/specs/2026-04-27-voice-announcement-mvp-design.md)
- [Android 常驻语音播报](superpowers/specs/2026-05-04-android-keep-alive-voice-announcement-design.md)
- [FCM 推送通知 MVP](superpowers/specs/2026-05-04-fcm-push-notification-mvp-design.md)

## 发布前建议

- 优先阅读根目录 [README.md](../README.md)，它汇总了当前功能、设置入口和 GitHub 上传前检查项。
- 审核顶层参考文档 `deepseek.md`、`doubao2.md` 是否要继续对外保留。
- 根目录中本地 API 文档快照 `端到端实时语音大模型API接入文档.md` 与 `豆包语音_端到端Android SDK 接口文档.md` 默认不纳入仓库。

## 上传前检查

```bash
git status --short
flutter test
flutter analyze
```

敏感信息建议额外用 `rg` 扫描 `api_key`、`secret`、`token`、`password`、`AKIA`、`ghp_` 等关键词。

另外检查以下内容是否应保留在仓库外：

- Firebase 配置文件：`google-services.json`、`GoogleService-Info.plist`
- 签名文件：`*.jks`、`*.keystore`
- 构建产物：`build/`、`*.apk`、`*.aab`
- 本地导出的第三方参考 PDF 和 API 文档快照
