module R10K
  module Action
    module Deploy
      module DeployHelpers

        # Ensure that a config file has been found (and presumably loaded) and exit
        # with a helpful error if it hasn't.
        #
        # @raise [SystemExit] If no config file was loaded
        def expect_config!
          if @config.nil?
            logger.fatal(_("No configuration file given, no config file found in current directory, and no global config present"))
            exit(8)
          end
        end

        # Check to see if the deploy write_lock setting has been set, and log the lock message
        # and exit if it has been set.
        #
        # @param config [Hash] The r10k config hash
        #
        # @raise [SystemExit] if the deploy write_lock setting has been set
        def check_write_lock!(config)
          write_lock = config.fetch(:deploy, {})[:write_lock]
          if write_lock
            logger.fatal(_("Making changes to deployed environments has been administratively disabled."))
            logger.fatal(_("Reason: %{write_lock}") % {write_lock: write_lock})
            exit(16)
          end
        end

        # Record the time and SHA of the last code deployment into r10k-deploy json file.
        #
        # @param environment [R10K::Environment] The environment where the r10k-deploy json file lives
        # @param started_at [Time] The time at which the modules deployment started
        # @param success [Boolean] The status of modules deployment
        def write_environment_info!(environment, started_at, success)
          module_deploys = []
          begin
            environment.modules.each do |mod|
              name = mod.name
              version = mod.version
              sha = mod.repo.head rescue nil
              module_deploys.push({:name => name, :version => version, :sha => sha})
            end
          rescue
            logger.debug("Unable to get environment module deploy data for .r10k-deploy.json at #{environment.path}")
          end

          File.open("#{environment.path}/.r10k-deploy.json", 'w') do |f|
            deploy_info = environment.info.merge({
                                                     :started_at => started_at,
                                                     :finished_at => Time.new,
                                                     :deploy_success => success,
                                                     :module_deploys => module_deploys,
                                                 })

            f.puts(JSON.pretty_generate(deploy_info))
          end
        end
      end
    end
  end
end
