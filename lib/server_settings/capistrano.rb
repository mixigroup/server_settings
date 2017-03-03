require 'server_settings'

module Capistrano
  module ServersGroup
    def self.extend(configuration)
      configuration.load do
        Capistrano::Configuration.instance.load do
          def load_servers(pattern)
            ServerSettings.load_config_dir(pattern)
            ServerSettings.each_role do |role, hosts|
              if hosts.class == ::ServerSettings::HostCollection && hosts.role_config["%no_release"]
                role role.to_sym, *hosts.map(&:host), :no_release => true
              else
                role role.to_sym, *hosts.map(&:host)
              end
            end
          end
        end
      end
    end
  end
end

if Capistrano::Configuration.instance
  Capistrano::ServersGroup.extend(Capistrano::Configuration.instance)
end

