import 'dart:async';

import 'package:flutter/services.dart';

class FlutterTwilioVoice {
  static const MethodChannel _channel =
      const MethodChannel('flutter_twilio_voice');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<void> get makeCall async{
    await _channel.invokeMethod('makeCall');
  }

  static Future<void> get hangUp async{
    await _channel.invokeMethod('hangUp');
  }

  static Future<void> get muteCall async{
    await _channel.invokeMethod('muteCall');
  }

  static Future<void> get toggleSpeaker async{
    await _channel.invokeMethod('toggleSpeaker');
  }

}
