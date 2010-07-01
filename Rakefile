require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "authlogic_radius"
    gemspec.summary = "Extension of the Authlogic library adding RADIUS support."
    gemspec.description = <<-EOF
This is a simple gem to allow authentication against a RADIUS server

Mostly it is the product of a global replace of ldap with radius...
and a few RADIUS specific bits.
EOF
    gemspec.email = "langhorst@neb.com"
    gemspec.homepage = "http://github.com/bwlang/authlogic_radius"
    gemspec.authors = ["Brad Langhorst"]
    gemspec.add_dependency 'authlogic', ">=2.0"
    gemspec.add_dependency 'radiustar', ">=0.0.3"
    gemspec.files = Dir['lib/**/*.rb']
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end
