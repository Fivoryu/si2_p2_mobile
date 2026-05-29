import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/config.dart';

class WsService {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;

  Stream<Map<String, dynamic>> connect({
    required String tenantId,
    required String incidentId,
    required String token,
  }) {
    close();
    final url = '${Config.wsUrl}/ws/$tenantId/$incidentId?token=$token';
    _channel = WebSocketChannel.connect(Uri.parse(url));

    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      send({'type': 'PING'});
    });

    return _channel!.stream.map((event) {
      if (event is String) {
        return jsonDecode(event) as Map<String, dynamic>;
      }
      return Map<String, dynamic>.from(event as Map);
    });
  }

  void send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  void close() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }
}
