import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_twilio_voice/flutter_twilio_voice.dart';

class CallScreen extends StatefulWidget {
  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  var speaker = false;
  var mute = false;
  var isEnded = false;

  String? message = "Connecting...";
  late StreamSubscription<CallState> callStateListener;
  void listenCall() {
    callStateListener = FlutterTwilioVoice.onCallStateChanged.listen((event) {
      print("voip-onCallStateChanged $event");

      switch (event) {
        case CallState.call_ended:
          print("call Ended");
          if (!isEnded) {
            isEnded = true;
            Navigator.of(context).pop();
          }
          break;
        case CallState.mute:
          setState(() {
            mute = true;
          });
          break;
        case CallState.unmute:
          setState(() {
            mute = false;
          });
          break;
        case CallState.speaker_on:
          setState(() {
            speaker = true;
          });
          break;
        case CallState.speaker_off:
          setState(() {
            speaker = false;
          });
          break;
        case CallState.ringing:
          setState(() {
            message = "Calling...";
          });
          break;
        case CallState.answer:
          setState(() {
            message = null;
          });
          break;
        case CallState.hold:
        case CallState.log:
        case CallState.unhold:
          break;
        default:
          break;
      }
    });
  }

  late String caller;

  String getCaller() {
    return FlutterTwilioVoice.callDirection == CallDirection.outgoing
        ? FlutterTwilioVoice.callTo!
        : FlutterTwilioVoice.callFrom!;
  }

  @override
  void initState() {
    listenCall();
    super.initState();
    caller = getCaller();
  }

  @override
  void dispose() {
    super.dispose();
    callStateListener.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).accentColor,
        body: Container(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        caller,
                        style: Theme.of(context)
                            .textTheme
                            .headline4!
                            .copyWith(color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      if (message != null)
                        Text(
                          message!,
                          style: Theme.of(context)
                              .textTheme
                              .headline6!
                              .copyWith(color: Colors.white),
                        )
                    ],
                  ),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Material(
                          type: MaterialType
                              .transparency, //Makes it usable on any background color, thanks @IanSmith
                          child: Ink(
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: Colors.white, width: 1.0),
                              color: speaker
                                  ? Theme.of(context).primaryColor
                                  : null,
                              shape: BoxShape.circle,
                            ),
                            child: InkWell(
                              //This keeps the splash effect within the circle
                              borderRadius: BorderRadius.circular(
                                  1000.0), //Something large to ensure a circle
                              child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Icon(
                                  Icons.volume_up,
                                  size: 40.0,
                                  color: Colors.white,
                                ),
                              ),
                              onTap: () {
                                print("speaker!");
                                setState(() {
                                  speaker = !speaker;
                                });
                                FlutterTwilioVoice.toggleSpeaker(speaker);
                              },
                            ),
                          ),
                        ),
                        Material(
                          type: MaterialType
                              .transparency, //Makes it usable on any background color, thanks @IanSmith
                          child: Ink(
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: Colors.white, width: 1.0),
                              color:
                                  mute ? Theme.of(context).primaryColor : null,
                              shape: BoxShape.circle,
                            ),
                            child: InkWell(
                              //This keeps the splash effect within the circle
                              borderRadius: BorderRadius.circular(
                                  1000.0), //Something large to ensure a circle
                              child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Icon(
                                  Icons.mic_off,
                                  size: 40.0,
                                  color: Colors.white,
                                ),
                              ),
                              onTap: () {
                                print("mute!");
                                setState(() {
                                  mute = !mute;
                                });
                                FlutterTwilioVoice.muteCall();
                              },
                            ),
                          ),
                        )
                      ]),
                  RawMaterialButton(
                    elevation: 2.0,
                    fillColor: Colors.red,
                    child: Icon(
                      Icons.call_end,
                      size: 40.0,
                      color: Colors.white,
                    ),
                    padding: EdgeInsets.all(20.0),
                    shape: CircleBorder(),
                    onPressed: () async {
                      final isOnCall = await FlutterTwilioVoice.isOnCall();
                      if (isOnCall) {
                        FlutterTwilioVoice.hangUp();
                      }
                    },
                  )
                ],
              ),
            ),
          ),
        ));
  }
}
