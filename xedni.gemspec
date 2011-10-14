Gem::Specification.new do |s|
  s.name = 'xedni'
  s.description = 'Implemenets Xedni search'
  s.summary = 'Woo hoo'
  s.version = '1.0.2'
  s.authors = ['Cary FitzHugh']
  s.email = ['cary.fitzhugh@ziplist.com']
  s.homepage = 'http://github.com/caryfitzhugh/xedni'
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>= 1.9.0'

  s.require_paths = ["lib"]

  s.has_rdoc = false
  s.files = [
    'README',
    'lib/xedni.rb',
    'lib/xedni/common.lua',
    'lib/xedni/scripts.rb',
    'lib/xedni/scripts/create.lua',
    'lib/xedni/scripts/delete.lua',
    'lib/xedni/scripts/dump.lua',
    'lib/xedni/scripts/query.lua',
    'lib/xedni/scripts/read.lua',
    'lib/xedni/scripts/echo.lua',
    'test/test_helper.rb',
    'test/xedni_test.rb'
  ]
end
