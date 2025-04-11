class ServerSettings
  class DatabaseConfig
    def self.slave_name(name, idx)
      name + "_slave#{idx}"
    end

    def self.replica_name(name, suffix, idx)
      "#{name}_#{suffix}#{idx}"
    end

    def self.generate_database_config(db_role, with_slave: true, replica_suffix: "replica")
      configuration = {}
      return configuration unless ServerSettings.databases

      ServerSettings.databases.each do |db|
        next unless db.config(db_role)

        role_db_config = db.config(db_role)
        stringify_keys!(role_db_config) if defined? Rails

        if db.name == "default"
          if defined? Rails
            configuration[Rails.env] = role_db_config
          else
            configuration.merge!(role_db_config)
          end
        elsif db.group
          configuration[db.group] ||= {}
          configuration[db.group][db.name] = role_db_config
        else
          configuration[db.name] = role_db_config
        end

        if with_slave && db.has_slave?
          db.config(:slaves).each.with_index(1) do |config, idx|
            # スレーブのバックアップホストは、マスターのバックアップホストと同じにする
            config[:host] = db.backup if db_role == :backup
            stringify_keys!(config) if defined? Rails
            configuration[slave_name(db.name, idx)] = config

            # AR6.1以降のDB分散機能の replica 向けの設定
            config = config.dup
            config[:replica] = true
            stringify_keys!(config) if defined? Rails
            configuration[replica_name(db.name, replica_suffix, idx)] = config
          end
        end
      end
      configuration
    end

    def self.stringify_keys!(config)
      config.keys.each { |key| config[key.to_s] = config.delete(key) }
    end
  end
end
