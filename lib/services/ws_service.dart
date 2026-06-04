import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/config.dart';

class WsService {
  static final WsService _instance = WsService._internal();
  factory WsService() => _instance;
  WsService._internal();

  final Map<String, WebSocketChannel> _channels = {};
  final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};
  final Map<String, Timer?> _pingTimers = {};
  final Map<String, bool> _connected = {};
  final Map<String, int> _reconnectAttempts = {};
  final Map<String, StreamSubscription<List<ConnectivityResult>>> _connectivitySubs = {};

  static const _maxReconnectAttempts = 10;
  static const _baseDelayMs = 1000;
  static const _maxDelayMs = 30000;
  static const _pingIntervalSec = 15;

  Stream<Map<String, dynamic>> connect({
    required String tenantId,
    required String incidentId,
    required String token,
  }) {
    final key = '$tenantId:$incidentId';

    _controllers[key]?.close();
    _controllers[key] = StreamController<Map<String, dynamic>>.broadcast();

    _connectivitySubs[key]?.cancel();
    final sub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        _attemptReconnect(tenantId, incidentId, token);
      }
    });
    _connectivitySubs[key] = sub;

    _establishConnection(tenantId, incidentId, token, key);

    return _controllers[key]!.stream;
  }

  Future<void> _establishConnection(
    String tenantId,
    String incidentId,
    String token,
    String key,
  ) async {
    try {
      final url = '${Config.wsUrl}/ws/$tenantId/$incidentId?token=$token';
      final channel = WebSocketChannel.connect(Uri.parse(url));

      _channels[key]?.sink.close();
      _channels[key] = channel;

      _pingTimers[key]?.cancel();
      _pingTimers[key] = Timer.periodic(
        const Duration(seconds: _pingIntervalSec),
        (_) => _sendPing(key),
      );

      channel.stream.listen(
        (event) {
          if (event is String) {
            final msg = jsonDecode(event) as Map<String, dynamic>;
            _controllers[key]?.add(msg);
            if (msg['type'] != 'PONG') {
              _connected[key] = true;
              _reconnectAttempts[key] = 0;
            }
          } else if (event is Map) {
            _controllers[key]?.add(Map<String, dynamic>.from(event));
          }
        },
        onError: (e) {
          _connected[key] = false;
          _controllers[key]?.addError(e);
          _scheduleReconnect(tenantId, incidentId, token, key);
        },
        onDone: () {
          _connected[key] = false;
          _scheduleReconnect(tenantId, incidentId, token, key);
        },
      );

      _connected[key] = true;
      _reconnectAttempts[key] = 0;
    } catch (e) {
      _connected[key] = false;
      _scheduleReconnect(tenantId, incidentId, token, key);
    }
  }

  void _sendPing(String key) {
    final channel = _channels[key];
    if (channel != null) {
      try {
        channel.sink.add(jsonEncode({'type': 'PING'}));
      } catch (_) {}
    }
  }

  void _scheduleReconnect(
    String tenantId,
    String incidentId,
    String token,
    String key,
  ) {
    _pingTimers[key]?.cancel();
    _channels[key]?.sink.close();
    _connectivitySubs[key]?.cancel();

    final attempts = _reconnectAttempts[key] ?? 0;
    if (attempts >= _maxReconnectAttempts) {
      _controllers[key]?.addError('Max reconnection attempts reached');
      return;
    }

    final delayMs = min(_baseDelayMs * pow(2, attempts).toInt(), _maxDelayMs);
    _reconnectAttempts[key] = attempts + 1;

    Future.delayed(Duration(milliseconds: delayMs), () {
      _attemptReconnect(tenantId, incidentId, token);
    });
  }

  Future<void> _attemptReconnect(
    String tenantId,
    String incidentId,
    String token,
  ) async {
    final key = '$tenantId:$incidentId';
    if (_connected[key] == true) return;
    await _establishConnection(tenantId, incidentId, token, key);
  }

  void send(String tenantId, String incidentId, Map<String, dynamic> payload) {
    final key = '$tenantId:$incidentId';
    final channel = _channels[key];
    if (channel != null) {
      try {
        channel.sink.add(jsonEncode(payload));
      } catch (_) {}
    }
  }

  void close({String? tenantId, String? incidentId}) {
    if (tenantId != null && incidentId != null) {
      final key = '$tenantId:$incidentId';
      _pingTimers[key]?.cancel();
      _channels[key]?.sink.close();
      _controllers[key]?.close();
      _connectivitySubs[key]?.cancel();
      _connectivitySubs.remove(key);
      _channels.remove(key);
      _controllers.remove(key);
      _pingTimers.remove(key);
      _connected.remove(key);
      _reconnectAttempts.remove(key);
    } else {
      for (final key in _channels.keys.toList()) {
        _pingTimers[key]?.cancel();
        _channels[key]?.sink.close();
        _controllers[key]?.close();
        _connectivitySubs[key]?.cancel();
      }
      _connectivitySubs.clear();
      _channels.clear();
      _controllers.clear();
      _pingTimers.clear();
      _connected.clear();
      _reconnectAttempts.clear();
    }
  }

  bool isConnected(String tenantId, String incidentId) {
    return _connected['$tenantId:$incidentId'] ?? false;
  }
}