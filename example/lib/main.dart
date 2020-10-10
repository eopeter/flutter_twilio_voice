import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_twilio_voice/flutter_twilio_voice.dart';
import 'package:flutter_twilio_voice_example/call_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  return runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: DialScreen());
  }
}

class DialScreen extends StatefulWidget {
  @override
  _DialScreenState createState() => _DialScreenState();
}

class _DialScreenState extends State<DialScreen> with WidgetsBindingObserver {
  TextEditingController _controller;
  String userId;

  registerUser() {
    print("voip- service init");
    // if (FlutterTwilioVoice.deviceToken != null) {
    //   print("device token changed");
    // }

    register();

    FlutterTwilioVoice.setOnDeviceTokenChanged(() {
      print("voip-device token changed");
      register();
    });
  }

  register() async {
    print("voip-registtering with token ");
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
    String androidToken;
    if (Platform.isAndroid) {
      androidToken = await FirebaseMessaging().getToken();
      print("androidToken is " + androidToken);
    }
    FlutterTwilioVoice.tokens(
        accessToken: result.data, deviceToken: androidToken);
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
        print("registering user ${user.uid}");
        registerUser();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    waitForLogin();

    super.initState();
    waitForCall();
    WidgetsBinding.instance.addObserver(this);

    final partnerId = "alicesId";
    FlutterTwilioVoice.registerClient(partnerId, "Alice");

    final a4 = "p32GLAC6CEfBz3mOJHQJdqR3ReE2";
    final other = "OwicvyDkHlR1ggI4R0k8ecYhWLt2";
    _controller = TextEditingController(text: a4);
  }

  checkActiveCall() async {
    final isOnCall = await FlutterTwilioVoice.isOnCall();
    print("checkActiveCall $isOnCall");
    if (isOnCall) {
      print("user is on call");
      pushToCallScreen();
    }
  }

  void waitForCall() {
    checkActiveCall();
    FlutterTwilioVoice.onCallStateChanged.listen((event) {
      print("voip-onCallStateChanged $event");

      switch (event) {
        case CallState.answer:
          if (Platform.isAndroid ||
              state == null ||
              state == AppLifecycleState.resumed) {
            pushToCallScreen();
          }
          break;
        case CallState.connected:
          if (Platform.isAndroid && state != AppLifecycleState.resumed) {
            FlutterTwilioVoice.showBackgroundCallUI();
          }
          break;
        default:
          break;
      }
    });
  }

  AppLifecycleState state;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    this.state = state;
    print("didChangeAppLifecycleState");
    if (state == AppLifecycleState.resumed) {
      checkActiveCall();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
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
                    if (!await FlutterTwilioVoice.hasMicAccess()) {
                      print("request mic access");
                      FlutterTwilioVoice.requestMicAccess();
                      return;
                    }
                    FlutterTwilioVoice.makeCall(
                        to: _controller.text, from: userId);
                    pushToCallScreen();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void pushToCallScreen() {
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        fullscreenDialog: true, builder: (context) => CallScreen()));
  }
}
