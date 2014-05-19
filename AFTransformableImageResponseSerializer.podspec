Pod::Spec.new do |s|
  s.name         = 'AFTransformableImageResponseSerializer'
  s.version      = '1.0.0'
  s.homepage     = 'https://github.com/marchisfy/'
  s.authors      = {'lvjg' => 'lvjg0304@163.com'}
  s.summary      = 'Extension for AFNetworking.'

# Source Info
  s.platform     =  :ios, '6.0'
  s.source       =  {:git => 'https://github.com/marchisfy/AFTransformableImageResponseSerializer.git'}
  s.source_files = 'AFTransformableImageResponseSerializer/*.{h,m}'
  
  s.requires_arc = true
  
# Pod Dependencies
  s.dependencies =	pod "AFNetworking"

end