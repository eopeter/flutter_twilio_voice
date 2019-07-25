#import "FlutterTwilioVoicePlugin.h"
#import <flutter_twilio_voice/flutter_twilio_voice-Swift.h>

@implementation FlutterTwilioVoicePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterTwilioVoicePlugin registerWithRegistrar:registrar];
}
@end
