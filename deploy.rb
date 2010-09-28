require "bundler/capistrano"

set :remote_host, "server.manualdesign.no" unless variables.has_key?(:remote_host)
set :remote_user, "rails" unless variables.has_key?(:remote_user)

set :runner,      remote_user
set :user,        remote_user
set :use_sudo,    false
set :deploy_to,   "/var/www/#{application}" unless variables.has_key?(:deploy_to) && deploy_to != "/u/apps/#{application}"
set :web_server,  :apache2

set :scm,                   "git"
set :repository,            "rails@manualdesign.no:~/git/sites/#{application}.git"
set :deploy_via,            :remote_cache
set :git_enable_submodules, 1

set :perform_verify_migrations, true
set :flush_cache,       true
set :reindex_sphinx,    true

set :monit_delayed_job, "#{application}_delayed_job"
set :monit_sphinx,      "#{application}_sphinx"

role :web, remote_host
role :app, remote_host
role :db,  remote_host, :primary => true

desc "Run rake task (specified as TASK environment variable)"
task :rake_task, :roles => :app do
	if ENV['TASK']
        run "cd #{deploy_to}/#{current_dir} && rake #{ENV['TASK']} RAILS_ENV=production"
	else
		puts "Please specify a command to execute on the remote servers (via the COMMAND environment variable)"
	end
end

desc "Quick deploy, do not clean cache and reindex Sphinx"
task :quick, :roles => [:web] do
	set :perform_verify_migrations, false
	set :flush_cache,       false
	set :reindex_sphinx,    false
end

namespace :deploy do

	desc "Setup, configure the web server and deploy the application"
	task :cold, :roles => [:web] do
		sudo "echo \"Include #{current_path}/config/apache.conf\" > /etc/apache2/sites-available/#{application}"
		sudo "a2ensite #{application}"
		run "cd #{deploy_to}/#{current_dir} && rake db:create RAILS_ENV=production"
	end

	desc "Restart application"
	task :restart, :roles => :app do
		run "touch #{current_path}/tmp/restart.txt"
	end

	desc "Reload webserver"
	task :reload_webserver, :roles => [:web] do
	    sudo "/etc/init.d/#{web_server} reload"
	end

	desc "Update plugin migrations"
	task :fix_plugin_migrations, :roles => [:db] do
		run "cd #{release_path} && rake pages:update:fix_plugin_migrations RAILS_ENV=production --trace"
	end
	
	desc "Ensure binary objects store"
	task :ensure_binary_objects, :roles => [:web] do
		run "mkdir -p #{deploy_to}/#{shared_dir}/binary-objects"
		run "ln -s #{deploy_to}/#{shared_dir}/binary-objects #{release_path}/db/binary-objects"
	end
	
	desc "Setup services"
	task :services, :roles => [:web] do
	end
	after 'deploy:services', 'sphinx:configure'
	after 'deploy:services', 'sphinx:index'
	after 'deploy:services', 'monit:configure'
	after 'deploy:services', 'monit:restart'
	
end

namespace :delayed_job do
	desc "Start delayed_job process" 
	task :start, :roles => :app do
		run "sudo monit start #{monit_delayed_job}"
	end

	desc "Stop delayed_job process" 
	task :stop, :roles => :app do
		run "sudo monit stop #{monit_delayed_job}"
	end

	desc "Restart delayed_job process" 
	task :restart, :roles => :app do
		run "sudo monit restart #{monit_delayed_job}"
	end
end


namespace :pages do

	desc "Verify migrations"
	task :verify_migrations, :roles => [:web, :app, :db] do
		if perform_verify_migrations
			migration_status = `rake -s pages:migration_status`
			current, plugin = (migration_status.split("\n").select{|l| l =~ /pages:/ }.first.match(/([\d]+\/[\d]+)/)[1] rescue "0/xx").split("/")
			unless current == plugin
				puts "================================================================================"
				puts "MIGRATIONS MISMATCH!"
				puts migration_status
				puts "\nRun the following commands to fix:"
				puts "\nrake pages:update\nrake db:migrate\ngit commit -a -m \"Fixed migrations\"\ncap deploy:migrations"
				puts
				exit
			end
		end
	end

	desc "Create shared directories"
	task :create_shared_dirs, :roles => [:web,:app] do
		run "mkdir -p #{deploy_to}/#{shared_dir}/cache"
		run "mkdir -p #{deploy_to}/#{shared_dir}/public_cache"
		run "mkdir -p #{deploy_to}/#{shared_dir}/sockets"
		run "mkdir -p #{deploy_to}/#{shared_dir}/sessions"
		run "mkdir -p #{deploy_to}/#{shared_dir}/index"
		run "mkdir -p #{deploy_to}/#{shared_dir}/sphinx"
		run "mkdir -p #{deploy_to}/#{shared_dir}/binary-objects"
	end

	desc "Fix permissions"
	task :fix_permissions, :roles => [:web, :app] do
		run "chmod -R a+x #{deploy_to}/#{current_dir}/script/*"
		run "chmod a+x    #{deploy_to}/#{current_dir}/public/dispatch.*"
		run "chmod a+rwx  #{deploy_to}/#{current_dir}/public"
		run "chmod a+rw   #{deploy_to}/#{current_dir}/public/plugin_assets"
	end

	desc "Create symlinks"
	task :create_symlinks, :roles => [:web,:app] do
		run "ln -s #{deploy_to}/#{shared_dir}/cache #{deploy_to}/#{current_dir}/tmp/cache"
		run "ln -s #{deploy_to}/#{shared_dir}/sockets #{deploy_to}/#{current_dir}/tmp/sockets"
		run "ln -s #{deploy_to}/#{shared_dir}/sessions #{deploy_to}/#{current_dir}/tmp/sessions"
		run "ln -s #{deploy_to}/#{shared_dir}/index #{deploy_to}/#{current_dir}/index"
		run "ln -s #{deploy_to}/#{shared_dir}/sphinx #{deploy_to}/#{current_dir}/db/sphinx"
		run "ln -s #{deploy_to}/#{shared_dir}/public_cache #{deploy_to}/#{current_dir}/public/cache"
	end

