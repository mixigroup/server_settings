# -*- coding: utf-8 -*-
require 'yaml'
require 'erb'
require "server_settings/version"
require "server_settings/host"
require "server_settings/host_collection"
require "server_settings/role"
require "server_settings/role_db"
require "server_settings/database"
require "server_settings/database_config"
require "server_settings/railtie" if defined? Rails

class ServerSettings
  attr_accessor :roles

  ## Exceptions
  class DuplicateRole < StandardError; end

  def initialize
    @roles = {}
  end

  def << (role)
    raise DuplicateRole, "`#{role.name}' already defined" if @roles.has_key?(role.name)
    @roles[role.name] = role
  end

  def each
    @roles.each do |name, role|
      yield(name, role)
    end
  end

  def has_key?(role)
    @roles.has_key?(role)
  end

  def method_missing(name, *args, &block)
    key = name.to_s
    return nil  unless has_key? key
    @roles[key]
  end

  class << self

    def load_config(file)
      @loaded_files ||= {}
      load_from_yaml_erb(IO.read(file))
      @loaded_files[file] = File.mtime(file)
    end

    def load_config_dir(pattern)
      Dir.glob(pattern) do |file|
        load_config(file)
      end
    end

    def load_from_yaml(yaml)
      config = YAML.safe_load(yaml, permitted_classes: [Symbol], aliases: true)
      config.each do |role, config|
        instance << role_klass(config).new(role, config)
      end
    end

    def load_from_yaml_erb(yaml, erb_binding: binding)
      yaml =  ERB.new(yaml).result(erb_binding)
      load_from_yaml(yaml)
    end

    def reload
      @loaded_files.each do |file, updated_at|
        if File.mtime(file) > updated_at
          load_config(file)
        end
      end
    end

    def roles
      instance.roles
    end

    def each_role
      roles.each do |role, config|
        yield(role, config.hosts)
      end
    end

    def role_klass(config)
      if config.has_key?("hosts")
        Role
      else
        RoleDB
      end
    end

    def destroy
      @servers_config = nil
      @loaded_files = nil
    end

    private

    def instance
      return @servers_config if @servers_config
      @servers_config = self.new
      return @servers_config
    end

    def method_missing(name, *args, &block)
      instance.send(name, *args, &block)
    end
  end
end
