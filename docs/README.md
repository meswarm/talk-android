# Talk 文档索引

这个目录保存 Talk 的设计记录、实施计划和功能说明。文档可能包含历史决策过程，上传公开仓库前应避免写入真实账号、密钥、本机路径和内网地址。

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
