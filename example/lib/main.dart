import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_twilio_voice/flutter_twilio_voice.dart';

import 'dialpad.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await FlutterTwilioVoice.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Twilio Voice Example'),
        ),
        body: SafeArea(child: Center(
          child: Column(children: <Widget>[
           
            Padding(
              padding: EdgeInsets.all(10),
              child: Text('Running on: $_platformVersion\n'),),
            DialPad(makeCall: (callingNumber) async {

              await FlutterTwilioVoice.makeCall(
                  accessTokenUrl: "https://<REMOTE-SERVER>/accesstoken",
                  to: callingNumber);

            },),

          ],),
        )),
      ),
    );
  }
}
