require 'deface'

module ForemanSoftlayer
  class Engine < ::Rails::Engine
    engine_name 'foreman_softlayer'

    config.autoload_paths += Dir["#{config.root}/app/controllers/concerns"]
    config.autoload_paths += Dir["#{config.root}/app/helpers/concerns"]
    config.autoload_paths += Dir["#{config.root}/app/models/concerns"]
    config.autoload_paths += Dir["#{config.root}/app/overrides"]

    # Add any db migrations
    initializer 'foreman_softlayer.load_app_instance_data' do |app|
      app.config.paths['db/migrate'] += ForemanSoftlayer::Engine.paths['db/migrate'].existent
    end

    initializer 'foreman_softlayer.register_plugin', after: :finisher_hook do |_app|
      Foreman::Plugin.register :foreman_softlayer do
        requires_foreman '>= 1.8'

        # This is a compute resource
        compute_resource ForemanSoftlayer::Softlayer

        # Add permissions
        #security_block :foreman_softlayer do
        #  permission :view_foreman_softlayer, :'foreman_softlayer/hosts' => [:new_action]
        #end

        # Add a new role called 'Discovery' if it doesn't exist
        #role 'ForemanSoftlayer', [:view_foreman_softlayer]

        # add menu entry
        #menu :top_menu, :template,
        #     url_hash: { controller: :'foreman_softlayer/hosts', action: :new_action },
        #     caption: 'ForemanSoftlayer',
        #     parent: :hosts_menu,
        #     after: :hosts

        # add dashboard widget
        #widget 'foreman_softlayer_widget', name: N_('Foreman plugin template widget'), sizex: 4, sizey: 1
      end
    end

    # Precompile any JS or CSS files under app/assets/
    # If requiring files from each other, list them explicitly here to avoid precompiling the same
    # content twice.
    assets_to_precompile =
      Dir.chdir(root) do
        Dir['app/assets/javascripts/**/*', 'app/assets/stylesheets/**/*'].map do |f|
          f.split(File::SEPARATOR, 4).last
        end
      end
    initializer 'foreman_softlayer.assets.precompile' do |app|
      app.config.assets.precompile += assets_to_precompile
    end
    initializer 'foreman_softlayer.configure_assets', group: :assets do
      SETTINGS[:foreman_softlayer] = { assets: { precompile: assets_to_precompile } }
    end

    # Include concerns in this config.to_prepare block
    #config.to_prepare do
    #  begin
    #    Host::Managed.send(:include, ForemanSoftlayer::HostExtensions)
    #    HostsHelper.send(:include, ForemanSoftlayer::HostsHelperExtensions)
    #  rescue => e
    #    Rails.logger.warn "ForemanSoftlayer: skipping engine hook (#{e})"
    #  end
    #end

    #rake_tasks do
    #  Rake::Task['db:seed'].enhance do
    #    ForemanSoftlayer::Engine.load_seed
    #  end
    #end

    initializer 'foreman_softlayer.register_gettext', after: :load_config_initializers do |_app|
      locale_dir = File.join(File.expand_path('../../..', __FILE__), 'locale')
      locale_domain = 'foreman_softlayer'
      Foreman::Gettext::Support.add_text_domain locale_domain, locale_dir
    end

    # Load fog extensions
    require 'fog/softlayer'
    require 'fog/softlayer/models/compute/server'
    require 'fog/softlayer/models/compute/servers'
    require File.expand_path('../../../app/models/concerns/fog_extensions/softlayer/server', __FILE__)
    require File.expand_path('../../../app/models/concerns/fog_extensions/softlayer/servers', __FILE__)
    Fog::Compute::Softlayer::Server.send(:include, FogExtensions::Softlayer::Server)
    Fog::Compute::Softlayer::Servers.send(:include, FogExtensions::Softlayer::Servers)
  end
end
