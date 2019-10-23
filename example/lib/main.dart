import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_twilio_voice/flutter_twilio_voice.dart';


void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  String _eventMessage;

  TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    initPlatformState();
    _controller = TextEditingController();
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

  void _onEvent(Object event) {

    setState(() {

      _eventMessage = "Battery status: ${event == 'charging' ? '' : 'dis'}charging.";

    });

  }




  void _onError(Object error) {

    setState(() {

      _eventMessage = 'Battery status: unknown.';

    });

  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: SafeArea(child: Center(
          child: Column(children: <Widget>[
           
            Padding(
              padding: EdgeInsets.all(10),
              child: Text('Running on: $_platformVersion\n'),),
            TextFormField(controller: _controller, decoration: InputDecoration(labelText: 'Client Identifier or Phone Number'),),
            SizedBox(height: 10,),
            RaisedButton(child: Text("Make Call"), onPressed: () async {
              FlutterTwilioVoice.phoneCallEventSubscription.listen(_onEvent, onError: _onError);
              FlutterTwilioVoice.receiveCalls("alice");
              FlutterTwilioVoice.makeCall(to: "555555555", accessTokenUrl: "https://{SERVER_URL}/accesstoken", toDisplayName: "James Bond" );
            },)
          ],),
        )),
      ),
    );
  }
}
