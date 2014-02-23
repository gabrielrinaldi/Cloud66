platform :ios, '7.0'

xcodeproj 'Cloud66', 'App Store' => :release, 'Ad Hoc' => :release

pod 'CocoaLumberjack', '~> 1.6.2', :inhibit_warnings => true
pod 'CSNotificationView', '~> 0.3'
pod 'FormatterKit/TimeIntervalFormatter', '~> 1.3.0'
pod 'GROAuth2SessionManager', '~> 0.1.4'
pod 'HockeySDK', '~> 3.5.0', :inhibit_warnings => true
pod 'Mixpanel', '~> 2.0.4'

post_install do | installer |
    require 'fileutils'
    FileUtils.cp_r('Pods/Pods-Acknowledgements.plist', 'Cloud66/Settings.bundle/Acknowledgements.plist', :remove_destination => true)
end
