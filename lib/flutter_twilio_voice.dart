import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CallState {
  ringing,
  connected,
  call_ended,
  unhold,
  hold,
  unmute,
  mute,
  speaker_on,
  speaker_off,
  log,
  answer
}
enum CallDirection { incoming, outgoing }

typedef OnDeviceTokenChanged = Function();

class FlutterTwilioVoice {
  static const MethodChannel _channel =
      const MethodChannel('flutter_twilio_voice/messages');

  static const EventChannel _eventChannel =
      EventChannel('flutter_twilio_voice/events');

  static Stream<CallState> _onCallStateChanged;
  static String callFrom;
  static String callTo;
  static int callStartedOn;
  static CallDirection callDirection = CallDirection.incoming;
  static OnDeviceTokenChanged deviceTokenChanged;

  static Stream<CallState> get onCallStateChanged {
    if (_onCallStateChanged == null) {
      _onCallStateChanged = _eventChannel
          .receiveBroadcastStream()
          .map((dynamic event) => _parseCallState(event));
    }
    return _onCallStateChanged;
  }

  static void setOnDeviceTokenChanged(OnDeviceTokenChanged deviceTokenChanged) {
    FlutterTwilioVoice.deviceTokenChanged = deviceTokenChanged;
  }

  static Future<bool> tokens(
      {@required String accessToken, String deviceToken}) {
    assert(accessToken != null);
    return _channel.invokeMethod('tokens', <String, dynamic>{
      "accessToken": accessToken,
      "deviceToken": deviceToken
    });
  }

  static Future<bool> unregister(String accessToken) {
    return _channel.invokeMethod(
        'unregister', <String, dynamic>{"accessToken": accessToken});
  }

  static Future<bool> makeCall(
      {@required String from,
      @required String to,
      Map<String, dynamic> extraOptions}) {
    assert(to != null);
    assert(from != null);
    var options = extraOptions != null ? extraOptions : Map<String, dynamic>();
    options['from'] = from;
    options['to'] = to;
    callFrom = from;
    callTo = to;
    callDirection = CallDirection.outgoing;
    return _channel.invokeMethod('makeCall', options);
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
    return _channel.invokeMethod(
        'toggleSpeaker', <String, dynamic>{"speakerIsOn": speakerIsOn});
  }

  static Future<bool> sendDigits(String digits) {
    assert(digits != null);
    return _channel
        .invokeMethod('sendDigits', <String, dynamic>{"digits": digits});
  }

  static Future<bool> requestBackgroundPermissions() {
    return _channel.invokeMethod('requestBackgroundPermissions', {});
  }

  static Future<bool> requiresBackgroundPermissions() {
    return _channel.invokeMethod('requiresBackgroundPermissions', {});
  }

  static Future<bool> isOnCall() {
    return _channel.invokeMethod('isOnCall', <String, dynamic>{});
  }

  static Future<bool> registerClient(String clientId, String clientName) {
    return _channel.invokeMethod('registerClient',
        <String, dynamic>{"id": clientId, "name": clientName});
  }

  static Future<bool> unregisterClient(String clientId) {
    return _channel
        .invokeMethod('unregisterClient', <String, dynamic>{"id": clientId});
  }

  static Future<bool> setDefaultCallerName(String callerName) {
    return _channel.invokeMethod(
        'defaultCaller', <String, dynamic>{"defaultCaller": callerName});
  }

  static Future<bool> hasMicAccess() {
    return _channel.invokeMethod('hasMicPermission', {});
  }

  static Future<bool> requestMicAccess() {
    return _channel.invokeMethod('requestMicPermission', {});
  }

  static Future showBackgroundCallUI() {
    return _channel.invokeMethod("backgroundCallUI", {});
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
    if (state.startsWith("DEVICETOKEN|")) {
      if (deviceTokenChanged != null) {
        deviceTokenChanged();
      }
      return CallState.log;
    } else if (state.startsWith("LOG|")) {
      List<String> tokens = state.split('|');
      print(tokens[1]);
      return CallState.log;
    } else if (state.startsWith("Connected|")) {
      List<String> tokens = state.split('|');
      callFrom = _prettyPrintNumber(tokens[1]);
      callTo = _prettyPrintNumber(tokens[2]);
      callDirection = ("Incoming" == tokens[3]
          ? CallDirection.incoming
          : CallDirection.outgoing);
      if (callStartedOn == null) {
        callStartedOn = DateTime.now().millisecondsSinceEpoch;
      }
      print(
          'Connected - From: $callFrom, To: $callTo, StartOn: $callStartedOn, Direction: $callDirection');
      return CallState.connected;
    } else if (state.startsWith("Ringing|")) {
      List<String> tokens = state.split('|');
      callFrom = _prettyPrintNumber(tokens[1]);
      callTo = _prettyPrintNumber(tokens[2]);

      print(
          'Ringing - From: $callFrom, To: $callTo, Direction: $callDirection');
      return CallState.ringing;
    } else if (state.startsWith("Answer")) {
      List<String> tokens = state.split('|');
      callFrom = _prettyPrintNumber(tokens[1]);
      callTo = _prettyPrintNumber(tokens[2]);
      callDirection = CallDirection.incoming;
      print('Answer - From: $callFrom, To: $callTo, Direction: $callDirection');
      return CallState.answer;
    }
    switch (state) {
      case 'Ringing':
        return CallState.ringing;
      case 'Connected':
        return CallState.connected;
      case 'Call Ended':
        callStartedOn = null;
        callFrom = null;
        callTo = null;
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
    return phoneNumber;
  }
}
