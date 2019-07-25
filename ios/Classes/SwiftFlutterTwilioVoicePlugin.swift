import Flutter
import UIKit
import AVFoundation
import PushKit
import TwilioVoice

public class SwiftFlutterTwilioVoicePlugin: NSObject, FlutterPlugin, PKPushRegistryDelegate, TVONotificationDelegate, TVOCallDelegate, AVAudioPlayerDelegate {

    var deviceTokenString: String?

    var voipRegistry: PKPushRegistry
    var incomingPushCompletionCallback: (()->Swift.Void?)? = nil

   var callInvite: TVOCallInvite?
   var call: TVOCall?
   var callKitCompletionCallback: ((Bool)->Swift.Void?)? = nil
   var audioDevice: TVODefaultAudioDevice = TVODefaultAudioDevice()

   let callKitProvider: CXProvider
   let callKitCallController: CXCallController
   var userInitiatedDisconnect: Bool = false

   required init?(coder aDecoder: NSCoder) {
          isSpinning = false
          voipRegistry = PKPushRegistry.init(queue: DispatchQueue.main)

          let configuration = CXProviderConfiguration(localizedName: "CallKit Quickstart")
          configuration.maximumCallGroups = 1
          configuration.maximumCallsPerCallGroup = 1
          if let callKitIcon = UIImage(named: "iconMask80") {
              configuration.iconTemplateImageData = UIImagePNGRepresentation(callKitIcon)
          }

          callKitProvider = CXProvider(configuration: configuration)
          callKitCallController = CXCallController()

          super.init(coder: aDecoder)

          callKitProvider.setDelegate(self, queue: nil)

          voipRegistry.delegate = self
          voipRegistry.desiredPushTypes = Set([PKPushType.voIP])
      }

      deinit {
          // CallKit has an odd API contract where the developer must call invalidate or the CXProvider is leaked.
          callKitProvider.invalidate()
      }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_twilio_voice", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterTwilioVoicePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ flutterCall: FlutterMethodCall, result: @escaping FlutterResult) {

    let arguments = flutterCall.arguments as! NSDictionary

