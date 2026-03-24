import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

/// Service for sending FCM push notifications directly from the client.
/// Uses FCM v1 HTTP API with service account credentials loaded from assets.
class FcmService {
  static const _projectId = 'rtx-lalbus-0916';
  static String? _cachedToken;
  static DateTime? _tokenExpiry;

  /// Get a valid OAuth2 access token for FCM API calls.
  static Future<String> _getAccessToken() async {
    // Return cached token if still valid (with 5 min buffer)
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)))) {
      return _cachedToken!;
    }

    try {
      // Load service account JSON from assets
      final jsonString = await rootBundle.loadString('assets/service_account.json');
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      final credentials = ServiceAccountCredentials.fromJson(json);
      final client = await clientViaServiceAccount(
        credentials,
        ['https://www.googleapis.com/auth/firebase.messaging'],
      );
      _cachedToken = client.credentials.accessToken.data;
      _tokenExpiry = client.credentials.accessToken.expiry;
      client.close();
      return _cachedToken!;
    } catch (e) {
      debugPrint('Error getting FCM access token: $e');
      rethrow;
    }
  }

  /// Send a push notification to all subscribers of a topic.
  static Future<void> sendToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final accessToken = await _getAccessToken();
      final url = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'topic': topic,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              ...?data,
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('FCM notification sent to topic: $topic');
      } else {
        debugPrint('FCM send failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending FCM notification: $e');
    }
  }

  /// Sends a data-only FCM to tell all clients to cancel the notification.
  static Future<void> sendDeleteToTopic({
    required String topic,
    required String noticeId,
  }) async {
    try {
      final accessToken = await _getAccessToken();
      final url = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'topic': topic,
            'data': {
              'noticeId': noticeId,
              'isDelete': 'true',
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('FCM delete broadcast sent to $topic for $noticeId');
      }
    } catch (e) {
      debugPrint('Error sending FCM delete broadcast: $e');
    }
  }
}
