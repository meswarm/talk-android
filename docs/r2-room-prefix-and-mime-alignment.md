# R2 房间共享参数与 MIME 对齐说明

## 目的

这份文档用于给其他客户端 / 同事对齐当前移动端的 R2 上传与渲染协议，重点回答两件事：

1. 如何获取房间共享的 R2 目录参数（常说的 A-room / shared prefix）
2. 现在 MIME 参数不再写进 `r2://` 链接后，其他端应如何和移动端保持一致

## 一句话结论

- 房间共享参数来自 **Matrix 房间 state event**：
  - `type = "com.talk.r2_prefix"`
  - `state_key = ""`
  - `content = { "prefix": "team-a/A-room" }`
- 新生成的 `r2://` 引用**不再带** `?mime=...`
- 媒体类型判断改为：
  1. 先看 object key 里的目录段：`imgs / videos / audios / files`
  2. 再看文件扩展名
- MIME 现在仍然用于：
  - 上传时的 `Content-Type`
  - 决定对象写入哪个子目录
  - 决定生成哪种 Markdown 语法
- MIME **不再用于**：
  - 写入 `r2://` ref 查询参数
  - 渲染时判断图片 / 视频 / 音频

---

## 1. 房间共享参数怎么取

### 1.1 来源

房间共享参数是一个房间级 Matrix state event。

```json
{
  "type": "com.talk.r2_prefix",
  "state_key": "",
  "content": {
    "prefix": "team-a/A-room"
  }
}
```

其中：

- `prefix` 不包含 bucket
- `prefix` 是整个房间共享的对象键前缀
- 示例：
  - `A-room`
  - `team-a/A-room`
  - `subhub`

### 1.2 移动端当前读取方式

移动端在聊天上传前读取：

- `room.getState("com.talk.r2_prefix")`
- 再从 `content.prefix` 取值
- 再做一次本地校验 / 规范化

如果未配置或非法，会直接阻止上传，并提示用户去房间信息页修正。

### 1.3 Prefix 校验规则

当前移动端接受以下规则：

- 去掉首尾空白后为空：视为“未配置”
- 不能包含反斜杠 `\`
- 不能以 `/` 开头或结尾
- 不能出现空段，也就是不能有连续 `/`
- 路径段不能是 `.` 或 `..`

合法示例：

- `A-room`
- `team-a/A-room`
- `subhub`

非法示例：

- `/a`
- `a/`
- `a//b`
- `a\ b`
- `a/../b`

---

## 2. Bucket 和 Prefix 的职责划分

### 2.1 Bucket

Bucket **不是房间共享参数**，而是客户端本机 R2 配置的一部分。

也就是说：

- Bucket：来自用户本机保存的 R2 凭据 / 默认 bucket
- Prefix：来自房间 state event 的共享配置

### 2.2 最终对象键结构

上传时对象键结构为：

```text
{prefix}/{imgs|videos|audios|files}/{timestamp}-{safeFileName}
```

例如：

```text
subhub/videos/1776580034770-1000009240.mp4
subhub/audios/1776580190426-_DJ_-_(_DJ_)_(_).mp3
team-a/A-room/imgs/1776581000000-photo.png
```

最终 ref 为：

```text
r2://{bucket}/{objectKey}
```

例如：

```text
r2://linux-storage/subhub/videos/1776580034770-1000009240.mp4
r2://linux-storage/subhub/audios/1776580190426-_DJ_-_(_DJ_)_(_).mp3
```

注意：**ref 里不再追加 `?mime=`**。

---

## 3. MIME 现在还做什么

虽然 `?mime=` 被移除了，但 MIME 本身没有消失，仍用于三件事。

### 3.1 上传请求头

上传 R2 时仍然带：

```http
Content-Type: <mime>
```

例如：

- `image/png`
- `video/mp4`
- `audio/mpeg`
- `application/pdf`

### 3.2 决定对象写入哪个目录

移动端当前映射规则：


| MIME 前缀  | 目录       |
| -------- | -------- |
| `image/` | `imgs`   |
| `video/` | `videos` |
| `audio/` | `audios` |
| 其它       | `files`  |


### 3.3 决定生成什么 Markdown

当前移动端生成规则：

- 图片：
  - `![name](r2://bucket/prefix/imgs/...)`
- 视频：
  - `![name（视频）](r2://bucket/prefix/videos/...)`
- 音频：
  - `![name（音频）](r2://bucket/prefix/audios/...)`
- 普通文件：
  - `[name](r2://bucket/prefix/files/...)`

说明：

- 现在音频也走 `![](...)` 语法，是因为移动端已经支持内联音频播放器
- 所以如果其他端想和当前移动端完全对齐，**音频也应生成 `![](...)`**

---

## 4. MIME 不再参与什么

### 4.1 不再写入 ref 查询参数

旧格式可能是：

```text
r2://bucket/path/to/file.mp4?mime=video%2Fmp4
```

新格式统一为：

```text
r2://bucket/path/to/file.mp4
```

### 4.2 不再依赖 `mimeHint` 做渲染判断

移动端现在渲染图片 / 视频 / 音频时，依赖的是 object key，而不是 `?mime=`。

判断顺序：

1. 看路径段是否出现：
  - `imgs`
  - `videos`
  - `audios`
  - `files`
2. 如果路径段看不出来，再看扩展名

扩展名集合当前为：

- 图片：`jpg jpeg png gif webp`
- 视频：`mp4 mov webm m4v`
- 音频：`mp3 m4a aac wav ogg opus flac weba`

### 4.3 下载缓存 MIME 的回退逻辑

下载 / 缓存时优先看 HTTP 响应头的 `Content-Type`。

如果响应头缺失，当前移动端回退到：

