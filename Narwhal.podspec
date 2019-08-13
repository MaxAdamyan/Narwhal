Pod::Spec.new do |rs|
  rs.name             = 'Narwhal'
  rs.version          = '1.0.0'
  rs.summary          = 'Shared logic for gg iOS applications'

  rs.homepage         = 'https://mirana.visualstudio.com/gg/_git/iOS.Narwhal'
  rs.license          = { :type => 'Copyright', :text => 'Copyright gg CJCS 2019' }
  rs.author           = { 'max' => 'max@team.gg' }
  rs.source           = { :git => 'https://mirana.visualstudio.com/gg/_git/iOS.Narwhal',
                          :branch => 'master' }

  rs.platform         = :ios, '9.0'
  rs.swift_version    = '5.0'
  
  rs.subspec 'HTTPService' do |s|
  	s.source_files    = 'Narwhal/HTTPService/*'
    s.dependency      'Alamofire', '~> 4.8'
    s.dependency      'ObjectMapper', '~> 3.4'
  end
end
