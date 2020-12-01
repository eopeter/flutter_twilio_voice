#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_twilio_voice'
  s.version          = '0.0.3'
  s.summary          = 'Provides an interface to Twilio&#x27;s Programmable Voice SDK to allows adding voice-over-IP (VoIP) calling into your Flutter applications.'
  s.description      = <<-DESC
Provides an interface to Twilio&#x27;s Programmable Voice SDK to allows adding voice-over-IP (VoIP) calling into your Flutter applications.
                       DESC
  s.homepage         = 'https://dormmom.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Emmanuel Oche' => 'eopeter@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'TwilioVoice','~> 6.0.2'


  s.pod_target_xcconfig = { "DEFINES_MODULE" => "YES" }
  s.swift_version = '5.0'
  s.ios.deployment_target = '11.0'
end

