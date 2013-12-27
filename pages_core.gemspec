# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "pages_core/version"

Gem::Specification.new do |s|
  s.name        = "pages_core"
  s.version     = PagesCore::VERSION
  s.authors     = ["Inge Jørgensen"]
  s.email       = ["inge@manualdesign.no"]
  s.homepage    = ""
  s.summary     = %q{Pages Core}
  s.description = %q{Pages Core}

  s.rubyforge_project = "."

  s.required_ruby_version = Gem::Requirement.new(">= 1.9.2")

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "rails", "~> 4.0.2"

  s.add_dependency 'bcrypt-ruby'
  s.add_dependency 'RedCloth', '~> 4.2.9'
  s.add_dependency 'daemon-spawn', '~> 0.2.0'
  s.add_dependency 'ruby-openid', '~> 2.2.3'
  s.add_dependency 'vector2d'
  s.add_dependency 'dynamic_image-pages', '>= 0.0.16'
  s.add_dependency 'actionpack-page_caching'

  # Default asset dependencies
  s.add_dependency 'sass-rails', '~> 4.0.0'
  s.add_dependency 'uglifier', '>= 1.3.0'
  s.add_dependency 'coffee-rails', '~> 4.0.0'
  s.add_dependency 'jquery-rails'
  s.add_dependency 'jbuilder', '~> 1.2'

  # Extra asset dependencies
  s.add_dependency 'jquery-ui-rails'
  s.add_dependency 'jquery-cookie-rails'
  s.add_dependency 'jcrop-rails'
  s.add_dependency 'underscore-rails'

  # ActiveRecord extensions
  s.add_dependency 'acts_as_list'

  # reCAPTCHA
  s.add_dependency 'recaptcha', '~> 0.3.5'

  # Delayed Job
  s.add_dependency 'delayed_job', '~> 4.0.0'
  s.add_dependency 'delayed_job_active_record', '~> 4.0.0'
  s.add_dependency 'daemons', '1.1.0'

  # Thinking Sphinx
  s.add_dependency 'thinking-sphinx', '~> 2.0.14' # 3.0 has a new API
  s.add_dependency 'ts-delayed-delta', '1.1.3'

  # Deployment
  s.add_dependency 'capistrano'
  s.add_dependency 'term-ansicolor'
end
