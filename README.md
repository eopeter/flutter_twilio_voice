# flutter_twilio_voice

Provides an interface to Twilio's Programmable Voice SDK to allow voice-over-IP (VoIP) calling into your Flutter applications.


## Configure Server to Generate Access Token

View Twilio Documentation on Access Token Generation: https://www.twilio.com/docs/iam/access-tokens

## Make a Call

```
 await FlutterTwilioVoice.makeCall(to: "$client_identifier_or_number_to_call",
                   accessTokenUrl: "https://${YOUR-SERVER-URL}/accesstoken");

```


## Mute a Call

```
 await FlutterTwilioVoice.muteCall(isMuted: true);

```

## Toggle Speaker

```
 await FlutterTwilioVoice.toggleSpeaker(speakerIsOn: true);

```

## Hang Up

```
 await FlutterTwilioVoice.hangUp();

```

## Client Setup to Receive Calls

```
 await FlutterTwilioVoice.receiveCalls(clientIdentifier: 'alice');

```

## Listen for Call Events
```
FlutterTwilioVoice.phoneCallEventSubscription.listen((data) 
    {
      setState(() {
        _callStatus = data.toString();
      });
    }, onError: (error) {
      setState(() {
        print(error);
      });
    });
    
```

## To Do

1. Android Support
2. Propagate Events and Call Status Notifications to Flutter



