import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FlutterTwilioVoice {
  static final String ACTION_ACCEPT = "ACTION_ACCEPT";
  static final String ACTION_REJECT = "ACTION_REJECT";
  static final String ACTION_INCOMING_CALL_NOTIFICATION =
      "ACTION_INCOMING_CALL_NOTIFICATION";
  static final String ACTION_INCOMING_CALL = "ACTION_INCOMING_CALL";
  static final String ACTION_CANCEL_CALL = "ACTION_CANCEL_CALL";
  static final String ACTION_FCM_TOKEN = "ACTION_FCM_TOKEN";

  static const MethodChannel _channel =
      const MethodChannel('flutter_twilio_voice/messages');

  static const EventChannel _eventChannel =
      EventChannel('flutter_twilio_voice/events');

  /*static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }*/

  static Stream<dynamic> get phoneCallEventSubscription {
    return _eventChannel.receiveBroadcastStream();
  }

  static Future<bool> tokens(
      {@required String accessToken, @required String fcmToken}) {
    assert(accessToken != null);
    return _channel.invokeMethod('tokens',
        <String, dynamic>{"accessToken": accessToken, "fcmToken": fcmToken});
  }

  static Future<bool> makeCall(
      {@required String from, @required String to, String toDisplayName}) {
    assert(to != null);
    assert(from != null);
    return _channel.invokeMethod('makeCall', <String, dynamic>{
      "from": from,
      "to": to,
      "toDisplayName": toDisplayName
    });
  }

  static Future<bool> hangUp() {
    return _channel.invokeMethod('hangUp');
  }

  static Future<bool> answer() {
    return _channel.invokeMethod('answer');
  }

  /*static Future<bool> receiveCalls(String clientIdentifier) async {
    assert(clientIdentifier != null);
    final Map<String, Object> args = <String, dynamic>{
      "clientIdentifier": clientIdentifier
    };
    await _channel.invokeMethod('receiveCalls', args);
  }*/

  static Future<bool> holdCall() {
    return _channel.invokeMethod('holdCall');
  }

  static Future<bool> muteCall(bool isMuted) {
    assert(isMuted != null);
    return _channel
        .invokeMethod('muteCall', <String, dynamic>{"isMuted": isMuted});
  }

  static Future<bool> toggleSpeaker(bool speakerIsOn) {
    assert(speakerIsOn != null);
    return _channel.invokeMethod(
        'toggleSpeaker', <String, dynamic>{"speakerIsOn": speakerIsOn});
  }
}
