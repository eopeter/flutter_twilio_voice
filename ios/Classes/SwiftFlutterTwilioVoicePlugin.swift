import Flutter
import UIKit
import AVFoundation
import PushKit
import TwilioVoice
import CallKit

public class SwiftFlutterTwilioVoicePlugin: NSObject, FlutterPlugin,  FlutterStreamHandler, PKPushRegistryDelegate, TVONotificationDelegate, TVOCallDelegate, AVAudioPlayerDelegate, CXProviderDelegate {

    var _result: FlutterResult?
    private var eventSink: FlutterEventSink?

    //var baseURLString = ""
    // If your token server is written in PHP, accessTokenEndpoint needs .php extension at the end. For example : /accessToken.php
    //var accessTokenEndpoint = "/accessToken"
    var accessToken = ""
    var fcmToken = ""
    var identity = "alice"
    var callTo: String = "error"
    var deviceTokenString: String?
    var callArgs: Dictionary<String, AnyObject> = [String: AnyObject]()

    var voipRegistry: PKPushRegistry
    var incomingPushCompletionCallback: (()->Swift.Void?)? = nil

   var callInvite:TVOCallInvite?
   var call:TVOCall?
   var callKitCompletionCallback: ((Bool)->Swift.Void?)? = nil
   var audioDevice: TVODefaultAudioDevice = TVODefaultAudioDevice()

   var callKitProvider: CXProvider
   var callKitCallController: CXCallController
   var userInitiatedDisconnect: Bool = false

    public override init() {

        //isSpinning = false
        voipRegistry = PKPushRegistry.init(queue: DispatchQueue.main)
        let appName = Bundle.main.infoDictionary!["CFBundleDisplayName"] as! String
        let configuration = CXProviderConfiguration(localizedName: appName)
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        if let callKitIcon = UIImage(named: "iconMask80") {
            configuration.iconTemplateImageData = callKitIcon.pngData()
        }

        callKitProvider = CXProvider(configuration: configuration)
        callKitCallController = CXCallController()

        //super.init(coder: aDecoder)
        super.init()

        callKitProvider.setDelegate(self, queue: nil)

        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = Set([PKPushType.voIP])


         let appDelegate = UIApplication.shared.delegate
         guard let controller = appDelegate?.window??.rootViewController as? FlutterViewController else {
         fatalError("rootViewController is not type FlutterViewController")
         }
         let registrar = controller.registrar(forPlugin: "flutter_twilio_voice")
         let eventChannel = FlutterEventChannel(name: "flutter_twilio_voice/events", binaryMessenger: registrar.messenger())

         eventChannel.setStreamHandler(self)

    }


      deinit {
          // CallKit has an odd API contract where the developer must call invalidate or the CXProvider is leaked.
          callKitProvider.invalidate()
      }


  public static func register(with registrar: FlutterPluginRegistrar) {

    let instance = SwiftFlutterTwilioVoicePlugin()
    let methodChannel = FlutterMethodChannel(name: "flutter_twilio_voice/messages", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "flutter_twilio_voice/events", binaryMessenger: registrar.messenger())
    eventChannel.setStreamHandler(instance)
    registrar.addMethodCallDelegate(instance, channel: methodChannel)

  }