    if flutterCall.method == "makeCall" {
        guard let callTo = arguments["to"] as? String else {return}
        guard let accessToken = arguments["accessToken"] as? String else {return}
        makeCall(accessToken, to)
    }
    else if flutterCall.method == "muteCall"
    {
        guard let isMuted = arguments["isMuted"] as? Bool else {return}
        if let call = call {
           call.isMuted = isMuted
        } else {
            NSLog("No active call to be muted")
        }
    }
    else if flutterCall.method == "toggleSpeaker"
    {
        guard let speakerIsOn = arguments["speakerIsOn"] as? Bool else {return}
        toggleAudioRoute(toSpeaker: speakerIsOn);
    }
    result("iOS " + UIDevice.current.systemVersion)
  }

  func makeCall(_accessToken: String, _to: String)
  {
    if (self.call != nil && self.call?.state == .connected) {
                self.userInitiatedDisconnect = true
                performEndCallAction(uuid: self.call!.uuid)
                //self.toggleUIState(isEnabled: false, showCallControl: false)
            } else {
                let uuid = UUID()
                let handle = "Voice Bot"

                self.checkRecordPermission { (permissionGranted) in
                    if (!permissionGranted) {
                        let alertController: UIAlertController = UIAlertController(title: "Voice Quick Start",
                                                                                   message: "Microphone permission not granted",
                                                                                   preferredStyle: .alert)

                        let continueWithMic: UIAlertAction = UIAlertAction(title: "Continue without microphone",
                                                                           style: .default,
                                                                           handler: { (action) in
                            self.performStartCallAction(uuid: uuid, handle: handle)
                        })
                        alertController.addAction(continueWithMic)

                        let goToSettings: UIAlertAction = UIAlertAction(title: "Settings",
                                                                        style: .default,
                                                                        handler: { (action) in
                            UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!,
                                                      options: [UIApplicationOpenURLOptionUniversalLinksOnly: false],
                                                      completionHandler: nil)
                        })
                        alertController.addAction(goToSettings)

                        let cancel: UIAlertAction = UIAlertAction(title: "Cancel",
                                                                  style: .cancel,
                                                                  handler: { (action) in
                            self.toggleUIState(isEnabled: true, showCallControl: false)
                            self.stopSpin()
                        })
                        alertController.addAction(cancel)

                        self.present(alertController, animated: true, completion: nil)
                    } else {
                        self.performStartCallAction(uuid: uuid, handle: handle)
                    }
                }
            }
  }

  // MARK: PKPushRegistryDelegate
      func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
          NSLog("pushRegistry:didUpdatePushCredentials:forType:")

          if (type != .voIP) {
              return
          }

          guard let accessToken = fetchAccessToken() else {
              return
          }

          let deviceToken = (credentials.token as NSData).description

          TwilioVoice.register(withAccessToken: accessToken, deviceToken: deviceToken) { (error) in
              if let error = error {
                  NSLog("An error occurred while registering: \(error.localizedDescription)")
              }
              else {
                  NSLog("Successfully registered for VoIP push notifications.")
              }
          }

          self.deviceTokenString = deviceToken
      }

      func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
          NSLog("pushRegistry:didInvalidatePushTokenForType:")

          if (type != .voIP) {
              return
          }

          guard let deviceToken = deviceTokenString, let accessToken = fetchAccessToken() else {
              return
          }

          TwilioVoice.unregister(withAccessToken: accessToken, deviceToken: deviceToken) { (error) in
              if let error = error {
                  NSLog("An error occurred while unregistering: \(error.localizedDescription)")
              }
              else {
                  NSLog("Successfully unregistered from VoIP push notifications.")
              }
          }

          self.deviceTokenString = nil
      }

    /**
         * Try using the `pushRegistry:didReceiveIncomingPushWithPayload:forType:withCompletionHandler:` method if
         * your application is targeting iOS 11. According to the docs, this delegate method is deprecated by Apple.
         */
        func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
            NSLog("pushRegistry:didReceiveIncomingPushWithPayload:forType:")

            if (type == PKPushType.voIP) {
                TwilioVoice.handleNotification(payload.dictionaryPayload, delegate: self)
            }
        }

        /**
         * This delegate method is available on iOS 11 and above. Call the completion handler once the
         * notification payload is passed to the `TwilioVoice.handleNotification()` method.
         */
        func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
            NSLog("pushRegistry:didReceiveIncomingPushWithPayload:forType:completion:")
            // Save for later when the notification is properly handled.
            self.incomingPushCompletionCallback = completion

            if (type == PKPushType.voIP) {
                TwilioVoice.handleNotification(payload.dictionaryPayload, delegate: self)
            }
        }

        func incomingPushHandled() {
            if let completion = self.incomingPushCompletionCallback {
                completion()
                self.incomingPushCompletionCallback = nil
            }
        }

        // MARK: TVONotificaitonDelegate
        func callInviteReceived(_ callInvite: TVOCallInvite) {
            NSLog("callInviteReceived:")

            if (self.callInvite != nil) {
                NSLog("A CallInvite is already in progress. Ignoring the incoming CallInvite from \(callInvite.from)")
                self.incomingPushHandled()
                return;
            } else if (self.call != nil) {
                NSLog("Already an active call.");
                NSLog("  >> Ignoring call from \(callInvite.from)");
                self.incomingPushHandled()
                return;
            }

            self.callInvite = callInvite

            reportIncomingCall(from: "Voice Bot", uuid: callInvite.uuid)
        }

        func cancelledCallInviteReceived(_ cancelledCallInvite: TVOCancelledCallInvite) {
            NSLog("cancelledCallInviteCanceled:")

            self.incomingPushHandled()

            if (self.callInvite == nil ||
                self.callInvite!.callSid != cancelledCallInvite.callSid) {
                NSLog("No matching pending CallInvite. Ignoring the Cancelled CallInvite")
                return
            }

            performEndCallAction(uuid: self.callInvite!.uuid)

            self.callInvite = nil
            self.incomingPushHandled()
        }

        // MARK: TVOCallDelegate
        func callDidStartRinging(_ call: TVOCall) {
            NSLog("callDidStartRinging:")

            self.placeCallButton.setTitle("Ringing", for: .normal)
        }

        func callDidConnect(_ call: TVOCall) {
            NSLog("callDidConnect:")

            self.call = call
            self.callKitCompletionCallback!(true)
            self.callKitCompletionCallback = nil

            self.placeCallButton.setTitle("Hang Up", for: .normal)

            toggleUIState(isEnabled: true, showCallControl: true)
            stopSpin()
            toggleAudioRoute(toSpeaker: true)
        }

        func call(_ call: TVOCall, isReconnectingWithError error: Error) {
            NSLog("call:isReconnectingWithError:")

            self.placeCallButton.setTitle("Reconnecting", for: .normal)

            toggleUIState(isEnabled: false, showCallControl: false)
        }

        func callDidReconnect(_ call: TVOCall) {
            NSLog("callDidReconnect:")

            self.placeCallButton.setTitle("Hang Up", for: .normal)

            toggleUIState(isEnabled: true, showCallControl: true)
        }

        func call(_ call: TVOCall, didFailToConnectWithError error: Error) {
            NSLog("Call failed to connect: \(error.localizedDescription)")

            if let completion = self.callKitCompletionCallback {
                completion(false)
            }

            performEndCallAction(uuid: call.uuid)
            callDisconnected()
        }

        func call(_ call: TVOCall, didDisconnectWithError error: Error?) {
            if let error = error {
                NSLog("Call failed: \(error.localizedDescription)")
            } else {
                NSLog("Call disconnected")
            }

            if !self.userInitiatedDisconnect {
                var reason = CXCallEndedReason.remoteEnded

                if error != nil {
                    reason = .failed
                }

                self.callKitProvider.reportCall(with: call.uuid, endedAt: Date(), reason: reason)
            }

            callDisconnected()
        }

        func callDisconnected() {
            self.call = nil
            self.callKitCompletionCallback = nil
            self.userInitiatedDisconnect = false

            stopSpin()
            toggleUIState(isEnabled: true, showCallControl: false)
            self.placeCallButton.setTitle("Call", for: .normal)
        }


        // MARK: AVAudioSession
        func toggleAudioRoute(toSpeaker: Bool) {
            // The mode set by the Voice SDK is "VoiceChat" so the default audio route is the built-in receiver. Use port override to switch the route.
            audioDevice.block = {
                kTVODefaultAVAudioSessionConfigurationBlock()
                do {
                    if (toSpeaker) {
                        try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                    } else {
                        try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                    }
                } catch {
                    NSLog(error.localizedDescription)
                }
            }
            audioDevice.block()
        }

    // MARK: CXProviderDelegate
        func providerDidReset(_ provider: CXProvider) {
            NSLog("providerDidReset:")
            audioDevice.isEnabled = true
        }

        func providerDidBegin(_ provider: CXProvider) {
            NSLog("providerDidBegin")
        }

        func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
            NSLog("provider:didActivateAudioSession:")
            audioDevice.isEnabled = true
        }

        func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
            NSLog("provider:didDeactivateAudioSession:")
        }

        func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
            NSLog("provider:timedOutPerformingAction:")
        }

        func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
            NSLog("provider:performStartCallAction:")

            toggleUIState(isEnabled: false, showCallControl: false)
            startSpin()

            audioDevice.isEnabled = false
            audioDevice.block();

            provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())

            self.performVoiceCall(uuid: action.callUUID, client: "") { (success) in
                if (success) {
                    provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
                    action.fulfill()
                } else {
                    action.fail()
                }
            }
        }

        func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
            NSLog("provider:performAnswerCallAction:")

            assert(action.callUUID == self.callInvite?.uuid)

            audioDevice.isEnabled = false
            audioDevice.block();

            self.performAnswerVoiceCall(uuid: action.callUUID) { (success) in
                if (success) {
                    action.fulfill()
                } else {
                    action.fail()
                }
            }

            action.fulfill()
        }

        func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
            NSLog("provider:performEndCallAction:")

            if (self.callInvite != nil) {
                self.callInvite!.reject()
                self.callInvite = nil
            } else if (self.call != nil) {
                self.call?.disconnect()
            }

            audioDevice.isEnabled = true
            action.fulfill()
        }

        func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
            NSLog("provider:performSetHeldAction:")
            if (self.call?.state == .connected) {
                self.call?.isOnHold = action.isOnHold
                action.fulfill()
            } else {
                action.fail()
            }
        }

        // MARK: Call Kit Actions
        func performStartCallAction(uuid: UUID, handle: String) {
            let callHandle = CXHandle(type: .generic, value: handle)
            let startCallAction = CXStartCallAction(call: uuid, handle: callHandle)
            let transaction = CXTransaction(action: startCallAction)

            callKitCallController.request(transaction)  { error in
                if let error = error {
                    NSLog("StartCallAction transaction request failed: \(error.localizedDescription)")
                    return
                }

                NSLog("StartCallAction transaction request successful")

                let callUpdate = CXCallUpdate()
                callUpdate.remoteHandle = callHandle
                callUpdate.supportsDTMF = true
                callUpdate.supportsHolding = true
                callUpdate.supportsGrouping = false
                callUpdate.supportsUngrouping = false
                callUpdate.hasVideo = false

                self.callKitProvider.reportCall(with: uuid, updated: callUpdate)
            }
        }

        func reportIncomingCall(from: String, uuid: UUID) {
            let callHandle = CXHandle(type: .generic, value: from)

            let callUpdate = CXCallUpdate()
            callUpdate.remoteHandle = callHandle
            callUpdate.supportsDTMF = true
            callUpdate.supportsHolding = true
            callUpdate.supportsGrouping = false
            callUpdate.supportsUngrouping = false
            callUpdate.hasVideo = false

            callKitProvider.reportNewIncomingCall(with: uuid, update: callUpdate) { error in
                if let error = error {
                    NSLog("Failed to report incoming call successfully: \(error.localizedDescription).")
                } else {
                    NSLog("Incoming call successfully reported.")
                }
            }
        }

        func performEndCallAction(uuid: UUID) {

            let endCallAction = CXEndCallAction(call: uuid)
            let transaction = CXTransaction(action: endCallAction)

            callKitCallController.request(transaction) { error in
                if let error = error {
                    NSLog("EndCallAction transaction request failed: \(error.localizedDescription).")
                } else {
                    NSLog("EndCallAction transaction request successful")
                }
            }
        }

        func performVoiceCall(uuid: UUID, client: String?, completionHandler: @escaping (Bool) -> Swift.Void) {
            guard let accessToken = fetchAccessToken() else {
                completionHandler(false)
                return
            }

            let connectOptions: TVOConnectOptions = TVOConnectOptions(accessToken: accessToken) { (builder) in
                builder.params = [twimlParamTo : self.outgoingValue.text!]
                builder.uuid = uuid
            }
            call = TwilioVoice.connect(with: connectOptions, delegate: self)
            self.callKitCompletionCallback = completionHandler
        }

        func performAnswerVoiceCall(uuid: UUID, completionHandler: @escaping (Bool) -> Swift.Void) {
            let acceptOptions: TVOAcceptOptions = TVOAcceptOptions(callInvite: self.callInvite!) { (builder) in
                builder.uuid = self.callInvite?.uuid
            }
            call = self.callInvite?.accept(with: acceptOptions, delegate: self)
            self.callInvite = nil
            self.callKitCompletionCallback = completionHandler
            self.incomingPushHandled()
        }
}
