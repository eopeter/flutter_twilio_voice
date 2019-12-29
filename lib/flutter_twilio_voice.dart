import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FlutterTwilioVoice {
  static const MethodChannel _channel =
      const MethodChannel('flutter_twilio_voice');

  static const EventChannel _eventChannel =
      EventChannel('flutter_twilio_voice');

  /*static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }*/

  static Stream<dynamic> get phoneCallEventSubscription {
    return _eventChannel.receiveBroadcastStream();
  }

  static Future<void> accessToken({@required String accessToken}) async {
    assert(accessToken != null);
    final Map<String, Object> args = <String, dynamic>{"token": accessToken};
    await _channel.invokeMethod('accessToken', args);
  }

  static Future<void> makeCall(
      {String from, @required String to, String toDisplayName}) async {
    assert(to != null);
    final Map<String, Object> args = <String, dynamic>{
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
    assert(clientIdentifier != null);
    final Map<String, Object> args = <String, dynamic>{
      "clientIdentifier": clientIdentifier
    };
    await _channel.invokeMethod('receiveCalls', args);
  }

  static Future<void> muteCall(bool isMuted) async {
    assert(isMuted != null);
    final Map<String, Object> args = <String, dynamic>{"isMuted": isMuted};
    await _channel.invokeMethod('muteCall', args);
  }

  static Future<void> toggleSpeaker(bool speakerIsOn) async {
    assert(speakerIsOn != null);
    final Map<String, Object> args = <String, dynamic>{
      "speakerIsOn": speakerIsOn
    };
    await _channel.invokeMethod('toggleSpeaker', args);
  }
}
