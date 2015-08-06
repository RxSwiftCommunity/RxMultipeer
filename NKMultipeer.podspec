
Pod::Spec.new do |s|
  s.name             = "NKMultipeer"
  s.version          = "0.2.2"
  s.summary          = "Testable p2p abstraction using the adapter pattern. Comes with MultipeerConnectivity support."
  s.homepage         = "https://github.com/nathankot/NKMultipeer"
  s.license          = 'MIT'
  s.author           = { "Nathan Kot" => "nk@nathankot.com" }
  s.source           = { :git => "https://github.com/nathankot/NKMultipeer.git", :tag => s.version.to_s }

  s.platform     = :ios
  s.ios.deployment_target = "8.0"
  s.requires_arc = true

  s.source_files = 'NKMultipeer/**/*'
  s.resource_bundles = {}

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'MultipeerConnectivity'
  s.dependency 'RxSwift', '~> 1.8'
end
