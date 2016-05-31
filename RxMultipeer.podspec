
Pod::Spec.new do |s|
  s.name             = "RxMultipeer"
  s.version          = "1.1.2"
  s.summary          = "A testable, Rx* wrapper around MultipeerConnectivity"
  s.homepage         = "https://github.com/RxSwiftCommunity/RxMultipeer"
  s.license          = 'MIT'
  s.author           = { "Nathan Kot" => "nk@nathankot.com" }
  s.source           = { :git => "https://github.com/RxSwiftCommunity/RxMultipeer.git", :tag => s.version.to_s }

  s.platform     = :ios
  s.ios.deployment_target = "8.0"
  s.requires_arc = true

  s.source_files = 'RxMultipeer/**/*'
  s.resource_bundles = {}

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'MultipeerConnectivity'
  s.dependency 'RxSwift', '~> 2.3.0'
  s.dependency 'RxCocoa', '~> 2.3.0'
end
