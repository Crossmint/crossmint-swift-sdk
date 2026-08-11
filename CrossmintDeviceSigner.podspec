Pod::Spec.new do |s|
  s.name             = 'CrossmintDeviceSigner'
  s.version          = '1.1.4'
  s.summary          = 'Hardware-backed device signer key storage for Crossmint wallets (iOS).'
  s.homepage         = 'https://github.com/Crossmint/crossmint-swift-sdk'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = 'Crossmint Inc'
  s.platforms        = { :ios => '15.0' }

  s.source           = {
    :git => 'https://github.com/Crossmint/crossmint-swift-sdk.git',
    :tag => s.version.to_s
  }

  s.source_files     = 'Sources/DeviceSigner/**/*.swift'

  s.swift_version    = '6.0'

  s.frameworks       = 'CryptoKit', 'LocalAuthentication', 'Security'
end