end

namespace :sphinx do
	desc "Rebuild Sphinx"
	task :rebuild do
        run "cd #{deploy_to}/#{current_dir} && rake ts:in RAILS_ENV=production"
		run "sudo monit restart #{monit_sphinx}"
	end
	desc "Configure Sphinx"
	task :configure do
        run "cd #{deploy_to}/#{current_dir} && rake ts:conf RAILS_ENV=production"
	end
	desc "(Re)index Sphinx"
	task :index do
        run "cd #{deploy_to}/#{current_dir} && rake ts:in RAILS_ENV=production"
	end
	desc "Start Sphinx"
	task :start do
		run "sudo monit start #{monit_sphinx}"
	end
	desc "Stop Sphinx"
	task :stop do
		run "sudo monit stop #{monit_sphinx}"
	end
	desc "Restart Sphinx"
	task :restart do
		run "sudo monit restart #{monit_sphinx}"
	end
	desc "Do not reindex Sphinx"
	task :skip_reindex do
		set :reindex_sphinx, false
	end
end

namespace :monit do
	desc "Reconfigure Monit"
	task :configure do
		run "pages_console monitrc > /etc/monit.d/pages && echo 'Monit configured'"
	end
	desc "Start Monit"
	task :start do
		sudo "/etc/init.d/monit start"
	end
	desc "Stop Monit"
	task :stop do
		sudo "/etc/init.d/monit stop"
	end
	desc "Restart Monit"
	task :restart do
		sudo "/etc/init.d/monit restart"
	end
	desc "Check Monit config syntax"
	task :syntax do
		sudo "/etc/init.d/monit syntax"
	end
	desc "Show Monit status"
	task :status do
		run "sudo monit status"
	end
end

namespace :cache do
	desc "Do not flush the page cache on reload"
	task :keep do
	    set :flush_cache, false
	end

	desc "Flush the page cache"
	task :flush, :roles => :app do
	    if flush_cache
	        run "cd #{deploy_to}/#{current_dir} && rake pages:cache:sweep RAILS_ENV=production"
	    end
	end
end

namespace :log do
	namespace :tail do
		desc "Tail production log"
		task :production, :roles => :app do
			run "tail -f #{shared_path}/log/production.log" do |channel, stream, data|
				puts  # for an extra line break before the host name
				puts "==== #{channel[:host]} ====\n#{data}" 
				break if stream == :err    
			end
		end

		desc "Tail delayed_job log"
		task :delayed_job, :roles => :app do
			run "tail -f #{shared_path}/log/delayed_job.log" do |channel, stream, data|
				puts  # for an extra line break before the host name
				puts "==== #{channel[:host]} ====\n#{data}" 
				break if stream == :err    
			end
		end
	end
end

#before "deploy", "pages:verify_migrations"

after "deploy:setup",           "pages:create_shared_dirs"
#after "deploy:symlink",         "pages:fix_permissions"
after "deploy:symlink",         "pages:create_symlinks"
#after "deploy:restart",   "sphinx:index"
after "deploy:restart",         "cache:flush"
before "deploy:migrate",        "deploy:fix_plugin_migrations"
after "deploy:finalize_update", "deploy:ensure_binary_objects"

# Sphinx
after "deploy:symlink", "sphinx:configure"

before "deploy:cold", "deploy:setup"
before "deploy:cold", "deploy"
after "deploy:cold", "deploy:reload_webserver"
after "deploy:cold", "sphinx:start"

after "deploy:start", "delayed_job:start" 
after "deploy:stop", "delayed_job:stop" 
after "deploy:restart", "delayed_job:restart" 



