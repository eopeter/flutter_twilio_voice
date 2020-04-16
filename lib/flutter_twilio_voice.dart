import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CallState { ringing, connected, call_ended, unhold, hold, unmute, mute, speaker_on, speaker_off }
enum CallDirection { incoming, outgoing }

class FlutterTwilioVoice {
  static final String ACTION_ACCEPT = "ACTION_ACCEPT";
  static final String ACTION_REJECT = "ACTION_REJECT";
  static final String ACTION_INCOMING_CALL_NOTIFICATION = "ACTION_INCOMING_CALL_NOTIFICATION";
  static final String ACTION_INCOMING_CALL = "ACTION_INCOMING_CALL";
  static final String ACTION_CANCEL_CALL = "ACTION_CANCEL_CALL";
  static final String ACTION_FCM_TOKEN = "ACTION_FCM_TOKEN";

  static const MethodChannel _channel = const MethodChannel('flutter_twilio_voice/messages');

  static const EventChannel _eventChannel = EventChannel('flutter_twilio_voice/events');

  static Stream<CallState> _onCallStateChanged;
  static String callFrom = "SafeNSound";
  static String callTo = "SafeNSound";
  static int callStartedOn;
  static CallDirection callDirection = CallDirection.incoming;

  static Stream<CallState> get onCallStateChanged {
    if (_onCallStateChanged == null) {
      _onCallStateChanged = _eventChannel.receiveBroadcastStream().map((dynamic event) => _parseCallState(event));
    }
    return _onCallStateChanged;
  }

  static Future<bool> tokens({@required String accessToken, @required String fcmToken}) {
    assert(accessToken != null);
    return _channel.invokeMethod('tokens', <String, dynamic>{"accessToken": accessToken, "fcmToken": fcmToken});
  }

  static Future<bool> unregister() {
    return _channel.invokeMethod('unregister', <String, dynamic>{});
  }

  static Future<bool> makeCall(
      {@required String from, @required String to, String toDisplayName, Map<String, dynamic> extraOptions}) {
    assert(to != null);
    assert(from != null);
    extraOptions['from'] = from;
    extraOptions['to'] = to;
    extraOptions['toDisplayName'] = toDisplayName;
    callFrom = from;
    callTo = to;
    callDirection = CallDirection.outgoing;
    return _channel.invokeMethod('makeCall', extraOptions);
  }

  static Future<bool> hangUp() {
    return _channel.invokeMethod('hangUp', <String, dynamic>{});
  }

  static Future<bool> answer() {
    return _channel.invokeMethod('answer', <String, dynamic>{});
  }

  static Future<bool> holdCall() {
    return _channel.invokeMethod('holdCall', <String, dynamic>{});
  }

  static Future<bool> muteCall() {
    return _channel.invokeMethod('muteCall', <String, dynamic>{});
  }

  static Future<bool> toggleSpeaker(bool speakerIsOn) {
    assert(speakerIsOn != null);
    return _channel.invokeMethod('toggleSpeaker', <String, dynamic>{"speakerIsOn": speakerIsOn});
  }

  static Future<bool> sendDigits(String digits) {
    assert(digits != null);
    return _channel.invokeMethod('sendDigits', <String, dynamic>{"digits": digits});
  }

  static Future<bool> isOnCall() {
    return _channel.invokeMethod('isOnCall', <String, dynamic>{});
  }

  static String getFrom() {
    return callFrom;
  }

  static String getTo() {
    return callTo;
  }

  static int getCallStartedOn() {
    return callStartedOn;
  }

  static CallDirection getCallDirection() {
    return callDirection;
  }

  static CallState _parseCallState(String state) {
    if (state.startsWith("Connected|")) {
      List<String> tokens = state.split('|');
      callFrom = _prettyPrintNumber(tokens[1]);
      callTo = _prettyPrintNumber(tokens[2]);
      callDirection = ("Incoming" == tokens[3] ? CallDirection.incoming : CallDirection.outgoing);
      if (callStartedOn == null) {
        callStartedOn = DateTime.now().millisecondsSinceEpoch;
      }
      print('Connected - From: $callFrom, To: $callTo, StartOn: $callStartedOn, Direction: $callDirection');
      return CallState.connected;
    } else if (state.startsWith("Ringing|")) {
      List<String> tokens = state.split('|');
      callFrom = _prettyPrintNumber(tokens[1]);
      callTo = _prettyPrintNumber(tokens[2]);
      callDirection = ("Incoming" == tokens[3] ? CallDirection.incoming : CallDirection.outgoing);
      callStartedOn = DateTime.now().millisecondsSinceEpoch;
      print('Ringing - From: $callFrom, To: $callTo, StartOn: $callStartedOn, Direction: $callDirection');
      return CallState.ringing;
    }
    switch (state) {
      case 'Ringing':
        return CallState.ringing;
      case 'Connected':
        return CallState.connected;
      case 'Call Ended':
        callStartedOn = null;
        callFrom = "SafeNSound";
        callTo = "SafeNSound";
        callDirection = CallDirection.incoming;
        return CallState.call_ended;
      case 'Unhold':
        return CallState.unhold;
      case 'Hold':
        return CallState.hold;
      case 'Unmute':
        return CallState.unmute;
      case 'Mute':
        return CallState.mute;
      case 'Speaker On':
        return CallState.speaker_on;
      case 'Speaker Off':
        return CallState.speaker_off;
      default:
        print('$state is not a valid CallState.');
        throw ArgumentError('$state is not a valid CallState.');
    }
  }

  static String _prettyPrintNumber(String phoneNumber) {
    if (phoneNumber.indexOf('client:') > -1) {
      return phoneNumber.split(':')[1];
    }
    if (phoneNumber.substring(0, 1) == '+') {
      phoneNumber = phoneNumber.substring(1);
    }
    if (phoneNumber.length == 7) {
      return phoneNumber.substring(0, 3) + "-" + phoneNumber.substring(3);
    }
    if (phoneNumber.length < 10) {
      return phoneNumber;
    }
    int start = 0;
    if (phoneNumber.length == 11) {
      start = 1;
    }
    return "(" +
        phoneNumber.substring(start, start + 3) +
        ") " +
        phoneNumber.substring(start + 3, start + 6) +
        "-" +
        phoneNumber.substring(start + 6);
  }
}
