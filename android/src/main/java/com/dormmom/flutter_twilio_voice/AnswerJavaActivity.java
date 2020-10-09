package com.dormmom.flutter_twilio_voice;

import android.Manifest;
import android.app.KeyguardManager;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.PowerManager;
import android.util.Log;
import android.view.View;
import android.view.WindowManager;
import android.widget.TextView;
import android.widget.ImageView;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.ProcessLifecycleOwner;
import com.dormmom.flutter_twilio_voice.R;
import com.dormmom.flutter_twilio_voice.Constants;
import com.dormmom.flutter_twilio_voice.IncomingCallNotificationService;
import com.dormmom.flutter_twilio_voice.SoundPoolManager;
import com.twilio.voice.Call;
import com.twilio.voice.CallInvite;
import java.io.File;

import android.os.Bundle;

public class AnswerJavaActivity extends AppCompatActivity{

    private static String TAG = "AnswerActivity";
    public static final String TwilioPreferences = "mx.TwilioPreferences";

    private CallInvite activeCallInvite;
    private Call activeCall;
    private NotificationManager notificationManager;
    private int activeCallNotificationId;
    private static final int MIC_PERMISSION_REQUEST_CODE = 17893;
    private PowerManager.WakeLock wakeLock;
    private TextView tvUserName;
    private TextView tvCallStatus;
    private ImageView btnAnswer;
    private ImageView btnReject;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_answer);

        tvUserName = (TextView) findViewById(R.id.tvUserName) ;
        tvCallStatus = (TextView) findViewById(R.id.tvCallStatus) ;
        btnAnswer = (ImageView) findViewById(R.id.btnAnswer);
        btnReject = (ImageView) findViewById(R.id.btnReject);

        KeyguardManager kgm = (KeyguardManager) getSystemService(Context.KEYGUARD_SERVICE);
        Boolean isKeyguardUp = kgm.inKeyguardRestrictedInputMode();

        Log.d(TAG, "isKeyguardUp $isKeyguardUp");
        if (isKeyguardUp) {

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                Log.d(TAG, "ohh shiny phone!");
                setTurnScreenOn(true);
                setShowWhenLocked(true);
                kgm.requestDismissKeyguard(this, null);

            }else{
                Log.d(TAG, "diego's old phone!");
                PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
                wakeLock = pm.newWakeLock(PowerManager.FULL_WAKE_LOCK, TAG);
                wakeLock.acquire();

                getWindow().addFlags(
                        WindowManager.LayoutParams.FLAG_FULLSCREEN |
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD |
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED |
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                );
            }
        }

        notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

        handleIncomingCallIntent(getIntent());
    }

    private void handleIncomingCallIntent(Intent intent){
        if (intent != null && intent.getAction() != null){
            String action = intent.getAction();
            activeCallInvite = intent.getParcelableExtra(Constants.INCOMING_CALL_INVITE);
        
            String fromId = activeCallInvite.getFrom().replace("client:","");
            SharedPreferences preferences = getApplicationContext().getSharedPreferences(TwilioPreferences, Context.MODE_PRIVATE);
            String caller = preferences.getString(fromId, preferences.getString("defaultCaller", "Desconocido"));

            activeCallNotificationId = intent.getIntExtra(Constants.INCOMING_CALL_NOTIFICATION_ID, 0);
            tvUserName.setText(caller);
            tvCallStatus.setText("Llamada entrante...");
            Log.d(TAG, "handleIncomingCallIntent-");
            Log.d(TAG, action);
            switch (action){
                case Constants.ACTION_INCOMING_CALL: 
                    handleIncomingCall();
                    break;
                case Constants.ACTION_INCOMING_CALL_NOTIFICATION: 
                    configCallUI();
                    break;
                case Constants.ACTION_CANCEL_CALL: 
                    newCancelCallClickListener();
                    break;
                case Constants.ACTION_ACCEPT: 
                    newAnswerCallClickListener();
                    break;
                case Constants.ACTION_REJECT: 
                    newCancelCallClickListener();
                    break;
                default: {
                }
            }
        }
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        if (intent != null && intent.getAction() != null){
        Log.d(TAG, "onNewIntent-");
        Log.d(TAG, intent.getAction());
            switch (intent.getAction()){
                case Constants.ACTION_CANCEL_CALL:
                    newCancelCallClickListener();
                    break;
                default: {
                }
            }
        }
    }

    private void handleIncomingCall(){
        Log.d(TAG, "handleIncomingCall");
        configCallUI();
    }


    private void configCallUI() {
        // SoundPoolManager.getInstance(this).playRinging();
        Log.d(TAG, "configCallUI");
        if (activeCallInvite != null){
            btnAnswer.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    Log.d(TAG, "onCLick");
                    if (!checkPermissionForMicrophone()) {
                        Log.d(TAG, "configCallUI-requestAudioPermissions");
                        requestAudioPermissions();
                    } else {
                        Log.d(TAG, "configCallUI-newAnswerCallClickListener");
                        newAnswerCallClickListener();
                    }
                }
            });

            btnReject.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    rejectCallClickListener();
                    //SoundPoolManager.getInstance(this@AnswerJavaActivity).playDisconnect();
                    disconnect();
                    finish();
                }
            });
        }
    }

    private void disconnect(){
        if (activeCall != null){
            activeCall.disconnect();
            activeCall = null;
        }
    }

    private void newAnswerCallClickListener(){
        Log.d(TAG, "Clicked accept");
        Intent acceptIntent = new Intent(this, IncomingCallNotificationService.class);
        acceptIntent.setAction(Constants.ACTION_ACCEPT);
        acceptIntent.putExtra(Constants.INCOMING_CALL_INVITE, activeCallInvite);
        acceptIntent.putExtra(Constants.INCOMING_CALL_NOTIFICATION_ID, activeCallNotificationId);
        Log.d(TAG, "Clicked accept startService");
        startService(acceptIntent);
        finish();
    }

    private void newCancelCallClickListener(){
        //SoundPoolManager.getInstance(this@AnswerJavaActivity).stopRinging();
        finish();
    }

    private void rejectCallClickListener(){
        //SoundPoolManager.getInstance(this@AnswerJavaActivity).stopRinging();
        if (activeCallInvite != null) {
            Intent rejectIntent = new Intent(this, IncomingCallNotificationService.class);
            rejectIntent.setAction(Constants.ACTION_REJECT);
            rejectIntent.putExtra(Constants.INCOMING_CALL_INVITE, activeCallInvite);
            startService(rejectIntent);
            finish();
        }
    }

    private Boolean checkPermissionForMicrophone(){
        int resultMic = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO);
        return resultMic == PackageManager.PERMISSION_GRANTED;
    }

    private void requestAudioPermissions(){
        String[] permissions = {Manifest.permission.RECORD_AUDIO};
         Log.d(TAG, "requestAudioPermissions");
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED){
            if (ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.RECORD_AUDIO)){
                ActivityCompat.requestPermissions(this, permissions, MIC_PERMISSION_REQUEST_CODE);
            } else {
                ActivityCompat.requestPermissions(this, permissions, MIC_PERMISSION_REQUEST_CODE);
            }
        } else if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED){
            Log.d(TAG, "requestAudioPermissions-> permission granted->newAnswerCallClickListener");
            newAnswerCallClickListener();
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        switch (requestCode){
            case MIC_PERMISSION_REQUEST_CODE:
                if (grantResults.length == 0 || grantResults[0] != PackageManager.PERMISSION_GRANTED){
                    Toast.makeText(this, "Microphone permissions needed. Please allow in your application settings.", Toast.LENGTH_LONG).show();
                    rejectCallClickListener();
                } else {
                    newAnswerCallClickListener();
                }
            default:
                throw new IllegalStateException("Unexpected value: " + requestCode);
        }
    }

    private Boolean isAppVisible(){
        return ProcessLifecycleOwner
                .get()
                .getLifecycle()
                .getCurrentState()
                .isAtLeast(Lifecycle.State.STARTED);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (wakeLock != null){
            wakeLock.release();
        }
    }

}