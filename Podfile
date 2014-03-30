platform :ios, '7.0'

xcodeproj 'Cloud66', 'App Store' => :release, 'Ad Hoc' => :release

pod 'AFNetworking', '~> 2.2.1'
pod 'CocoaLumberjack', '~> 1.6.5', :inhibit_warnings => true
pod 'CSNotificationView', '~> 0.3.5'
pod 'FormatterKit/TimeIntervalFormatter', '~> 1.4.2'
pod 'GROAuth2SessionManager', '~> 0.2.2'
pod 'HockeySDK', '~> 3.5.4', :inhibit_warnings => true
pod 'Mixpanel', '~> 2.0.5'

post_install do | installer |
    require 'fileutils'
    FileUtils.cp_r('Pods/Pods-Acknowledgements.plist', 'Cloud66/Settings.bundle/Acknowledgements.plist', :remove_destination => true)
end
