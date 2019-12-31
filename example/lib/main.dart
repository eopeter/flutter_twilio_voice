import 'package:flutter/material.dart';
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

    _controller = TextEditingController();
  }

  void _onEvent(Object event) {
    setState(() {
      _eventMessage = "Plugin status: $event";
    });
  }

  void _onError(Object error) {
    setState(() {
      _eventMessage = 'Plugin status: unknown.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: SafeArea(
            child: Center(
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(10),
                child: Text('Running on: $_platformVersion\n'),
              ),
              TextFormField(
                controller: _controller,
                decoration: InputDecoration(
                    labelText: 'Client Identifier or Phone Number'),
              ),
              SizedBox(
                height: 10,
              ),
              RaisedButton(
                child: Text("Make Call"),
                onPressed: () async {
                  FlutterTwilioVoice.phoneCallEventSubscription
                      .listen(_onEvent, onError: _onError);
                  FlutterTwilioVoice.makeCall(
                      to: _controller.text,
                      from: "5551234567",
                      toDisplayName: "James Bond");
                },
              )
            ],
          ),
        )),
      ),
    );
  }
}
