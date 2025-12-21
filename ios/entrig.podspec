Pod::Spec.new do |s|
  s.name             = 'entrig'
  s.version          = '0.0.5-dev'
  s.summary          = 'Entrig Flutter Plugin for iOS'
  s.description      = <<-DESC
Flutter plugin for Entrig push notifications integration.
                       DESC
  s.homepage         = 'https://entrig.com'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Entrig' => 'team@entrig.com' }
  s.source           = { :path => '.' }

  s.source_files = 'Classes/**/*'
  s.ios.deployment_target = '14.0'
  s.swift_version = '5.9'

  s.dependency 'Flutter'
  s.dependency 'EntrigSDK', '0.0.5-dev'
end
