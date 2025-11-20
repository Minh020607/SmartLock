import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:smart_lock/service.dart/history_service.dart';


class MqttService {
  late MqttServerClient client;//kết nối , giao tiếp với broker
  final String broker = "broker.emqx.io";//địa chỉ MQTT
  final int port = 8883;

  Function(Map<String, dynamic>)? onStatusMessage;

  //Thiết lập khởi tạo đến broker
  Future<void> connect(String lockId) async {
    client = MqttServerClient(broker, "flutter_${DateTime.now().millisecondsSinceEpoch}");
    client.port = port;
    client.logging(on: false);//tắt ghi log chi tiết của thư viện
    client.keepAlivePeriod = 20;//thời gian duy trì kết nối

    client.onDisconnected = () {
      print("MQTT Disconnected");
    };

    final connMess = MqttConnectMessage()
        .withClientIdentifier("flutter_${DateTime.now().millisecondsSinceEpoch}")
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMess;

    try {
      await client.connect();
      print("MQTT Connected");
    } catch (e) {
      print("MQTT ERROR: $e");
      client.disconnect();
      return;
    }

    _subscribeToStatus(lockId);// nếu kết nối thành công , nhận trạng thái khóa
  }

  void _subscribeToStatus(String lockId) {
    final topic = "smartlock/$lockId/status";// tạo topic 

    client.subscribe(topic, MqttQos.atMostOnce);// đăng kí topic 
    print("Subscribed to $topic");

    client.updates!.listen((messages) {
      final MqttPublishMessage msg = messages[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(msg.payload.message);

      try {
        final data = jsonDecode(payload);
        // --- LOGIC GHI LỊCH SỬ KHI NHẬN PHẢN HỒI THÀNH CÔNG ---
        if (data["success"] == true) {
            // Kiểm tra xem hành động có tồn tại không
            final action = data["action"] as String?; 
            if (action != null) {
                // Sử dụng HistoryService để ghi lại hành động
                historyService.save(lockId, action); 
                print("Lịch sử hành động '$action' đã được ghi lại.");
            }
        }
        if (onStatusMessage != null) onStatusMessage!(data);
      } catch (e) {
        print("Invalid JSON from MQTT");
      }
    });
  }
 // Điều khiển khóa thông minh
  void sendCommand(String lockId, String action) {
    final topic = "smartlock/$lockId/cmd";

    final payload = jsonEncode({
      "action": action,
      "timestamp": DateTime.now().millisecondsSinceEpoch
    });
    //Đóng gói json thành định dạng byte mqtt yêu cầu
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }
}

final mqttService = MqttService();
