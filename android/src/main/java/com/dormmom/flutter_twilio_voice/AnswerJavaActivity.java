package com.dormmom.flutter_twilio_voice;

import android.Manifest;
import android.app.KeyguardManager;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
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

    private CallInvite activeCallInvite;
    private Call activeCall;
    private NotificationManager notificationManager;
    private int activeCallNotificationId;
    private static final int MIC_PERMISSION_REQUEST_CODE = 17893;
    private PowerManager.WakeLock wakeLock;
    private TextView tvCallStatus;
    private ImageView btnAnswer;
    private ImageView btnReject;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_answer);

        tvCallStatus = (TextView) findViewById(R.id.tvCallStatus) ;
        btnAnswer = (ImageView) findViewById(R.id.btnAnswer);
        btnReject = (ImageView) findViewById(R.id.btnReject);

        KeyguardManager kgm = (KeyguardManager) getSystemService(Context.KEYGUARD_SERVICE);
        Boolean isKeyguardUp = kgm.inKeyguardRestrictedInputMode();
        KeyguardManager.KeyguardLock kgl = kgm.newKeyguardLock("OnCallActivityNew");

        if (isKeyguardUp){
            kgl.disableKeyguard();
            isKeyguardUp = false;
        }

        PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
        wakeLock = pm.newWakeLock(PowerManager.FULL_WAKE_LOCK, TAG);
        wakeLock.acquire();

        notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

        handleIncomingCallIntent(getIntent());
    }

    private void handleIncomingCallIntent(Intent intent){
        if (intent != null && intent.getAction() != null){
            String action = intent.getAction();
            activeCallInvite = intent.getParcelableExtra(Constants.INCOMING_CALL_INVITE);
            activeCallNotificationId = intent.getIntExtra(Constants.INCOMING_CALL_NOTIFICATION_ID, 0);
            tvCallStatus.setText("Incoming call...");
            switch (action){
                case Constants.ACTION_INCOMING_CALL: handleIncomingCall();
                case Constants.ACTION_INCOMING_CALL_NOTIFICATION: configCallUI();
                case Constants.ACTION_CANCEL_CALL: newCancelCallClickListener();
                case Constants.ACTION_FCM_TOKEN: {
                    //VoiceRegister.retrieveAccessToken(this)
                }
                case Constants.ACTION_ACCEPT: newAnswerCallClickListener();
                case Constants.ACTION_REJECT: newCancelCallClickListener();
                default: {
                }
            }
        }
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        if (intent != null && intent.getAction() != null){
            switch (intent.getAction()){
                case Constants.ACTION_ACCEPT: newAnswerCallClickListener();
                case Constants.ACTION_REJECT: newCancelCallClickListener();
                default: {
                }
            }
        }
    }

    private void handleIncomingCall(){
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            configCallUI();
        } else {
            if (isAppVisible()) {
                configCallUI();
            }
        }
    }


    private void configCallUI() {
        SoundPoolManager.getInstance(this).playRinging();
        if (activeCallInvite != null){
            btnAnswer.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    if (!checkPermissionForMicrophone()) {
                        requestAudioPermissions();
                    } else {
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
        if (activeCallInvite != null) {
            Intent cancelIntent = new Intent(this, IncomingCallNotificationService.class);
            cancelIntent.setAction(Constants.ACTION_CANCEL_CALL);
            cancelIntent.putExtra(Constants.INCOMING_CALL_INVITE, activeCallInvite);
            startService(cancelIntent);
            finish();
        }
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
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED){
            if (ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.RECORD_AUDIO)){
                ActivityCompat.requestPermissions(this, permissions, MIC_PERMISSION_REQUEST_CODE);
            } else {
                ActivityCompat.requestPermissions(this, permissions, MIC_PERMISSION_REQUEST_CODE);
            }
        } else if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED){
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