# use this for local installs
SOURCE=ENV['SOURCE'] || 'http://github.com/kelliott/strappy/raw/golden'

def file_append(file, data)
  File.open(file, 'a') {|f| f.write(data) }
end

def file_inject(file_name, sentinel, string, before_after=:after)
  gsub_file file_name, /(#{Regexp.escape(sentinel)})/mi do |match|
    if :after == before_after
      "#{match}\n#{string}"
    else
      "#{string}\n#{match}"
    end
  end
end

# Git
file '.gitignore', open("#{SOURCE}/gitignore").read
git :init
git :add => '.gitignore'
run 'rm -f public/images/rails.png'
run 'cp config/database.yml config/database.template.yml'
git :add => "."
git :commit => "-a -m 'Initial commit'"

# Install Gems
gem 'config_reader'
gem 'mislav-will_paginate', :lib => false
gem 'capistrano'
gem 'capistrano-ext', :lib => false
gem 'haml'
gem 'authlogic'
gem 'norman-friendly_id', :lib => false
gem 'cucumber', :lib => false
gem 'rspec', :lib => false
gem 'rspec-rails', :lib => false
gem 'rcov', :lib => false
gem 'webrat', :lib => false
gem 'ZenTest', :lib => false
rake('gems:install', :sudo => true)
git :add => "."
git :commit => "-a -m 'Added Gems'"


# Hamlify the project
run 'echo N\n | haml --rails .'
run 'mkdir -p public/stylesheets/sass'
%w(
  application
  print
  _colors
  _common
  _flash
  _grid
  _helpers
  _reset
  _typography
).each do |file|
  file "public/stylesheets/sass/#{file}.sass",
    open("#{SOURCE}/public/stylesheets/sass/#{file}.sass").read
end
git :add => "."
git :commit => "-a -m 'Added Haml and Sass stylesheets'"

# install haml rake tasks
rakefile 'haml.rake', open("#{SOURCE}/lib/tasks/haml.rake").read

# RSpec / Cucumber
generate 'rspec'
generate 'cucumber'
file 'spec/rcov.opts', open("#{SOURCE}/spec/rcov.opts").read
file_append('spec/spec_helper.rb', open("#{SOURCE}/spec/helpers.rb").read)
git :add => "."
git :commit => "-a -m 'Generated RSpec and Cucumber'"

# SiteConfig
file 'config/site.yml', open("#{SOURCE}/config/site.yml").read
lib 'site_config.rb', open("#{SOURCE}/lib/site_config.rb").read
git :add => "."
git :commit => "-a -m 'Added SiteConfig'"

# CC.rb
rakefile('cruise.rake') { open("#{SOURCE}/lib/tasks/cruise.rake").read }
git :add => "."
git :commit => "-a -m 'Added cruise rake task'"

# Capistrano
capify!
file 'config/deploy.rb', open("#{SOURCE}/config/deploy.rb").read

%w( alpha production staging ).each do |env|
  file "config/deploy/#{env}.rb", "set :rails_env, \"#{env}\""
end

inside('config/environments') do
  run 'cp development.rb alpha.rb'
  run 'cp development.rb staging.rb'
end

git :add => "."
git :commit => "-a -m 'Added Capistrano config'"

# Blackbird
run 'mkdir -p public/blackbird'
file 'public/blackbird/blackbird.js',
  open('http://blackbirdjs.googlecode.com/svn/trunk/blackbird.js').read
file 'public/blackbird/blackbird.css',
  open('http://blackbirdjs.googlecode.com/svn/trunk/blackbird.css').read
file 'public/blackbird/blackbird.png',
  open('http://blackbirdjs.googlecode.com/svn/trunk/blackbird.png').read

git :add => "."
git :commit => "-a -m 'Added Blackbird'"

# uberkit
plugin 'uberkit', :git => 'git://github.com/mbleigh/uberkit.git'

git :add => "."
git :commit => "-a -m 'Added uberkit plugin'"

# add bundle-fu
plugin 'bundle-fu',
  :git => 'git://github.com/timcharper/bundle-fu.git'

git :add => "."
git :commit => "-a -m 'Added Haml and Sass stylesheets'"

# Setup Authlogic
# rails gets cranky when this isn't included in the config
generate 'session user_session'

# allow login by login or pass
file_inject('/app/models/user_session.rb',
  "class UserSession < Authlogic::Session::Base",
  "  find_by_login_method :find_by_login_or_email",
  :after
)

generate 'rspec_controller user_sessions'
generate 'scaffold user'

# get rid of the generated templates
Dir.glob('app/views/users/*.erb').each do |file|
  run "rm #{file}"
end
run "rm app/views/layouts/users.html.erb"

generate 'controller password_reset'

route "map.logout '/logout', :controller => 'user_sessions', :action => 'destroy'"
route "map.login '/login', :controller => 'user_sessions', :action => 'new'"
route "map.signup '/signup', :controller => 'users', :action => 'new'"
route 'map.resource :user_session'
route 'map.resource :account, :controller => "users"'
route 'map.resources :password_reset'

# migrations
file Dir.glob('db/migrate/*_create_users.rb').first,
  open("#{SOURCE}/db/migrate/create_users.rb").read

# models
%w( user notifier ).each do |name|
  file "app/models/#{name}.rb",
    open("#{SOURCE}/app/models/#{name}.rb").read
end

# controllers
%w( user_sessions password_reset users ).each do |name|
  file "app/controllers/#{name}_controller.rb",
    open("#{SOURCE}/app/controllers/#{name}_controller.rb").read
end

# views
%w(
  notifier/password_reset_instructions.erb
  password_reset/edit.html.haml
  password_reset/new.html.haml
  user_sessions/new.html.haml
  users/_form.haml
  users/edit.html.haml
  users/new.html.haml
  users/show.html.haml
).each do |name|
  file "app/views/#{name}", open("#{SOURCE}/app/views/#{name}").read
end

# testing goodies
file_inject('/spec/spec_helper.rb',
  "require 'spec/rails'",
  "require 'authlogic/test_case'\n",
  :after
)

# specs
run 'mkdir -p spec/fixtures'

%w(
  fixtures/users.yml
  helpers/application_helper_spec.rb
  controllers/password_reset_controller_spec.rb
  controllers/user_sessions_controller_spec.rb
  controllers/users_controller_spec.rb
  views/home/index.html.haml_spec.rb
).each do |name|
  file "spec/#{name}", open("#{SOURCE}/spec/#{name}").read
end

route "map.forgot_password '/forgot_password',
  :controller => 'password_reset',
  :action => 'new'"

rake('db:migrate')
git :add => "."
git :commit => "-a -m 'Added Authlogic'"

# Add ApplicationController
file 'app/controllers/application_controller.rb',
  open("#{SOURCE}/app/controllers/application_controller.rb").read

# Add in the :xhr mime type
file_inject('/config/initializers/mime_types.rb',
  '# Be sure to restart your server when you modify this file.',
  'Mime::Type.register_alias "text/html", :xhr',
  :after
)

git :add => "."
git :commit => "-a -m 'Added ApplicationController'"

# Add ApplicationHelper
file 'app/helpers/application_helper.rb',
  open("#{SOURCE}/app/helpers/application_helper.rb").read
git :add => "."
git :commit => "-a -m 'Added ApplicationHelper'"

# Add Layout
%w(
  application.html.erb
).each do |name|
  file "app/views/layouts/#{name}",
    open("#{SOURCE}/app/views/layouts/#{name}").read
end

git :add => "."
git :commit => "-a -m 'Added Layout and templates'"

# setup admin section
%w(
  app/controllers/admin
  app/views/admin/base
  spec/controllers/admin
  app/helpers/admin
).each do |dir|
  run "mkdir -p #{dir}"
end

# Remove index.html and add HomeController
git :rm => 'public/index.html'
generate :rspec_controller, 'home'
route "map.root :controller => 'home'"

file 'app/views/home/index.html.haml',
  open("#{SOURCE}/app/views/home/index.html.haml").read

file "app/helpers/home_helper.rb",
  open("#{SOURCE}/app/helpers/home_helper.rb").read

file "spec/views/home/index.html.haml_spec.rb",
  open("#{SOURCE}/spec/views/home/index.html.haml_spec.rb").read

file "spec/controllers/home_controller_spec.rb",
  open("#{SOURCE}/spec/controllers/home_controller_spec.rb").read

git :add => "."
git :commit => "-a -m 'Removed index.html. Added HomeController'"

# Add ApplicationController
file 'app/controllers/application_controller.rb',
  open("#{SOURCE}/app/controllers/application_controller.rb").read

git :add => "."
git :commit => "-a -m 'Added ApplicationController'"

# update the readme
run 'rm README'
file 'README.textile', open("#{SOURCE}/README.textile").read
git :add => "."
git :commit => "-a -m 'Replaced README'"

# Add Action images
%w(
  add.png
  arrow_up_down.png
  delete.png
  pencil.png
  user_edit.png
).each do |name|
  file "public/images/#{name}",
    open("#{SOURCE}/public/images/#{name}").read
end

git :add => "."
git :commit => "-a -m 'Added Action images'"

puts "\n#{'*' * 80}\n\n"
puts "All done. Enjoy."
puts "\n#{'*' * 80}\n\n"
