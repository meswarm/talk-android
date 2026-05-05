package com.example.talk

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.bytedance.speech.speechengine.SpeechEngine
import com.bytedance.speech.speechengine.SpeechEngineDefines
import com.bytedance.speech.speechengine.SpeechEngineGenerator
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class TalkRealtimeSecretaryService : Service() {
    override fun onCreate() {
        super.onCreate()
        isRunning = true
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isRunning = true
        startForegroundCompat(buildNotification())
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Talk 实时语音秘书",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "保持 Talk 实时语音秘书待命"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag(),
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Talk 实时语音秘书待命中")
            .setContentText("收到新消息后将等待语音暗号")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
            return
        }
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun immutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
    }

    companion object {
        const val CHANNEL_ID = "talk_realtime_secretary"
        const val NOTIFICATION_ID = 3018
        var isRunning: Boolean = false
            private set

        private const val dialogAddress = "wss://openspeech.bytedance.com"
        private const val dialogUri = "/api/v3/realtime/dialogue"
        private const val tag = "TalkRealtimeSecretary"
        private const val testSessionDurationMs = 10000L
        private const val voiceAnnouncementSafetyTimeoutMs = 60000L
        private const val voiceAnnouncementAudioIdleStopMs = 1500L

        @Volatile
        private var engine: SpeechEngine? = null
        @Volatile
        private var environmentPrepared: Boolean = false
        private val mainHandler = Handler(Looper.getMainLooper())

        @Volatile
        private var flutterChannel: MethodChannel? = null

        @Volatile
        private var voiceAnnouncementActive: Boolean = false
        private var voiceAnnouncementAudioIdleRunnable: Runnable? = null
        private var voiceAnnouncementSafetyRunnable: Runnable? = null

        fun setFlutterChannel(channel: MethodChannel?) {
            flutterChannel = channel
        }

        fun startWakeSession(
            context: android.content.Context,
            args: Map<*, *>,
        ) {
            Log.i(tag, "startWakeSession requested")
            clearVoiceAnnouncementState()
            val speechEngine = ensureEngine(context, args)
            speechEngine.sendDirective(SpeechEngineDefines.DIRECTIVE_SYNC_STOP_ENGINE, "")
            Log.i(tag, "sending DIRECTIVE_START_ENGINE")
            checkDirective(
                "DIRECTIVE_START_ENGINE",
                speechEngine.sendDirective(
                    SpeechEngineDefines.DIRECTIVE_START_ENGINE,
                    startSessionPayload(args),
                ),
            )
            val opening = args["openingAnnouncement"] as? String ?: return
            Log.i(tag, "sending DIRECTIVE_EVENT_SAY_HELLO")
            checkDirective(
                "DIRECTIVE_EVENT_SAY_HELLO",
                speechEngine.sendDirective(
                    SpeechEngineDefines.DIRECTIVE_EVENT_SAY_HELLO,
                    contentPayload(opening),
                ),
            )
        }

        fun testConfig(
            context: android.content.Context,
            args: Map<*, *>,
        ) {
            Log.i(tag, "testConfig requested")
            startWakeSession(
                context,
                args + mapOf("openingAnnouncement" to "实时语音秘书测试。"),
            )
            mainHandler.postDelayed({ stopCurrentSession() }, testSessionDurationMs)
        }

        fun sendContextTextQuery(text: String) {
            val speechEngine = engine ?: return
            checkDirective(
                "DIRECTIVE_EVENT_CHAT_TEXT_QUERY",
                speechEngine.sendDirective(
                    SpeechEngineDefines.DIRECTIVE_EVENT_CHAT_TEXT_QUERY,
                    contentPayload(text),
                ),
            )
        }

        fun speakVoiceAnnouncementTextQuery(
            context: android.content.Context,
            args: Map<*, *>,
        ) {
            val text = (args["text"] as? String)?.takeIf { it.isNotBlank() }
                ?: throw IllegalArgumentException("text is required")
            Log.i(tag, "speakVoiceAnnouncementTextQuery requested")
            val speechEngine = ensureEngine(context, args)
            speechEngine.sendDirective(SpeechEngineDefines.DIRECTIVE_SYNC_STOP_ENGINE, "")
            val sessionArgs = args + mapOf("inputMode" to "text")
            checkDirective(
                "DIRECTIVE_START_ENGINE",
                speechEngine.sendDirective(
                    SpeechEngineDefines.DIRECTIVE_START_ENGINE,
                    startSessionPayload(sessionArgs),
                ),
            )
            checkDirective(
                "DIRECTIVE_EVENT_CHAT_TEXT_QUERY",
                speechEngine.sendDirective(
                    SpeechEngineDefines.DIRECTIVE_EVENT_CHAT_TEXT_QUERY,
                    contentPayload(text),
                ),
            )
            startVoiceAnnouncementSafetyTimeout()
        }

        fun stopCurrentSession() {
            Log.i(tag, "stopCurrentSession requested")
            clearVoiceAnnouncementState()
            engine?.sendDirective(SpeechEngineDefines.DIRECTIVE_SYNC_STOP_ENGINE, "")
        }

        fun shutdownEngine() {
            stopCurrentSession()
            engine?.destroyEngine()
            engine = null
        }

        private fun ensureEngine(
            context: android.content.Context,
            args: Map<*, *>,
        ): SpeechEngine {
            val current = engine
            if (current != null) {
                configureEngine(current, args)
                return current
            }
            val application = context.applicationContext as android.app.Application
            if (!environmentPrepared) {
                SpeechEngineGenerator.PrepareEnvironment(application, application)
                environmentPrepared = true
            }
            return SpeechEngineGenerator.getInstance().also { speechEngine ->
                speechEngine.setContext(application)
                speechEngine.setListener(object : SpeechEngine.SpeechListener {
                    override fun onSpeechMessage(type: Int, data: ByteArray, len: Int) {
                        handleSpeechMessage(type, data, len)
                    }
                })
                speechEngine.createEngine()
                configureEngine(speechEngine, args)
                checkDirective("initEngine", speechEngine.initEngine())
                engine = speechEngine
            }
        }

        private fun configureEngine(speechEngine: SpeechEngine, args: Map<*, *>) {
            speechEngine.setOptionString(
                SpeechEngineDefines.PARAMS_KEY_ENGINE_NAME_STRING,
                SpeechEngineDefines.DIALOG_ENGINE,
            )
            speechEngine.setOptionString(
                SpeechEngineDefines.PARAMS_KEY_APP_ID_STRING,
                args["appId"] as? String ?: "",
            )
            speechEngine.setOptionString(
                SpeechEngineDefines.PARAMS_KEY_APP_KEY_STRING,
                args["appKey"] as? String ?: "",
            )
            speechEngine.setOptionString(
                SpeechEngineDefines.PARAMS_KEY_APP_TOKEN_STRING,
                args["accessToken"] as? String ?: "",
            )
            speechEngine.setOptionString(
                SpeechEngineDefines.PARAMS_KEY_RESOURCE_ID_STRING,
                args["resourceId"] as? String ?: "volc.speech.dialog",
            )
            speechEngine.setOptionString(
                SpeechEngineDefines.PARAMS_KEY_UID_STRING,
                "talk-realtime-secretary",
            )
            speechEngine.setOptionString(
                SpeechEngineDefines.PARAMS_KEY_DIALOG_ADDRESS_STRING,
                dialogAddress,
            )
            speechEngine.setOptionString(
                SpeechEngineDefines.PARAMS_KEY_DIALOG_URI_STRING,
                dialogUri,
            )
            speechEngine.setOptionBoolean(
                SpeechEngineDefines.PARAMS_KEY_ENABLE_AEC_BOOL,
                false,
            )
            speechEngine.setOptionString(
                SpeechEngineDefines.PARAMS_KEY_RECORDER_TYPE_STRING,
                SpeechEngineDefines.RECORDER_TYPE_RECORDER,
            )
            speechEngine.setOptionString(
                SpeechEngineDefines.PARAMS_KEY_DIALOG_RECORDER_PATH_STRING,
                "",
            )
            speechEngine.setOptionBoolean(
                SpeechEngineDefines.PARAMS_KEY_DIALOG_ENABLE_RECORDER_AUDIO_CALLBACK_BOOL,
                false,
            )
            speechEngine.setOptionBoolean(
                SpeechEngineDefines.PARAMS_KEY_DIALOG_ENABLE_PLAYER_BOOL,
                true,
            )
            speechEngine.setOptionBoolean(
                SpeechEngineDefines.PARAMS_KEY_DIALOG_ENABLE_PLAYER_AUDIO_CALLBACK_BOOL,
                true,
            )
            speechEngine.setOptionBoolean(
                SpeechEngineDefines.PARAMS_KEY_DIALOG_ENABLE_DECODER_AUDIO_CALLBACK_BOOL,
                true,
            )
            speechEngine.setOptionString(
                SpeechEngineDefines.PARAMS_KEY_DIALOG_PLAYER_PATH_STRING,
                "",
            )
            speechEngine.setOptionInt(
                SpeechEngineDefines.PARAMS_KEY_AUDIO_STREAM_TYPE_INT,
                SpeechEngineDefines.AUDIO_STREAM_TYPE_MEDIA,
            )
        }

        private fun handleSpeechMessage(type: Int, data: ByteArray, len: Int) {
            when (type) {
                SpeechEngineDefines.MESSAGE_TYPE_PLAYER_AUDIO_DATA -> {
                    Log.d(tag, "player audio callback len=$len")
                    scheduleVoiceAnnouncementAudioIdleStop(len)
                    return
                }
                SpeechEngineDefines.MESSAGE_TYPE_DECODER_AUDIO_DATA -> {
                    Log.d(tag, "decoder audio callback len=$len")
                    scheduleVoiceAnnouncementAudioIdleStop(len)
                    return
                }
                SpeechEngineDefines.MESSAGE_TYPE_DIALOG_ASR_INFO -> {
                    Log.d(tag, "asr started")
                    notifySpeechStarted()
                    return
                }
                SpeechEngineDefines.MESSAGE_TYPE_DIALOG_ASR_ENDED -> {
                    Log.d(tag, "asr ended")
                    notifySpeechEnded()
                    return
                }
                SpeechEngineDefines.MESSAGE_TYPE_ENGINE_STOP -> {
                    Log.i(tag, "engine stopped")
                    clearVoiceAnnouncementState()
                    notifySessionEnded("engine_stop")
                    return
                }
                SpeechEngineDefines.MESSAGE_TYPE_DIALOG_SESSION_FINISHED -> {
                    Log.i(tag, "dialog session finished")
                    clearVoiceAnnouncementState()
                    notifySessionEnded("session_finished")
                    return
                }
                SpeechEngineDefines.MESSAGE_TYPE_DIALOG_SESSION_FAILED -> {
                    Log.w(tag, "dialog session failed: ${payloadText(data, len)}")
                    clearVoiceAnnouncementState()
                    notifySessionEnded("session_failed")
                    return
                }
                SpeechEngineDefines.MESSAGE_TYPE_ENGINE_ERROR -> {
                    Log.w(tag, "engine error: ${payloadText(data, len)}")
                    clearVoiceAnnouncementState()
                    notifySessionEnded("engine_error")
                    return
                }
            }
            if (type != SpeechEngineDefines.MESSAGE_TYPE_DIALOG_ASR_RESPONSE) return
            val safeLen = len.coerceIn(0, data.size)
            if (safeLen == 0) return
            notifySpeechStarted()
            val raw = payloadText(data, len)
            val text = extractAsrText(raw)
            if (text.isBlank()) {
                Log.d(tag, "ignore non-text asr payload: $raw")
                return
            }
            mainHandler.post {
                flutterChannel?.invokeMethod(
                    "onRealtimeSecretaryAsrText",
                    mapOf("text" to text),
                )
            }
        }

        private fun startVoiceAnnouncementSafetyTimeout() {
            clearVoiceAnnouncementState()
            voiceAnnouncementActive = true
            val runnable = Runnable {
                Log.w(tag, "voice announcement safety timeout, stopping session")
                stopCurrentSession()
            }
            voiceAnnouncementSafetyRunnable = runnable
            mainHandler.postDelayed(runnable, voiceAnnouncementSafetyTimeoutMs)
        }

        private fun scheduleVoiceAnnouncementAudioIdleStop(len: Int) {
            if (!voiceAnnouncementActive || len <= 0) return
            voiceAnnouncementAudioIdleRunnable?.let { mainHandler.removeCallbacks(it) }
            val runnable = Runnable {
                Log.i(tag, "voice announcement audio idle, stopping session")
                stopCurrentSession()
            }
            voiceAnnouncementAudioIdleRunnable = runnable
            mainHandler.postDelayed(runnable, voiceAnnouncementAudioIdleStopMs)
        }

        private fun clearVoiceAnnouncementState() {
            voiceAnnouncementActive = false
            voiceAnnouncementAudioIdleRunnable?.let { mainHandler.removeCallbacks(it) }
            voiceAnnouncementSafetyRunnable?.let { mainHandler.removeCallbacks(it) }
            voiceAnnouncementAudioIdleRunnable = null
            voiceAnnouncementSafetyRunnable = null
        }

        private fun notifySessionEnded(reason: String) {
            mainHandler.post {
                flutterChannel?.invokeMethod(
                    "onRealtimeSecretarySessionEnded",
                    mapOf("reason" to reason),
                )
            }
        }

        private fun notifySpeechStarted() {
            mainHandler.post {
                flutterChannel?.invokeMethod("onRealtimeSecretarySpeechStarted", null)
            }
        }

        private fun notifySpeechEnded() {
            mainHandler.post {
                flutterChannel?.invokeMethod("onRealtimeSecretarySpeechEnded", null)
            }
        }

        private fun checkDirective(name: String, code: Int) {
            if (code != 0) {
                throw IllegalStateException("$name failed: $code")
            }
        }

        private fun contentPayload(content: String): String {
            return JSONObject().put("content", content).toString()
        }

        private fun payloadText(data: ByteArray, len: Int): String {
            val safeLen = len.coerceIn(0, data.size)
            if (safeLen == 0) return ""
            return data.copyOfRange(0, safeLen).toString(Charsets.UTF_8)
        }

        private fun extractAsrText(raw: String): String {
            val trimmed = raw.trim()
            if (trimmed.startsWith("{")) {
                val jsonText = extractAsrTextFromJson(trimmed)
                if (jsonText.isNotBlank()) return jsonText
            }
            return Regex("[\\u4E00-\\u9FFF，。！？、；：,.!?\\s]+")
                .findAll(trimmed)
                .map { it.value.trim() }
                .filter { it.any { ch -> ch in '\u4E00'..'\u9FFF' } }
                .joinToString("")
                .trim()
        }

        private fun extractAsrTextFromJson(raw: String): String {
            return try {
                val root = JSONObject(raw)
                for (key in listOf("text", "utterance", "asr_text")) {
                    val value = root.optString(key, "")
                    if (value.isNotBlank()) return value
                }
                val results = root.optJSONArray("results")
                if (results != null && results.length() > 0) {
                    return results.optJSONObject(results.length() - 1)
                        ?.optString("text", "")
                        ?: ""
                }
                ""
            } catch (_: Exception) {
                ""
            }
        }

        private fun startSessionPayload(args: Map<*, *>): String {
            val botName = (args["secretaryName"] as? String)
                ?.takeIf { it.isNotBlank() }
                ?: "小智"
            val systemRole = (args["systemRole"] as? String)
                ?.takeIf { it.isNotBlank() }
            val speakingStyle = (args["speakingStyle"] as? String)
                ?.takeIf { it.isNotBlank() }
            val initialContextText = (args["initialContextText"] as? String)
                ?.takeIf { it.isNotBlank() }
            val inputMode = (args["inputMode"] as? String)
                ?.takeIf { it.isNotBlank() }
            val model = (args["model"] as? String)
                ?.takeIf { it.isNotBlank() }
                ?: "1.2.1.1"
            val speaker = (args["speaker"] as? String)
                ?.takeIf { it.isNotBlank() }
                ?: "zh_female_vv_jupiter_bigtts"
            val speechRate = (args["speechRate"] as? Number)?.toInt() ?: 0
            val loudnessRate = (args["loudnessRate"] as? Number)?.toInt() ?: 0
            val extra = JSONObject().put("model", model)
            inputMode?.let { extra.put("input_mod", it) }
            val dialog = JSONObject()
                .put("bot_name", botName)
                .put("extra", extra)
            systemRole?.let { dialog.put("system_role", it) }
            speakingStyle?.let { dialog.put("speaking_style", it) }
            initialContextText?.let {
                dialog.put(
                    "dialog_context",
                    JSONArray()
                        .put(JSONObject().put("role", "user").put("text", it))
                        .put(
                            JSONObject()
                                .put("role", "assistant")
                                .put("text", "我已收到这段消息上下文。用户询问时，我会严格基于这些内容回答。"),
                        ),
                )
            }
            return JSONObject()
                .put("dialog", dialog)
                .put(
                    "tts",
                    JSONObject()
                        .put("speaker", speaker)
                        .put(
                            "audio_config",
                            JSONObject()
                                .put("speech_rate", speechRate)
                                .put("loudness_rate", loudnessRate),
                        ),
                )
                .toString()
        }
    }
}
