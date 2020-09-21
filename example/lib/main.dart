import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_twilio_voice/flutter_twilio_voice.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  return runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

  TextEditingController _controller;
  String userId;

  registerUser() {
    print("voip- service init");
    // if (FlutterTwilioVoice.deviceToken != null) {
    //   print("device token changed");
    // }

    register();

    FlutterTwilioVoice.setOnDeviceTokenChanged((deviceToken) {
      print("voip-device token changed");
      register(deviceToken: deviceToken);
    });
  }

  register({String deviceToken}) async {
    var devToken = deviceToken;
    print("voip-registtering with token $deviceToken");
    print("voip-calling voice-accessToken");
    final function = CloudFunctions.instance
        // .useFunctionsEmulator(origin: "http://192.168.1.9:5000")
        .getHttpsCallable(functionName: "voice-accessToken");

    final data = {
      "platform": Platform.isIOS ? "iOS" : "Android",
    };

    final result = await function.call(data);
    print("voip-result");
    print(result.data);
    if (devToken == null && Platform.isAndroid) {
      devToken = await FirebaseMessaging().getToken();
      print("dev token is " + devToken);
    }
    FlutterTwilioVoice.tokens(accessToken: result.data, deviceToken: devToken);
  }

  var registered = false;
  waitForLogin() {
    final auth = FirebaseAuth.instance;
    auth.authStateChanges().listen((user) async {
      // print("authStateChanges $user");
      if (user == null) {
        print("user is anonomous");
        await auth.signInAnonymously();
      } else if (!registered) {
        registered = true;
        this.userId = user.uid;
<<<<<<< HEAD
        setState(() {
          _platformVersion = user.uid;
        });
        print("registering user ${user.uid}");
=======
        print(user.uid);
        print("registering user");
>>>>>>> 26e754212b7098ccd6d17a044ae365e6bf85d1cc
        registerUser();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    waitForLogin();
    FlutterTwilioVoice.onCallStateChanged.listen(_onEvent, onError: _onError);

    // registra el nombre con el clientId del otro usuario para identificador de llamadas
    // FlutterTwilioVoice.registerClient(clientId, clientName)
    _controller = TextEditingController(text: "OwicvyDkHlR1ggI4R0k8ecYhWLt2");
  }

  void _onEvent(Object event) {
    print(event);
    setState(() {});
  }

  void _onError(Object error) {
    print(error);
    setState(() {});
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
                  FlutterTwilioVoice.onCallStateChanged
                      .listen(_onEvent, onError: _onError);

                  if (!await FlutterTwilioVoice.hasMicAccess()) {
                    print("request mic access");
                    FlutterTwilioVoice.requestMicAccess();
                    return;
                  }

                  FlutterTwilioVoice.makeCall(
                      to: _controller.text,
                      from: userId,
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
