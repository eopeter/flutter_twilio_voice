package com.dormmom.flutter_twilio_voice;

import com.twilio.voice.Call;
import com.twilio.voice.CallException;
import com.twilio.voice.CallInvite;
import com.twilio.voice.ConnectOptions;
import com.twilio.voice.RegistrationException;
import com.twilio.voice.RegistrationListener;
import com.twilio.voice.UnregistrationListener;
import com.twilio.voice.Voice;

import java.util.HashMap;
import android.Manifest;
import android.app.Activity;
import android.app.NotificationManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.os.Build;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

public class FlutterTwilioVoicePlugin implements FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler,
  ActivityAware, PluginRegistry.NewIntentListener {

    private static final String CHANNEL_NAME = "flutter_twilio_voice";
    private static final String TAG = "TwilioVoicePlugin";
    public static final String TwilioPreferences = "mx.TwilioPreferences";
    private static final int MIC_PERMISSION_REQUEST_CODE = 1;

    private String accessToken;
    private AudioManager audioManager;
    private int savedAudioMode = AudioManager.MODE_INVALID;

    private boolean isReceiverRegistered = false;
    private VoiceBroadcastReceiver voiceBroadcastReceiver;


    private NotificationManager notificationManager;
    //private SoundPoolManager soundPoolManager;
    private CallInvite activeCallInvite;
    private Call activeCall;
    private int activeCallNotificationId;
    private Context context;
    private Activity activity;

    RegistrationListener registrationListener = registrationListener();
    UnregistrationListener unregistrationListener = unregistrationListener();
    Call.Listener callListener = callListener();
    private MethodChannel methodChannel;
    private EventChannel eventChannel;
    private EventChannel.EventSink eventSink;
    private String fcmToken;
    private boolean callOutgoing;

    private SharedPreferences pSharedPref;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding flutterPluginBinding) {
        register(flutterPluginBinding.getFlutterEngine().getDartExecutor(), this, flutterPluginBinding.getApplicationContext());
    }

    private static void register(BinaryMessenger messenger, FlutterTwilioVoicePlugin plugin, Context context) {
        plugin.methodChannel = new MethodChannel(messenger, CHANNEL_NAME + "/messages");
        plugin.methodChannel.setMethodCallHandler(plugin);

        plugin.eventChannel = new EventChannel(messenger, CHANNEL_NAME + "/events");
        plugin.eventChannel.setStreamHandler(plugin);

        plugin.context = context;
        //plugin.soundPoolManager = SoundPoolManager.getInstance(context);

        plugin.notificationManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        plugin.voiceBroadcastReceiver = new VoiceBroadcastReceiver(plugin);
        plugin.registerReceiver();

        /*
         * Needed for setting/abandoning audio focus during a call
         */
        plugin.audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        plugin.audioManager.setSpeakerphoneOn(true);

        plugin.pSharedPref = context.getSharedPreferences(TwilioPreferences, Context.MODE_PRIVATE);


        /*
         * Enable changing the volume using the up/down keys during a conversation
         */
        //setVolumeControlStream(AudioManager.STREAM_VOICE_CALL);
    }

    /** Plugin registration. */
    public static void registerWith(PluginRegistry.Registrar registrar) {
        // Detect if we've been launched in background
        if (registrar.activity() == null) {
            return;
        }

        final FlutterTwilioVoicePlugin instance = new FlutterTwilioVoicePlugin();
        instance.activity = registrar.activity();
        register(registrar.messenger(), instance, registrar.context());
        registrar.addNewIntentListener(instance);
    }

    private void handleIncomingCallIntent(Intent intent) {
        if (intent != null && intent.getAction() != null) {
            String action = intent.getAction();
            Log.d(TAG, "Handling incoming call intent for action " + action);
            activeCallInvite = intent.getParcelableExtra(Constants.INCOMING_CALL_INVITE);
            activeCallNotificationId = intent.getIntExtra(Constants.INCOMING_CALL_NOTIFICATION_ID, 0);
            callOutgoing = false;

            switch (action) {
            case Constants.ACTION_INCOMING_CALL:
                handleIncomingCall(activeCallInvite.getFrom(), activeCallInvite.getTo());
                break;
            case Constants.ACTION_INCOMING_CALL_NOTIFICATION:
                handleIncomingCall(activeCallInvite.getFrom(), activeCallInvite.getTo());
                break;
            case Constants.ACTION_CANCEL_CALL:
                handleCancel();
                break;
            case Constants.ACTION_FCM_TOKEN:
                //retrieveAccessToken();
                break;
            case Constants.ACTION_REJECT:
                //do somethinng????
                break;
            case Constants.ACTION_ACCEPT:
                answer();
                // do in receive call activty
                // if(checkPermissionForMicrophone()) {
                // }else{
                //     requestPermissionForMicrophone();
                // }
                break;
            default:
                break;
            }
        }
    }

    private void showIncomingCallDialog() {
        this.handleIncomingCall(activeCallInvite.getFrom(), activeCallInvite.getTo());
    }

    private void handleIncomingCall(String from, String to) {
        sendPhoneCallEvents("Ringing|" + from + "|" + to + "|" + (callOutgoing ? "Outgoing" : "Incoming"));
        SoundPoolManager.getInstance(activity).playRinging();
        /*if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            showIncomingCallDialog();
        } else {
            if (isAppVisible()) {
                showIncomingCallDialog();
            }
        }*/
    }

    private void handleCancel() {
        //if (alertDialog != null && alertDialog.isShowing()) {
        callOutgoing = false;
        sendPhoneCallEvents("Call Ended");
        SoundPoolManager.getInstance(activity).stopRinging();
            //alertDialog.cancel();
        //}
    }

    private void registerReceiver() {
        if (!isReceiverRegistered) {
            Log.d(TAG, "registerReceiver");
            IntentFilter intentFilter = new IntentFilter();
            intentFilter.addAction(Constants.ACTION_INCOMING_CALL);
            intentFilter.addAction(Constants.ACTION_INCOMING_CALL_NOTIFICATION);
            intentFilter.addAction(Constants.ACTION_CANCEL_CALL);
            intentFilter.addAction(Constants.ACTION_FCM_TOKEN);
            intentFilter.addAction(Constants.ACTION_ACCEPT);
            intentFilter.addAction(Constants.ACTION_REJECT);
            LocalBroadcastManager.getInstance(this.activity).registerReceiver(
              voiceBroadcastReceiver, intentFilter);
            isReceiverRegistered = true;
        }
    }

    private void unregisterReceiver() {
        if (isReceiverRegistered) {
            LocalBroadcastManager.getInstance(this.activity).unregisterReceiver(voiceBroadcastReceiver);
            isReceiverRegistered = false;
        }
    }

    private RegistrationListener registrationListener() {
        return new RegistrationListener() {
            @Override
            public void onRegistered(String accessToken, String fcmToken) {
                Log.d(TAG, "Successfully registered FCM " + fcmToken);
            }

            @Override
            public void onError(RegistrationException error, String accessToken, String fcmToken) {
                String message = String.format("Registration Error: %d, %s", error.getErrorCode(), error.getMessage());
                Log.e(TAG, message);
            }
        };
    }

    private UnregistrationListener unregistrationListener() {
        return new UnregistrationListener() {
            @Override
            public void onUnregistered(String accessToken, String fcmToken) {
                Log.d(TAG, "Successfully un-registered FCM " + fcmToken);
            }

            @Override
            public void onError(RegistrationException error, String accessToken, String fcmToken) {
                String message = String.format("Unregistration Error: %d, %s", error.getErrorCode(), error.getMessage());
                Log.e(TAG, message);
            }
        };
    }

    private static class VoiceBroadcastReceiver extends BroadcastReceiver {

        private final FlutterTwilioVoicePlugin plugin;

        private VoiceBroadcastReceiver(FlutterTwilioVoicePlugin plugin) {
            this.plugin = plugin;
        }

        @Override
        public void onReceive(Context context, Intent intent) {
            String action = intent.getAction();
            Log.d(TAG, "Received broadcast for action " + action);
            if (action != null && (action.equals(Constants.ACTION_INCOMING_CALL) || action.equals(Constants.ACTION_CANCEL_CALL)
              || action.equals(Constants.ACTION_INCOMING_CALL_NOTIFICATION) || action.equals(Constants.ACTION_ACCEPT))) {
                /*
                 * Handle the incoming or cancelled call invite
                 */
                plugin.handleIncomingCallIntent(intent);
            }
        }
    }

    /*
     * Register your FCM token with Twilio to receive incoming call invites
     *
     * If a valid google-services.json has not been provided or the FirebaseInstanceId has not been
     * initialized the fcmToken will be null.
     *
     * In the case where the FirebaseInstanceId has not yet been initialized the
     * VoiceFirebaseInstanceIDService.onTokenRefresh should result in a LocalBroadcast to this
     * activity which will attempt registerForCallInvites again.
     *
     */
    private void registerForCallInvites() {
        if (this.accessToken != null && this.fcmToken != null) {
            Log.i(TAG, "Registering with FCM");
            Voice.register(this.accessToken, Voice.RegistrationChannel.FCM, this.fcmToken, registrationListener);
        }
    }

    private void unregisterForCallInvites() {
        if (this.accessToken != null && this.fcmToken != null) {
            Log.i(TAG, "Un-registering with FCM");
            Voice.unregister(this.accessToken, Voice.RegistrationChannel.FCM, this.fcmToken, unregistrationListener);
        }
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding flutterPluginBinding) {
        Log.d(TAG, "Detatched from Flutter engine");
        //soundPoolManager.release();
    }

    @Override
    public void onListen(Object o, EventChannel.EventSink eventSink) {
        Log.i(TAG, "Setting event sink");
        this.eventSink = eventSink;
    }

    @Override
    public void onCancel(Object o) {
        Log.i(TAG, "Removing event sink");
        this.eventSink = null;
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (call.method.equals("tokens")) {
            Log.d(TAG, "Setting up tokens");
            this.accessToken = call.argument("accessToken");
            this.fcmToken = call.argument("deviceToken");
            this.registerForCallInvites();
            result.success(true);
        } else if (call.method.equals("sendDigits")) {
            String digits = call.argument("digits");
            if (this.activeCall != null) {
                Log.d(TAG, "Sending digits " + digits);
                this.activeCall.sendDigits(digits);
            }
            result.success(true);
        } else if (call.method.equals("hangUp")) {
            Log.d(TAG, "Hanging up");
            this.disconnect();
            result.success(true);
        } else if (call.method.equals("toggleSpeaker")) {
            // nuthin
            result.success(true);
        } else if (call.method.equals("muteCall")) {
            Log.d(TAG, "Muting call");
            this.mute();
            result.success(true);
        } else if (call.method.equals("isOnCall")) {
            Log.d(TAG, "Is on call invoked");
            result.success(this.activeCall != null);
        } else if (call.method.equals("holdCall")) {
            Log.d(TAG, "Hold call invoked");
            this.hold();
            result.success(true);
        } else if (call.method.equals("answer")) {
            Log.d(TAG, "Answering call");
            this.answer();
            result.success(true);
        } else if (call.method.equals("unregister")) {
            this.unregisterForCallInvites();
            result.success(true);
        } else if (call.method.equals("makeCall")) {
            Log.d(TAG, "Making new call");
            sendPhoneCallEvents("LOG|Making new call");
            final HashMap<String, String> params = new HashMap<>();
            params.put("To", call.argument("to").toString());
//             params.put("From", call.argument("from").toString());
            this.callOutgoing = true;
            final ConnectOptions connectOptions = new ConnectOptions.Builder(this.accessToken)
              .params(params)
              .build();
            this.activeCall = Voice.connect(this.activity, connectOptions, this.callListener);
            result.success(true);
        } else if (call.method.equals("registerClient")) {
            String id = call.argument("id");
            String name = call.argument("name");
            if(id != null && name != null && !pSharedPref.contains(id)  ){
                sendPhoneCallEvents("LOG|Registering client " +id +":"+ name);
                SharedPreferences.Editor edit = pSharedPref.edit();
                edit.putString(id, name);
                edit.apply();
            }
        } else if (call.method.equals("unregisterClient")) {
            String id = call.argument("id");
            if(id != null) {
                sendPhoneCallEvents("LOG|Unegistering" + id);
                SharedPreferences.Editor edit = pSharedPref.edit();
                edit.remove(id);
                edit.apply();
            }
        } else if (call.method.equals("defaultCaller")){
            String caller = call.argument("defaultCaller");
            if(caller != null){
                sendPhoneCallEvents("LOG|defaultCaller is "+ caller);
                SharedPreferences.Editor edit = pSharedPref.edit();
                edit.putString("defaultCaller", caller);
                edit.apply();
            }
        } else if (call.method.equals("hasMicPermission")) {
            result.success(this.checkPermissionForMicrophone());
        }else if (call.method.equals("requestMicPermission")){
            sendPhoneCallEvents("LOG|requesting mic permission");
            if (!this.checkPermissionForMicrophone()) {
                boolean hasAccess = this.requestPermissionForMicrophone();
                result.success(hasAccess);
            }else {
                result.success(true);
            }
        }else {
            result.notImplemented();
        }
    }

    /*
     * Accept an incoming Call
     */
    private void answer() {
        Log.d(TAG, "Answering call");
        SoundPoolManager.getInstance(this.context).stopRinging();
        activeCallInvite.accept(this.activity, callListener);
        eventSink.success("Answer");
        notificationManager.cancel(activeCallNotificationId);
    }

    private void sendPhoneCallEvents(String description){
        if(eventSink == null){ return;}
        eventSink.success(description);
    }

    @Override
    public boolean onNewIntent(Intent intent) {
        Log.d(TAG, "onNewIntent");
        this.handleIncomingCallIntent(intent);
        return false;
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding activityPluginBinding) {
        this.activity = activityPluginBinding.getActivity();
        activityPluginBinding.addOnNewIntentListener(this);
        registerReceiver();
        /*
         * Ensure the microphone permission is enabled
         */
//        if (!this.checkPermissionForMicrophone()) {
//            this.requestPermissionForMicrophone();
//        }
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        this.activity = null;
        unregisterReceiver();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding activityPluginBinding) {
        this.activity = activityPluginBinding.getActivity();
        activityPluginBinding.addOnNewIntentListener(this);
        registerReceiver();
    }

    @Override
    public void onDetachedFromActivity() {
        unregisterReceiver();
        this.activity = null;
    }

    private Call.Listener callListener() {
        return new Call.Listener() {
            /*
             * This callback is emitted once before the Call.Listener.onConnected() callback when
             * the callee is being alerted of a Call. The behavior of this callback is determined by
             * the answerOnBridge flag provided in the Dial verb of your TwiML application
             * associated with this client. If the answerOnBridge flag is false, which is the
             * default, the Call.Listener.onConnected() callback will be emitted immediately after
             * Call.Listener.onRinging(). If the answerOnBridge flag is true, this will cause the
             * call to emit the onConnected callback only after the call is answered.
             * See answeronbridge for more details on how to use it with the Dial TwiML verb. If the
             * twiML response contains a Say verb, then the call will emit the
             * Call.Listener.onConnected callback immediately after Call.Listener.onRinging() is
             * raised, irrespective of the value of answerOnBridge being set to true or false
             */
            @Override
            public void onRinging(Call call) {
                Log.d(TAG, "Ringing");
                eventSink.success("Ringing|" + call.getFrom() + "|" + call.getTo() + "|" + (callOutgoing ? "Outgoing" : "Incoming"));
            }

            @Override
            public void onConnectFailure(Call call, CallException error) {
                setAudioFocus(false);
                Log.d(TAG, "Connect failure");
                String message = String.format("Call Error: %d, %s", error.getErrorCode(), error.getMessage());
                Log.e(TAG, message);
                eventSink.success("LOG|"+message);

            }

            @Override
            public void onConnected(Call call) {
                setAudioFocus(true);
                Log.d(TAG, "Connected");
                eventSink.success("LOG|Connected");
                activeCall = call;
                eventSink.success("Connected|" + call.getFrom() + "|" + call.getTo() + "|" + (callOutgoing ? "Outgoing" : "Incoming"));
            }

            @Override
            public void onReconnecting(@NonNull Call call, @NonNull CallException callException) {
                Log.d(TAG, "onReconnecting");
            }

            @Override
            public void onReconnected(@NonNull Call call) {
                Log.d(TAG, "onReconnected");
            }

            @Override
            public void onDisconnected(Call call, CallException error) {
                setAudioFocus(false);
                Log.d(TAG, "Disconnected");
                if (error != null) {
                    String message = String.format("Call Error: %d, %s", error.getErrorCode(), error.getMessage());
                    Log.e(TAG, message);
                }
                eventSink.success("Call Ended");
            }
        };

    }

    private void disconnect() {
        if (activeCall != null) {
            activeCall.disconnect();
            activeCall = null;
        }
    }

    private void hold() {
        if (activeCall != null) {
            boolean hold = activeCall.isOnHold();
            activeCall.hold(!hold);
            eventSink.success(hold ? "Unhold" : "Hold");
        }
    }

    private void mute() {
        if (activeCall != null) {
            boolean mute = activeCall.isMuted();
            activeCall.mute(!mute);
            eventSink.success(mute ? "Unmute" : "Mute");
        }
    }

    private void setAudioFocus(boolean setFocus) {
        if (audioManager != null) {
            if (setFocus) {
                savedAudioMode = audioManager.getMode();
                // Request audio focus before making any device switch.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    AudioAttributes playbackAttributes = new AudioAttributes.Builder()
                      .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                      .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                      .build();
                    AudioFocusRequest focusRequest = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                      .setAudioAttributes(playbackAttributes)
                      .setAcceptsDelayedFocusGain(true)
                      .setOnAudioFocusChangeListener(new AudioManager.OnAudioFocusChangeListener() {
                          @Override
                          public void onAudioFocusChange(int i) {
                          }
                      })
                      .build();
                    audioManager.requestAudioFocus(focusRequest);
                } else {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.FROYO) {
                        int focusRequestResult = audioManager.requestAudioFocus(
                          new AudioManager.OnAudioFocusChangeListener() {

                              @Override
                              public void onAudioFocusChange(int focusChange)
                              {
                              }
                          }, AudioManager.STREAM_VOICE_CALL,
                          AudioManager.AUDIOFOCUS_GAIN_TRANSIENT);
                    }
                }
                /*
                 * Start by setting MODE_IN_COMMUNICATION as default audio mode. It is
                 * required to be in this mode when playout and/or recording starts for
                 * best possible VoIP performance. Some devices have difficulties with speaker mode
                 * if this is not set.
                 */
                audioManager.setMode(AudioManager.MODE_IN_COMMUNICATION);
            } else {
                audioManager.setMode(savedAudioMode);
                audioManager.abandonAudioFocus(null);
            }
        }
    }

    private boolean checkPermissionForMicrophone() {
        eventSink.success("LOG|checkPermissionForMicrophone");
        int resultMic = ContextCompat.checkSelfPermission(this.context, Manifest.permission.RECORD_AUDIO);
        return resultMic == PackageManager.PERMISSION_GRANTED;
    }

    private boolean requestPermissionForMicrophone() {
        eventSink.success("LOG|requestPermissionForMicrophone");
        if (ActivityCompat.shouldShowRequestPermissionRationale(this.activity, Manifest.permission.RECORD_AUDIO)) {
            eventSink.success("RequestMicrophoneAccess");
            return false;
        } else {
            ActivityCompat.requestPermissions(this.activity,
              new String[]{Manifest.permission.RECORD_AUDIO},
              MIC_PERMISSION_REQUEST_CODE);
            return true;
        }
    }
/*

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        */
/*
         * Check if microphone permissions is granted
         *//*

        if (requestCode == MIC_PERMISSION_REQUEST_CODE && permissions.length > 0) {
            if (grantResults[0] != PackageManager.PERMISSION_GRANTED) {

                Log.d(TAG, "Microphone permissions needed. Please allow in your application settings.");
            }
            else {
                Log.d(TAG, "Microphone permissions granted.");
                if(activeCallInvite != null){
                    answer();
                }
//                retrieveAccessToken();
            }

        }
            }*/

}
