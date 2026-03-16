Pod::Spec.new do |s|
  s.name             = 'CrossmintDeviceSigner'
  s.version          = '0.1.0'
  s.summary          = 'Hardware-backed device signer key storage for Crossmint wallets (iOS).'
  s.homepage         = 'https://github.com/Crossmint/crossmint-swift-sdk'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = 'Paella Labs Inc'
  s.platforms        = { :ios => '15.0' }

  s.source           = {
    :git => 'https://github.com/Crossmint/crossmint-swift-sdk.git',
    :tag => "CrossmintDeviceSigner/#{s.version}"
  }

  s.source_files     = 'Sources/DeviceSigner/**/*.swift'

  s.swift_version    = '5.10'

  s.frameworks       = 'CryptoKit', 'LocalAuthentication', 'Security'
end
