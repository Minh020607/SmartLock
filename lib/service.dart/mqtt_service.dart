import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  MqttServerClient? _client;

  // Thông tin lấy từ ảnh chụp màn hình của bạn
  final String broker = "d60daf22.ala.asia-southeast1.emqxsl.com";
  final int port = 8883; 


  // Thông tin lấy từ ảnh mục Authentication của bạn
  final String username = "anhminh";
  final String password = "020623";

  final Set<String> _subscribedTopics = {};
  Function(String lockId, Map<String, dynamic> data)? onMessage;

  bool _isConnecting = false;

  // ===== HÀM KẾT NỐI CHUẨN =====
  Future<bool> connect() async {
  if (_isConnecting) return false;
  if (_client?.connectionStatus?.state == MqttConnectionState.connected) return true;

  _isConnecting = true;
  // Dùng ClientID ngắn gọn để máy Oppo dễ xử lý
  final clientId = "oppo_lock_${DateTime.now().millisecondsSinceEpoch.toString().substring(10)}";
  
  _client = MqttServerClient(broker, clientId);
  _client!
    ..port = 8883 
    ..secure = true 
    ..keepAlivePeriod = 60
    ..connectTimeoutPeriod = 20000 
    ..autoReconnect = true 
    ..setProtocolV311()
    ..onDisconnected = _onDisconnected;

  _client!.onBadCertificate = (dynamic cert) => true;

  final connMess = MqttConnectMessage()
      .withClientIdentifier(clientId)
      .authenticateAs("anhminh", "020623") // Khớp hoàn toàn với Console
      .startClean();

  _client!.connectionMessage = connMess;

  try {
    print("⏳ Đang kết nối SSL đến EMQX...");
    await _client!.connect();
    
    // Đợi 1 giây để trạng thái kết nối cập nhật xong trên Android
    await Future.delayed(const Duration(seconds: 1));

    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      print("✅ MQTT CONNECTED!");
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
    print("⚠ MQTT Disconnected");
    _subscribedTopics.clear();
    _isConnecting = false;
  }

  // ===== SUBSCRIBE =====
  Future<void> subscribeLock(String lockId) async {
    // Đảm bảo kết nối xong mới tiến hành Sub
    bool success = await connect();

    if (success) {
      final topic = "smartlock/$lockId/status";
      if (_subscribedTopics.contains(topic)) return;

      print("📡 Đang đăng ký topic: $topic");
      _client!.subscribe(topic, MqttQos.atLeastOnce);
      _subscribedTopics.add(topic);
    } else {
      print("❌ Không thể Sub vì kết nối thất bại");
    }
  }

  // ===== GỬI LỆNH =====
  Future<void> sendCommand(String lockId, bool lock, String by) async {
    bool success = await connect();

    if (success) {
      final topic = "smartlock/$lockId/cmd";
      final payload = jsonEncode({
        "action": lock ? "lock" : "unlock",
        "by": by,
      });

      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);

      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      print("🚀 Đã gửi: $payload");
    }
  }

  void _handleMessage(List<MqttReceivedMessage<MqttMessage>> events) {
    final recMsg = events[0].payload as MqttPublishMessage;
    final topic = events[0].topic;
    final payload = MqttPublishPayload.bytesToStringAsString(recMsg.payload.message);

    print("📩 Nhận tin: $topic -> $payload");

    try {
      Map<String, dynamic> data = jsonDecode(payload);
      
      // ===== CHUẨN HÓA DỮ LIỆU TẠI ĐÂY =====
      if (data.containsKey('online')) {
        data['isOnline'] = data['online'];
      }
      if (data.containsKey('locked')) {
        data['isLocked'] = data['locked'];
      }
      
      // 🔥 THÊM DÒNG NÀY:
      // Đảm bảo phím 'battery' từ ESP32 được giữ nguyên hoặc gán vào data
      // (LockModel của bạn đã đọc json['battery'] nên thực tế chỉ cần data có chứa phím này)
      if (data.containsKey('battery')) {
        print("🔋 Pin nhận được từ ESP32: ${data['battery']}%");
      }

      final lockId = topic.split('/')[1];
      onMessage?.call(lockId, data); // Gửi data đã có 'battery' sang Provider
    } catch (e) {
      print("❌ Lỗi parse JSON: $e");
    }
  }

  void unsubscribeAll() {
    _client?.disconnect();
    _client = null;
    _subscribedTopics.clear();
  }
}

final mqttService = MqttService();