  public func handle(_ flutterCall: FlutterMethodCall, result: @escaping FlutterResult) {
    _result = result

    let arguments:Dictionary<String, AnyObject> = flutterCall.arguments as! Dictionary<String, AnyObject>;

    if flutterCall.method == "tokens" {
        guard let token = arguments["accessToken"] as? String else {return}
        guard let fcmToken = arguments["fcmToken"] as? String else {return}
        self.accessToken = token
        self.fcmToken = fcmToken
        if self.deviceTokenString != nil {
            NSLog("pushRegistry:attempting to register with twilio")
            TwilioVoice.register(withAccessToken: self.accessToken, deviceToken: self.deviceTokenString!) { (error) in
                if let error = error {
                    NSLog("An error occurred while registering: \(error.localizedDescription)")
                }
                else {
                    NSLog("Successfully registered for VoIP push notifications.")
                }
            }
        }
    } else if flutterCall.method == "makeCall" {
        guard let callTo = arguments["to"] as? String else {return}
        guard let callFrom = arguments["from"] as? String else {return}
        let callToDisplayName:String = arguments["toDisplayName"] as? String ?? callTo
        self.callArgs = arguments
        //guard let accessTokenUrl = arguments["accessTokenUrl"] as? String else {return}
        //self.accessTokenEndpoint = accessTokenUrl
        self.callTo = callTo
        self.identity = callFrom
        makeCall(to: callTo, displayName: callToDisplayName)
    }
    else if flutterCall.method == "muteCall"
    {
        if (self.call != nil) {
           let muted = self.call!.isMuted
           self.call!.isMuted = !muted
           guard let eventSink = eventSink else {
               return
           }
           eventSink(!muted ? "Mute" : "Unmute")
        } else {
            let ferror: FlutterError = FlutterError(code: "MUTE_ERROR", message: "No call to be muted", details: nil)
            _result!(ferror)
        }
    }
    else if flutterCall.method == "toggleSpeaker"
    {
        guard let speakerIsOn = arguments["speakerIsOn"] as? Bool else {return}
        toggleAudioRoute(toSpeaker: speakerIsOn)
        guard let eventSink = eventSink else {
            return
        }
        eventSink(speakerIsOn ? "Speaker On" : "Speaker Off")
    }
    else if flutterCall.method == "isOnCall"
        {
            result(self.call != nil);
            return;
        }
    else if flutterCall.method == "sendDigits"
    {
        guard let digits = arguments["digits"] as? String else {return}
        if (self.call != nil) {
            self.call!.sendDigits(digits);
        }
    }
    /* else if flutterCall.method == "receiveCalls"
    {
        guard let clientIdentity = arguments["clientIdentifier"] as? String else {return}
        self.identity = clientIdentity;
    } */
    else if flutterCall.method == "holdCall" {
        if (self.call != nil) {

            let hold = self.call!.isOnHold
            self.call!.isOnHold = !hold
            guard let eventSink = eventSink else {
                return
            }
            eventSink(!hold ? "Hold" : "Unhold")
        }
    }
    else if flutterCall.method == "answer" {
        // nuthin
    }
    else if flutterCall.method == "unregister" {
        self.unregister()
    }
    else if flutterCall.method == "hangUp"
    {
        if (self.call != nil && self.call?.state == .connected) {
            NSLog("hangUp method invoked")
            self.userInitiatedDisconnect = true
            performEndCallAction(uuid: self.call!.uuid)
            //self.toggleUIState(isEnabled: false, showCallControl: false)
        }
    }
    result(true)
  }

