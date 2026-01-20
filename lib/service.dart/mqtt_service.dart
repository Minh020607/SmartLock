import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  MqttServerClient? _client;

  final String broker = "d60daf22.ala.asia-southeast1.emqxsl.com";
  final int port = 8883; 
  final String username = "anhminh";
  final String password = "020623";

  final Set<String> _subscribedTopics = {};
  Function(String lockId, Map<String, dynamic> data)? onMessage;
  bool _isConnecting = false;

  Future<bool> connect() async {
    if (_isConnecting) return false;
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) return true;

    _isConnecting = true;
    final clientId = "oppo_lock_${DateTime.now().millisecondsSinceEpoch.toString().substring(10)}";
    
    _client = MqttServerClient(broker, clientId);
    _client!
      ..port = port 
      ..secure = true 
      ..keepAlivePeriod = 60
      ..connectTimeoutPeriod = 20000 
      ..autoReconnect = true 
      ..setProtocolV311()
      ..onDisconnected = _onDisconnected;

    _client!.onBadCertificate = (dynamic cert) => true;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(username, password)
        .startClean();

    _client!.connectionMessage = connMess;

    try {
      await _client!.connect();
      if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
        _client!.updates!.listen(_handleMessage);
        return true;
      }
    } catch (e) {
      print("❌ Lỗi kết nối: $e");
    } finally {
      _isConnecting = false;
    }
    return false;
  }

  void _onDisconnected() {
    _subscribedTopics.clear();
    _isConnecting = false;
  }

  Future<void> subscribeLock(String lockId) async {
    bool success = await connect();
    if (success) {
      final topic = "smartlock/$lockId/status";
      if (_subscribedTopics.contains(topic)) return;
      _client!.subscribe(topic, MqttQos.atLeastOnce);
      _subscribedTopics.add(topic);
    }
  }

  // ⭐ BỔ SUNG: Hàm publish chung để dùng cho lệnh START_LEARNING
  Future<void> publish(String topic, String payload) async {
    bool success = await connect();
    if (success) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      print("📤 MQTT Sent: $topic -> $payload");
    }
  }

  Future<void> sendCommand(String lockId, bool lock, String by) async {
    final topic = "smartlock/$lockId/cmd";
    final payload = jsonEncode({
      "action": lock ? "lock" : "unlock",
      "by": by,
    });
    await publish(topic, payload); // Sử dụng hàm publish dùng chung
  }

  void _handleMessage(List<MqttReceivedMessage<MqttMessage>> events) {
    final recMsg = events[0].payload as MqttPublishMessage;
    final topic = events[0].topic;
    final payload = MqttPublishPayload.bytesToStringAsString(recMsg.payload.message);

    try {
      Map<String, dynamic> data = jsonDecode(payload);
      final String lockId = topic.split('/')[1];

      // Nếu là tin nhắn trạng thái bình thường, chuẩn hóa key
      if (data.containsKey('locked') || data.containsKey('battery')) {
        data['isOnline'] = data['online'] ?? true;
        data['isLocked'] = data['locked'] ?? true;
        data['battery'] = data['battery'] ?? 0;
      }

      // Gửi dữ liệu về LockProvider xử lý (bao gồm cả pending_id cho RFID)
      onMessage?.call(lockId, data); 

    } catch (e) {
      print("❌ Lỗi parse JSON MQTT: $e");
    }
  }

  void unsubscribeAll() {
    _client?.disconnect();
    _client = null;
    _subscribedTopics.clear();
  }
}

final mqttService = MqttService();