Gem::Specification.new do |s| 
  s.name    = 'sortable'
  s.version = '1.0.6'
  s.date    = '2009-07-06'
  
  s.summary     = 'Allows you to sort ActiveRecord items in multiple lists with multiple scopes'
  s.description = 'Allows you to sort ActiveRecord items in multiple lists with multiple scopes'
  
  s.author   = 'Sean Huber'
  s.email    = 'shuber@huberry.com'
  s.homepage = 'http://github.com/shuber/sortable'
  
  s.has_rdoc = false
  s.rdoc_options = ['--line-numbers', '--inline-source', '--main', 'README.rdoc']
  
  s.require_paths = ['lib']
  
  s.files = %w(
    CHANGELOG
    init.rb
    lib/sortable.rb
    MIT-LICENSE
    Rakefile
    README.rdoc
  )
  
  s.test_files = %w(
    test/sortable_test.rb
  )
end