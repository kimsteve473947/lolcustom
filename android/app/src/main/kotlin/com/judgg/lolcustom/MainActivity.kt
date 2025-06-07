package com.judgg.lolcustom

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.annotation.NonNull

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.judgg.lolcustom/notifications"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 알림 채널 생성
        createNotificationChannels()
        
        // 메서드 채널 설정
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "createNotificationChannels" -> {
                    createNotificationChannels()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    // 알림 채널 생성 메서드
    private fun createNotificationChannels() {
        // Android 8.0 (Oreo) 이상에서만 알림 채널이 필요함
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // 메인 채널
            val mainChannel = NotificationChannel(
                "main_channel",
                "Main Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "General notifications from the app"
                enableLights(true)
                enableVibration(true)
            }
            
            // 채팅 채널
            val chatChannel = NotificationChannel(
                "chat_channel",
                "Chat Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for chat messages"
                enableLights(true)
                enableVibration(true)
            }
            
            // 토너먼트 채널
            val tournamentChannel = NotificationChannel(
                "tournament_channel",
                "Tournament Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications related to tournaments"
                enableLights(true)
                enableVibration(true)
            }
            
            // 채널 등록
            notificationManager.createNotificationChannels(
                listOf(mainChannel, chatChannel, tournamentChannel)
            )
        }
    }
}
