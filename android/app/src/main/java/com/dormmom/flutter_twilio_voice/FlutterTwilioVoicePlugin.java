package com.dormmom.flutter_twilio_voice;

import com.twilio.voice.Call;
import com.twilio.voice.CallException;
import com.twilio.voice.CallInvite;
import com.twilio.voice.ConnectOptions;
import com.twilio.voice.RegistrationException;
import com.twilio.voice.RegistrationListener;
import com.twilio.voice.Voice;

import java.util.HashMap;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.os.Build;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;
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
    private static final int MIC_PERMISSION_REQUEST_CODE = 1;

    private String accessToken;
    private AudioManager audioManager;
    private int savedAudioMode = AudioManager.MODE_INVALID;

    //private SoundPoolManager soundPoolManager;
    private Call activeCall;
    private Context context;
    private Activity activity;

    Call.Listener callListener = callListener();

    @Override
    public void onAttachedToEngine(FlutterPluginBinding flutterPluginBinding) {
        register(flutterPluginBinding.getFlutterEngine().getDartExecutor(), this, flutterPluginBinding.getApplicationContext());
    }

    private static void register(BinaryMessenger messenger, FlutterTwilioVoicePlugin plugin, Context context) {
        final MethodChannel methodChannel = new MethodChannel(messenger, CHANNEL_NAME);
        methodChannel.setMethodCallHandler(plugin);

        final EventChannel eventChannel = new EventChannel(messenger, CHANNEL_NAME);
        eventChannel.setStreamHandler(plugin);

        plugin.context = context;
        //plugin.soundPoolManager = SoundPoolManager.getInstance(context);

        /*
         * Needed for setting/abandoning audio focus during a call
         */
        plugin.audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        plugin.audioManager.setSpeakerphoneOn(true);

        /*
         * Enable changing the volume using the up/down keys during a conversation
         */
        //setVolumeControlStream(AudioManager.STREAM_VOICE_CALL);



        /*
         * Displays a call dialog if the intent contains a call invite
         */
        //handleIncomingCallIntent(getIntent());

        /*
         * Ensure the microphone permission is enabled
         */
        if (!plugin.checkPermissionForMicrophone()) {
            plugin.requestPermissionForMicrophone();
        }
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

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding flutterPluginBinding) {

    }

    @Override
    public void onListen(Object o, EventChannel.EventSink eventSink) {

    }

    @Override
    public void onCancel(Object o) {


    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (call.method.equals("accessToken")) {
            this.accessToken = call.argument("token");
            result.success("");
        } else if (call.method.equals("hangup")) {
            this.disconnect();
            result.success("");
        } else if (call.method.equals("mute")) {
            this.mute();
            result.success("");
        } else if (call.method.equals("hold")) {
            this.hold();
            result.success("");
        } else if (call.method.equals("makeCall")) {
            final HashMap<String, String> params = new HashMap<>();
            params.put("to", call.argument("to"));
            final ConnectOptions connectOptions = new ConnectOptions.Builder(this.accessToken)
              .params(params)
              .build();
            this.activeCall = Voice.connect(this.activity, connectOptions, this.callListener);
            result.success("");
        } else {
            result.notImplemented();
        }
    }

    @Override
    public boolean onNewIntent(Intent intent) {
        //this.handleIntent(context, intent);
        return false;
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding activityPluginBinding) {
        this.activity = activityPluginBinding.getActivity();
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {

    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding activityPluginBinding) {
        this.activity = activityPluginBinding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() {

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
            }

            @Override
            public void onConnectFailure(Call call, CallException error) {
                setAudioFocus(false);
                Log.d(TAG, "Connect failure");
                String message = String.format("Call Error: %d, %s", error.getErrorCode(), error.getMessage());
                Log.e(TAG, message);

            }

            @Override
            public void onConnected(Call call) {
                setAudioFocus(true);
                Log.d(TAG, "Connected");
                activeCall = call;
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
            boolean hold = !activeCall.isOnHold();
            activeCall.hold(hold);

        }
    }

    private void mute() {
        if (activeCall != null) {
            boolean mute = !activeCall.isMuted();
            activeCall.mute(mute);

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
        int resultMic = ContextCompat.checkSelfPermission(this.context, Manifest.permission.RECORD_AUDIO);
        return resultMic == PackageManager.PERMISSION_GRANTED;
    }

    private void requestPermissionForMicrophone() {
        if (this.activity.shouldShowRequestPermissionRationale(Manifest.permission.RECORD_AUDIO)) {

        } else {
            this.activity.requestPermissions(
              new String[]{Manifest.permission.RECORD_AUDIO},
              MIC_PERMISSION_REQUEST_CODE);
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
            }*/
/* else {
                retrieveAccessToken();
            }*//*

        }
    }
*/
}


/*
class SoundPoolManager {

    private boolean playing = false;
    private boolean loaded = false;
    private boolean playingCalled = false;
    private float actualVolume;
    private float maxVolume;
    private float volume;
    private AudioManager audioManager;
    private SoundPool soundPool;
    private int ringingSoundId;
    private int ringingStreamId;
    private int disconnectSoundId;
    private static SoundPoolManager instance;

    private SoundPoolManager(Context context) {
        // AudioManager audio settings for adjusting the volume
        audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        actualVolume = (float) audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
        maxVolume = (float) audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
        volume = actualVolume / maxVolume;

        // Load the sounds
        int maxStreams = 1;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            soundPool = new SoundPool.Builder()
              .setMaxStreams(maxStreams)
              .build();
        } else {
            soundPool = new SoundPool(maxStreams, AudioManager.STREAM_MUSIC, 0);
        }

        soundPool.setOnLoadCompleteListener(new SoundPool.OnLoadCompleteListener() {
            @Override
            public void onLoadComplete(SoundPool soundPool, int sampleId, int status) {
                loaded = true;
                if (playingCalled) {
                    playRinging();
                    playingCalled = false;
                }
            }

        });
        ringingSoundId = soundPool.load(context, R.raw.incoming, 1);
        disconnectSoundId = soundPool.load(context, R.raw.disconnect, 1);
    }

    public static SoundPoolManager getInstance(Context context) {
        if (instance == null) {
            instance = new SoundPoolManager(context);
        }
        return instance;
    }

    public void playRinging() {
        if (loaded && !playing) {
            ringingStreamId = soundPool.play(ringingSoundId, volume, volume, 1, -1, 1f);
            playing = true;
        } else {
            playingCalled = true;
        }
    }

    public void stopRinging() {
        if (playing) {
            soundPool.stop(ringingStreamId);
            playing = false;
        }
    }

    public void playDisconnect() {
        if (loaded && !playing) {
            soundPool.play(disconnectSoundId, volume, volume, 1, 0, 1f);
            playing = false;
        }
    }

    public void release() {
        if (soundPool != null) {
            soundPool.unload(ringingSoundId);
            soundPool.unload(disconnectSoundId);
            soundPool.release();
            soundPool = null;
        }
        instance = null;
    }
}
*/
