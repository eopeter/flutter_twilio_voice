import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CallState { ringing, connected, call_ended, unhold, hold, unmute, mute }

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

  static Stream<CallState> _onCallStateChanged;

  static Stream<CallState> get onCallStateChanged {
    if (_onCallStateChanged == null) {
      _onCallStateChanged = _eventChannel
          .receiveBroadcastStream()
          .map((dynamic event) => _parseCallState(event));
    }
    return _onCallStateChanged;
  }

  static Future<bool> tokens(
      {@required String accessToken, @required String fcmToken}) {
    assert(accessToken != null);
    return _channel.invokeMethod('tokens',
        <String, dynamic>{"accessToken": accessToken, "fcmToken": fcmToken});
  }

  static Future<bool> unregister() {
    return _channel.invokeMethod('unregister');
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

  static Future<bool> holdCall() {
    return _channel.invokeMethod('holdCall');
  }

  static Future<bool> muteCall() {
    return _channel.invokeMethod('muteCall');
  }

  static Future<bool> toggleSpeaker(bool speakerIsOn) {
    assert(speakerIsOn != null);
    return _channel.invokeMethod(
        'toggleSpeaker', <String, dynamic>{"speakerIsOn": speakerIsOn});
  }

  static Future<bool> sendDigits(String digits) {
    assert(digits != null);
    return _channel
        .invokeMethod('sendDigits', <String, dynamic>{"digits": digits});
  }

  static CallState _parseCallState(String state) {
    switch (state) {
      case 'Ringing':
        return CallState.ringing;
      case 'Connected':
        return CallState.connected;
      case 'Call Ended':
        return CallState.call_ended;
      case 'Unhold':
        return CallState.unhold;
      case 'Hold':
        return CallState.hold;
      case 'Unmute':
        return CallState.unmute;
      case 'Mute':
        return CallState.mute;
      default:
        print('$state is not a valid CallState.');
        throw ArgumentError('$state is not a valid CallState.');
    }
  }
}
