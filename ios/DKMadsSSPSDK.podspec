Pod::Spec.new do |s|
  s.name             = 'DKMadsSSPSDK'
  s.version          = '0.5.26'
  s.summary          = 'DKMads SSP iOS SDK for publisher app monetization.'
  s.description      = <<-DESC
DKMadsSSPSDK provides initialization, banner views,
ad loading, response diagnostics, and telemetry for iOS publisher apps.
  DESC

  s.homepage         = 'https://github.com/DKMads-Codocs/dkmads-ssp-sdk'
  s.license          = { type: 'MIT', text: 'Copyright (c) DKMads. Released under the MIT License.' }
  s.author           = { 'DKMads' => 'engineering@dkmads.com' }
  s.source           = {
    git: 'https://github.com/DKMads-Codocs/dkmads-ssp-sdk.git',
    tag: "sdk-#{s.version}"
  }

  s.platform         = :ios, '13.0'
  s.swift_version    = '5.9'
  s.requires_arc     = true
  s.module_name      = 'DKMadsSSPSDK'
  s.source_files     = 'Sources/DKMadsSSPSDK/**/*.swift'
  s.frameworks       = 'Foundation', 'UIKit', 'WebKit', 'AVFoundation', 'SafariServices'
end
