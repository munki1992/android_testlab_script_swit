lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/android_testlab_script_swit/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-android_testlab_script_swit'
  spec.version       = Fastlane::AndroidTestlabScriptSwit::VERSION
  spec.author        = '나비이쁜이'
  spec.email         = 'munkijung1992@gmail.com'

  spec.summary       = 'short'
  spec.homepage      = "https://github.com/munki1992/android_testlab_script_swit"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency('bundler')
  spec.add_development_dependency('fastlane', '>= 2.214.0')
  spec.add_development_dependency('pry')
  spec.add_development_dependency('rake')
  spec.add_development_dependency('rspec')
  spec.add_development_dependency('rspec_junit_formatter')
  spec.add_development_dependency('rubocop', '1.12.1')
  spec.add_development_dependency('rubocop-performance')
  spec.add_development_dependency('rubocop-require_tools')
  spec.add_development_dependency('simplecov')
end
