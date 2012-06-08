namespace :pages do

	desc "Fix migrations"
	task :fix_migrations, :roles => [:db] do
		run "cd #{release_path} && bundle exec rake pages:update:fix_migrations RAILS_ENV=production"
	end

	desc "Verify migrations"
	task :verify_migrations, :roles => [:web, :app, :db] do
		if perform_verify_migrations
			migration_status = `bundle exec rake -s pages:migration_status`
			current, plugin = (migration_status.split("\n").select{|l| l =~ /pages:/ }.first.match(/([\d]+\/[\d]+)/)[1] rescue "0/xx").split("/")
			unless current == plugin
				puts "================================================================================"
				puts "MIGRATIONS MISMATCH!"
				puts migration_status
				puts "\nRun the following commands to fix:"
				puts "\nbundle exec rake pages:update\nbundle exec rake db:migrate\ngit commit -a -m \"Fixed migrations\"\ncap deploy:migrations"
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
		run "ln -s #{deploy_to}/#{shared_dir}/cache #{release_path}/tmp/cache"
		run "ln -s #{deploy_to}/#{shared_dir}/sockets #{release_path}/tmp/sockets"
		run "ln -s #{deploy_to}/#{shared_dir}/sessions #{release_path}/tmp/sessions"
		run "ln -s #{deploy_to}/#{shared_dir}/index #{release_path}/index"
		run "ln -s #{deploy_to}/#{shared_dir}/sphinx #{release_path}/db/sphinx"
		run "ln -s #{deploy_to}/#{shared_dir}/public_cache #{release_path}/public/cache"
	end

end