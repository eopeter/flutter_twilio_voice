import 'dart:async';

import 'package:flutter/services.dart';

class FlutterTwilioVoice {
  static const MethodChannel _channel =
      const MethodChannel('flutter_twilio_voice');

  static const EventChannel _eventChannel =
      EventChannel('flutter_twilio_voice');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Stream<dynamic> get phoneCallEventSubscription {
    return _eventChannel.receiveBroadcastStream();
  }

  static Future<void> makeCall(
      {required String accessTokenUrl,
      required String from,
      required String to,
      String? toDisplayName}) async {
    assert(from.trim() != "");
    assert(to.trim() != "");
    final Map<String, dynamic> args = <String, dynamic>{
      "accessTokenUrl": accessTokenUrl,
      "from": from,
      "to": to,
      "toDisplayName": toDisplayName
    };
    await _channel.invokeMethod('makeCall', args);
  }

  static Future<void> hangUp() async {
    await _channel.invokeMethod('hangUp');
  }

  static Future<void> receiveCalls(String clientIdentifier) async {
    final Map<String, dynamic> args = <String, dynamic>{
      "clientIdentifier": clientIdentifier
    };
    await _channel.invokeMethod('receiveCalls', args);
  }

  static Future<void> muteCall(bool isMuted) async {
    final Map<String, dynamic> args = <String, dynamic>{"isMuted": isMuted};
    await _channel.invokeMethod('muteCall', args);
  }

  static Future<void> toggleSpeaker(bool speakerIsOn) async {
    final Map<String, dynamic> args = <String, dynamic>{
      "speakerIsOn": speakerIsOn
    };
    await _channel.invokeMethod('toggleSpeaker', args);
  }
}
