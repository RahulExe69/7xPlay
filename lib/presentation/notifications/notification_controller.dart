import 'dart:async';
import 'package:flixquest/data/sources/onesignal_messaging_client.dart';
import 'push_message_controller.dart';
import 'package:flixquest/data/sources/push_messaging_client.dart';
import 'device_registration_controller.dart';
import 'in_app_message_controller.dart';

class NotificationController {
  const NotificationController(this.devices, this.messages, this.messaging,
      {this.pushMessages});
  final DeviceRegistrationController devices;
  final InAppMessageController messages;
  final PushMessagingClient messaging;
  final PushMessageController? pushMessages;
  Future<void> receive(Map<String, dynamic> data) =>
      pushMessages?.receive(data) ?? messages.receive(data);
  Future<void> boot() async => Future.wait([devices.boot(), messages.boot()]);
  Future<void> onResume() async =>
      Future.wait([devices.onResume(), messages.onResume()]);
  void dispose() {
    pushMessages?.dispose();
    if (messaging is OneSignalMessagingClient) {
      unawaited((messaging as OneSignalMessagingClient).dispose());
    }
    devices.dispose();
    messages.dispose();
  }
}
