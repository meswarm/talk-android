import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../push/fcm_push_service.dart';
import '../theme/app_colors.dart';

class PushNotificationSettingsPage extends StatelessWidget {
  const PushNotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FcmPushService>();
    final token = service.token;

    return Scaffold(
      appBar: AppBar(title: const Text('FCM 推送通知')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '用于在 App 被系统回收后仍接收系统通知。当前 MVP 先显示本机 FCM Token，后续服务端会用它推送新消息。',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 20),
          Text(
            service.available ? '状态：已获取 Token' : '状态：未获取 Token',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (service.error != null) ...[
            const SizedBox(height: 12),
            Text(service.error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          SelectableText(token ?? '暂无 Token'),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => service.refreshToken(),
            child: const Text('刷新 Token'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: token == null
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: token));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Token 已复制'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  },
            child: const Text('复制 Token'),
          ),
        ],
      ),
    );
  }
}
