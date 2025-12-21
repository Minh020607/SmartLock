import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  MqttServerClient? _client;

  final String broker = "broker.emqx.io";
  final int port = 1883; // ❗ Chỉnh về 1883 để tránh lỗi SSL

  /// Danh sách topic đang subscribe
  final Set<String> _subscribedTopics = {};

  /// Callback khi nhận message
  /// Map = { "lockId": "...", "locked": true/false, "online": true/false }
  Function(String lockId, Map<String, dynamic> data)? onMessage;

  // -----------------------------
  // 🔌 KẾT NỐI MQTT
  // -----------------------------
  bool _shouldReconnect = true;
  bool _listening = false;


  Future<void> connect() async {
      _shouldReconnect = true;
    if (_client != null &&
        _client!.connectionStatus!.state == MqttConnectionState.connected) {
      return; // Đã kết nối
    }

    _client = MqttServerClient(broker, "flutter_${DateTime.now().millisecondsSinceEpoch}");
    _client!.port = port;
    _client!.keepAlivePeriod = 20;
    _client!.logging(on: false);

    _client!.onDisconnected = () {
  print("⚠ MQTT disconnected");

  if (_shouldReconnect) {
    Future.delayed(const Duration(seconds: 3), connect);
  }
};

    try {
      await _client!.connect();
      print("✅ MQTT CONNECTED");
    } catch (e) {
      print("❌ MQTT connect error: $e");
      _client!.disconnect();
      return;
    }

    // Bắt đầu nhận message
    if (!_listening) {
  _client!.updates!.listen(_handleMessage);
  _listening = true;
}

  }

  // -----------------------------
  // 📌 ĐĂNG KÝ TOPIC CHO 1 KHÓA
  // -----------------------------
  Future<void> subscribeLock(String lockId) async {
    await connect(); // đảm bảo đã kết nối

    final topic = "smartlock/$lockId/status";

    if (_subscribedTopics.contains(topic)) return;

    _client!.subscribe(topic, MqttQos.atLeastOnce);
    _subscribedTopics.add(topic);

    print("📡 Subscribed: $topic");
  }

  Future<void> unsubscribeLock(String lockId) async {
  if (_client == null || _client!.connectionStatus?.state != MqttConnectionState.connected) {
    return;
  }

  final topic = "smartlock/$lockId/status";

  if (!_subscribedTopics.contains(topic)) return;

  _client!.unsubscribe(topic);
  _subscribedTopics.remove(topic);

  print("📴 Unsubscribed: $topic");
}

Future<void> unsubscribeAll() async {
  _shouldReconnect = false;
  _listening = false;

  if (_client == null) return;

  for (final topic in _subscribedTopics) {
    _client!.unsubscribe(topic);
    print("📴 Unsubscribed: $topic");
  }

  _subscribedTopics.clear();

  _client!.disconnect();
  _client = null;

  print("🔌 MQTT fully disconnected");
}


  // -----------------------------
  // 📥 XỬ LÝ MESSAGE MQTT
  // -----------------------------
  void _handleMessage(List<MqttReceivedMessage> events) {
    final MqttPublishMessage recMsg = events[0].payload as MqttPublishMessage;
    final topic = events[0].topic;

    final payload =
        MqttPublishPayload.bytesToStringAsString(recMsg.payload.message);

    print("📩 MQTT Message from $topic → $payload");

    try {
      final data = jsonDecode(payload);

      // Lấy lockId từ topic
      final segments = topic.split('/');
      final lockId = segments[1];

      // Gửi về UI
      if (onMessage != null) {
        onMessage!(lockId, data);
      }
    } catch (e) {
      print("❌ Invalid JSON");
    }
  }

  // -----------------------------
  // 🚀 GỬI LỆNH ĐIỀU KHIỂN
  // -----------------------------

  Future<void> sendCommand(String lockId, bool lock, String by) async {
  await connect();

  final topic = "smartlock/$lockId/cmd";

  final payload = jsonEncode({
    "action": lock ? "lock" : "unlock",
    "by": by,
  });

  final builder = MqttClientPayloadBuilder();
  builder.addString(payload);

  _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
   print("🚀 MQTT Sent → $topic : $payload");
}

  
}

final mqttService = MqttService();