```text
application/octet-stream
```

不会再从 `r2://...?mime=` 里拿 MIME 兜底。

---

## 5. 其他端如何和移动端对齐

推荐按下面的顺序实现。

### 第一步：读取房间共享 prefix

从 Matrix 房间 state 中读取：

- `type = "com.talk.r2_prefix"`
- `state_key = ""`
- `content.prefix`

读到后按上面的 Prefix 校验规则做本地校验。

### 第二步：本机准备 bucket 和 R2 凭据

其他端需要自己准备：

- `accountId`
- `accessKeyId`
- `secretAccessKey`
- `region`
- `defaultBucket`

这里的 `defaultBucket` 应与移动端使用的 bucket 保持一致，否则不同端会写到不同 bucket。

### 第三步：根据 MIME 计算目标目录

伪代码：

```ts
function attachmentDirFromMime(mime: string): "imgs" | "videos" | "audios" | "files" {
  const m = mime.trim().toLowerCase();
  if (m.startsWith("image/")) return "imgs";
  if (m.startsWith("video/")) return "videos";
  if (m.startsWith("audio/")) return "audios";
  return "files";
}
```

### 第四步：拼 object key

```ts
const dir = attachmentDirFromMime(mime);
const objectKey = `${prefix}/${dir}/${Date.now()}-${safeFileName}`;
```

`safeFileName` 建议与移动端保持接近：

- `/`、`\` 替换为 `_`
- trim
- 空名回退为 `file`
- 非 `[A-Za-z0-9_ . - ( ) +]` 的字符替换为 `_`
- 最长截断到 120 字符

### 第五步：上传

- PUT 到 R2
- `Content-Type` 使用原始 MIME

### 第六步：生成 ref

```ts
const ref = `r2://${bucket}/${objectKey}`;
```

不要再拼：

```ts
?mime=${encodeURIComponent(mime)}
```

### 第七步：生成 Markdown

建议完全对齐当前移动端：

```ts
if (mime.startsWith("image/")) return `![${alt}](${ref})`;
if (mime.startsWith("video/")) return `![${alt}（视频）](${ref})`;
if (mime.startsWith("audio/")) return `![${alt}（音频）](${ref})`;
return `[${alt}](${ref})`;
```

---

## 6. 渲染端如何判断媒体类型

如果同事那边也要渲染 `r2://` Markdown，建议直接复用同一套规则：

### 6.1 目录优先

如果 object key 中包含：

- `/imgs/` -> 图片
- `/videos/` -> 视频
- `/audios/` -> 音频
- `/files/` -> 普通文件

### 6.2 扩展名兜底

如果目录看不出来，再按扩展名判断。

### 6.3 不要再依赖 `?mime=`

原因：

- 新消息不会再生成这个参数
- 老消息就算还带 `?mime=`，也不再作为主要判断依据

---

## 7. 兼容性说明

### 7.1 新消息

新消息是这次协议的目标：

- ref 无 `?mime=`
- 目录有明确分类
- 渲染按目录 / 扩展名识别

### 7.2 旧消息

旧消息可能仍然是：

```text
r2://bucket/path/file.mp4?mime=video%2Fmp4
```

当前移动端仍能解析这个 query，但**不会再依赖它做主要媒体判断**。

换句话说：

- 老消息不保证继续享有旧时代的“靠 mime query 强行推断视频”兼容行为
- 如果 object key 本身没有目录信息、扩展名也不明确，旧消息可能退化成普通链接 / 普通附件

---

## 8. 推荐给同事的最小对齐清单

如果对方不是要 100% 复刻移动端，只想保证能互通，最少做到这几条：

1. 读取 `com.talk.r2_prefix` / `state_key=""` / `content.prefix`
2. 上传路径写成 `{prefix}/{dir}/{timestamp}-{safeFileName}`
3. `dir` 由 MIME 前缀决定：`imgs/videos/audios/files`
4. 生成 `r2://bucket/objectKey`，不要带 `?mime=`
5. 渲染时按目录段优先、扩展名兜底判断图片 / 视频 / 音频

如果要和当前移动端**完全一致**，再补两条：

1. 音频 Markdown 也走 `![](...)`
2. 音频渲染为内联播放器，而不是普通链接

---

## 9. 示例：从房间配置到最终消息

假设：

- bucket = `linux-storage`
- 房间共享 prefix = `subhub`
- 文件名 = `1000009240.mp4`
- MIME = `video/mp4`

那么：

### 9.1 目录判断

```text
video/mp4 -> videos
```

### 9.2 object key

```text
subhub/videos/1776580034770-1000009240.mp4
```

### 9.3 ref

```text
r2://linux-storage/subhub/videos/1776580034770-1000009240.mp4
```

### 9.4 Markdown

```text
![1000009240.mp4（视频）](r2://linux-storage/subhub/videos/1776580034770-1000009240.mp4)
```

音频同理：

```text
![xxx.mp3（音频）](r2://linux-storage/subhub/audios/1776580190426-xxx.mp3)
```

---

## 10. 建议给对接方的实现口径

如果需要一句话口径发给同事，可以直接用下面这段：

> 房间共享目录请从 Matrix room state `com.talk.r2_prefix` 读取，`state_key` 为空串，内容为 `{ prefix: "team-a/A-room" }`。Bucket 不是房间共享参数，而是各端本机 R2 配置。上传时仍然要保留 MIME 作为 `Content-Type` 和目录分类依据，但不要再把 MIME 写进 `r2://` 查询参数。新 ref 统一为 `r2://bucket/objectKey`。媒体渲染请优先按 object key 的目录段 `imgs/videos/audios/files` 判断，其次按扩展名兜底；不要再依赖 `?mime=`。