  func makeCall(to: String, displayName: String)
  {
        if (self.call != nil && self.call?.state == .connected) {
            self.userInitiatedDisconnect = true
            performEndCallAction(uuid: self.call!.uuid)
            //self.toggleUIState(isEnabled: false, showCallControl: false)
        } else {
            let appName = Bundle.main.infoDictionary!["CFBundleDisplayName"] as! String
            let uuid = UUID()
            let handle = displayName

            self.checkRecordPermission { (permissionGranted) in
                if (!permissionGranted) {
                    let alertController: UIAlertController = UIAlertController(title: appName + " Permission",
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
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                  options: [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly: false],
                                                  completionHandler: nil)
                    })
                    alertController.addAction(goToSettings)

                    let cancel: UIAlertAction = UIAlertAction(title: "Cancel",
                                                              style: .cancel,
                                                              handler: { (action) in
                        //self.toggleUIState(isEnabled: true, showCallControl: false)
                        //self.stopSpin()
                    })
                    alertController.addAction(cancel)
                    guard let currentViewController = UIApplication.shared.keyWindow?.topMostViewController() else {
                        return
                    }
                    currentViewController.present(alertController, animated: true, completion: nil)

                } else {
                    self.performStartCallAction(uuid: uuid, handle: handle)
                }
            }
        }
  }

    /* func fetchAccessToken() -> String? {
        let endpointWithIdentity = String(format: "%@?identity=%@", accessTokenEndpoint, identity)
        guard let accessTokenURL = URL(string: baseURLString + endpointWithIdentity) else {
            return nil
        }

        return try? String.init(contentsOf: accessTokenURL, encoding: .utf8)
    } */

    func checkRecordPermission(completion: @escaping (_ permissionGranted: Bool) -> Void) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case AVAudioSessionRecordPermission.granted:
            // Record permission already granted.
            completion(true)
            break
        case AVAudioSessionRecordPermission.denied:
            // Record permission denied.
            completion(false)
            break
        case AVAudioSessionRecordPermission.undetermined:
            // Requesting record permission.
            // Optional: pop up app dialog to let the users know if they want to request.
            AVAudioSession.sharedInstance().requestRecordPermission({ (granted) in
                completion(granted)
            })
            break
        default:
            completion(false)
            break
        }
    }


  // MARK: PKPushRegistryDelegate
      public func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
          NSLog("pushRegistry:didUpdatePushCredentials:forType:")

          if (type != .voIP) {
              return
          }

          //guard let accessToken = fetchAccessToken() else {
          //    return
          //}

          let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()

          NSLog("pushRegistry:attempting to register with twilio")
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

      public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
          NSLog("pushRegistry:didInvalidatePushTokenForType:")

          if (type != .voIP) {
              return
          }

          self.unregister()
      }

      func unregister() {

          guard let deviceToken = deviceTokenString/* , let accessToken = fetchAccessToken() */ else {
              return
          }

          TwilioVoice.unregister(withAccessToken: accessToken, deviceToken: deviceToken) { (error) in
              if let error = error {
                  NSLog("An error occurred while unregistering: \(error.localizedDescription)")
              } else {
                  NSLog("Successfully unregistered from VoIP push notifications.")
              }
          }

          self.deviceTokenString = nil
      }

    /**
         * Try using the `pushRegistry:didReceiveIncomingPushWithPayload:forType:withCompletionHandler:` method if
         * your application is targeting iOS 11. According to the docs, this delegate method is deprecated by Apple.
         */
        public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
            NSLog("pushRegistry:didReceiveIncomingPushWithPayload:forType:")

            if (type == PKPushType.voIP) {
                TwilioVoice.handleNotification(payload.dictionaryPayload, delegate: self, delegateQueue: nil)
            }
        }

        /**
         * This delegate method is available on iOS 11 and above. Call the completion handler once the
         * notification payload is passed to the `TwilioVoice.handleNotification()` method.
         */
        public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
            NSLog("pushRegistry:didReceiveIncomingPushWithPayload:forType:completion:")
            // Save for later when the notification is properly handled.
            self.incomingPushCompletionCallback = completion

            if (type == PKPushType.voIP) {
                TwilioVoice.handleNotification(payload.dictionaryPayload, delegate: self, delegateQueue: nil)
            }

            if let version = Float(UIDevice.current.systemVersion), version < 13.0 {
                // Save for later when the notification is properly handled.
                self.incomingPushCompletionCallback = completion
            } else {
                /**
                * The Voice SDK processes the call notification and returns the call invite synchronously. Report the incoming call to
                * CallKit and fulfill the completion before exiting this callback method.
                */
                completion()
            }
        }

        func incomingPushHandled() {
            if let completion = self.incomingPushCompletionCallback {
                completion()
                self.incomingPushCompletionCallback = nil
            }
        }

        // MARK: TVONotificaitonDelegate
    public func callInviteReceived(_ ci: TVOCallInvite) {
            NSLog("callInviteReceived:")

            var from:String = ci.from ?? "Voice Bot"
            from = from.replacingOccurrences(of: "client:", with: "")

            reportIncomingCall(from: from, uuid: ci.uuid)
            self.callInvite = ci
        }

    public func cancelledCallInviteReceived(_ cancelledCallInvite: TVOCancelledCallInvite, error: Error) {
            NSLog("cancelledCallInviteCanceled:")

            if (self.callInvite == nil) {
                NSLog("No pending call invite")
                return
            }

            if let ci = self.callInvite {
                performEndCallAction(uuid: ci.uuid)
            }
        }

        // MARK: TVOCallDelegate
    public func callDidStartRinging(_ call: TVOCall) {
        sendPhoneCallEvents(description: "Ringing", isError: false)

            //self.placeCallButton.setTitle("Ringing", for: .normal)
        }

    public func callDidConnect(_ call: TVOCall) {
            sendPhoneCallEvents(description: "Connected|" + (call.from ?? "client:SafeNSound"), isError: false)

            self.callKitCompletionCallback!(true)

            //self.placeCallButton.setTitle("Hang Up", for: .normal)

            //toggleUIState(isEnabled: true, showCallControl: true)
            //stopSpin()
            toggleAudioRoute(toSpeaker: false)
        }

        public func call(_ call: TVOCall, isReconnectingWithError error: Error) {
            NSLog("call:isReconnectingWithError:")

            //self.placeCallButton.setTitle("Reconnecting", for: .normal)

            //toggleUIState(isEnabled: false, showCallControl: false)
        }

        public func callDidReconnect(_ call: TVOCall) {
            NSLog("callDidReconnect:")

            //self.placeCallButton.setTitle("Hang Up", for: .normal)

            //toggleUIState(isEnabled: true, showCallControl: true)
        }

        public func call(_ call: TVOCall, didFailToConnectWithError error: Error) {
            NSLog("Call failed to connect: \(error.localizedDescription)")

            if let completion = self.callKitCompletionCallback {
                completion(false)
            }

            performEndCallAction(uuid: call.uuid)
            callDisconnected()
        }

    public func call(_ call: TVOCall, didDisconnectWithError error: Error?) {
            self.sendPhoneCallEvents(description: "Call Ended", isError: false)
            if let error = error {
                self.sendPhoneCallEvents(description: "Call Failed: \(error.localizedDescription)", isError: true)
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
            if (self.call != nil) {
                self.call = nil
            }
            if (self.callInvite != nil) {
                self.callInvite = nil
            }

            self.userInitiatedDisconnect = false

            //stopSpin()
            //toggleUIState(isEnabled: true, showCallControl: false)
            //self.placeCallButton.setTitle("Call", for: .normal)
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
        public func providerDidReset(_ provider: CXProvider) {
            NSLog("providerDidReset:")
            audioDevice.isEnabled = true
        }

        public func providerDidBegin(_ provider: CXProvider) {
            NSLog("providerDidBegin")
        }

        public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
            NSLog("provider:didActivateAudioSession:")
            audioDevice.isEnabled = true
        }

        public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
            NSLog("provider:didDeactivateAudioSession:")
        }

        public func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
            NSLog("provider:timedOutPerformingAction:")
        }

        public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
            NSLog("provider:performStartCallAction:")

            //toggleUIState(isEnabled: false, showCallControl: false)
            //startSpin()

            audioDevice.isEnabled = false
            audioDevice.block()

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

        public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
            NSLog("provider:performAnswerCallAction:")

            audioDevice.isEnabled = false
            audioDevice.block()

            self.performAnswerVoiceCall(uuid: action.callUUID) { (success) in
                if (success) {
                    action.fulfill()
                } else {
                    action.fail()
                }
            }

            action.fulfill()
        }

        public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
            NSLog("provider:performEndCallAction:")

            audioDevice.isEnabled = true

            if (self.call != nil) {
                NSLog("provider:performEndCallAction: disconnecting call")
                self.call?.disconnect()
                //self.callInvite = nil
                //self.call = nil
                action.fulfill()
                return
            }

            if (self.callInvite != nil) {
                NSLog("provider:performEndCallAction: rejecting call")
                self.callInvite?.reject()
                //self.callInvite = nil
                //self.call = nil
                action.fulfill()
                return
            }
        }

        public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
            NSLog("provider:performSetHeldAction:")
            if let call = self.call {
                call.isOnHold = action.isOnHold
                action.fulfill()
            } else {
                action.fail()
            }
        }

        public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
            NSLog("provider:performSetMutedAction:")

            if let call = self.call {
                call.isMuted = action.isMuted
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

            NSLog("performEndCallAction method invoked")

            let endCallAction = CXEndCallAction(call: uuid)
            let transaction = CXTransaction(action: endCallAction)

            callKitCallController.request(transaction) { error in
                if let error = error {
                    self.sendPhoneCallEvents(description: "End Call Failed: \(error.localizedDescription).", isError: true)
                } else {
                    self.sendPhoneCallEvents(description: "Call Ended", isError: false)
                }
            }
        }

        func performVoiceCall(uuid: UUID, client: String?, completionHandler: @escaping (Bool) -> Swift.Void) {
            /* guard let accessToken = fetchAccessToken() else {
                completionHandler(false)
                return
            } */

            let connectOptions: TVOConnectOptions = TVOConnectOptions(accessToken: accessToken) { (builder) in
                builder.params = ["PhoneNumber": self.callTo, "From": self.identity]
                for (key, value) in self.callArgs {
                    if (key != "to" && key != "toDisplayName" && key != "from") {
                        builder.params[key] = "\(value)"
                    }
                }
                builder.uuid = uuid
            }
            let theCall = TwilioVoice.connect(with: connectOptions, delegate: self)
            self.call = theCall
            self.callKitCompletionCallback = completionHandler
        }

        func performAnswerVoiceCall(uuid: UUID, completionHandler: @escaping (Bool) -> Swift.Void) {
            if let ci = self.callInvite {
                let acceptOptions: TVOAcceptOptions = TVOAcceptOptions(callInvite: ci) { (builder) in
                    builder.uuid = ci.uuid
                }
                NSLog("performAnswerVoiceCall: answering call")
                let theCall = ci.accept(with: acceptOptions, delegate: self)
                self.call = theCall
                self.callKitCompletionCallback = completionHandler

                guard #available(iOS 13, *) else {
                    self.incomingPushHandled()
                    return
                }
            } else {
                NSLog("No CallInvite matches the UUID")
            }
        }

    public func onListen(withArguments arguments: Any?,
                         eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(TVOCallDelegate.call(_:didDisconnectWithError:)),
            name: NSNotification.Name(rawValue: "PhoneCallEvent"),
            object: nil)

        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NotificationCenter.default.removeObserver(self)
        eventSink = nil
        return nil
    }

    private func sendPhoneCallEvents(description: String, isError: Bool) {
        NSLog(description)
        guard let eventSink = eventSink else {
            return
        }

        if isError
        {
            eventSink(FlutterError(code: "unavailable",
                                   message: description,
                                   details: nil))
        }
        else
        {
            eventSink(description)
        }
    }



}

extension UIWindow {
    func topMostViewController() -> UIViewController? {
        guard let rootViewController = self.rootViewController else {
            return nil
        }
        return topViewController(for: rootViewController)
    }

    func topViewController(for rootViewController: UIViewController?) -> UIViewController? {
        guard let rootViewController = rootViewController else {
            return nil
        }
        guard let presentedViewController = rootViewController.presentedViewController else {
            return rootViewController
        }
        switch presentedViewController {
        case is UINavigationController:
            let navigationController = presentedViewController as! UINavigationController
            return topViewController(for: navigationController.viewControllers.last)
        case is UITabBarController:
            let tabBarController = presentedViewController as! UITabBarController
            return topViewController(for: tabBarController.selectedViewController)
        default:
            return topViewController(for: presentedViewController)
        }
    }


}
