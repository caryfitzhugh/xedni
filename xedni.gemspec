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
    'lib/xedni/filter.rb',
    'lib/xedni/record.rb',
    'lib/xedni.rb',
    'test/filter_test.rb',
    'test/records_test.rb',
    'test/test_helper.rb',
    'test/xedni_test.rb'
  ]
end
