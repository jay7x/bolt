# frozen_string_literal: true

##############################################################
## DO NOT EDIT THIS FILE                                    ##
## Use /etc/puppetlabs/bolt-server/conf.d/bolt-server.conf  ##
## to configure the sinatra server                          ##
##############################################################

require 'bolt_ext/server'
require 'bolt_ext/server_acl'
require 'bolt_ext/server_config'
require 'bolt/logger'

Bolt::Logger.initialize_logging

config = if ENV['BOLT_SERVER_CONF']
           TransportConfig.new(ENV['BOLT_SERVER_CONF'])
         elsif ENV['RACK_ENV'] == 'test'
           TransportConfig.new(File.join(__dir__, 'spec', 'fixtures', 'configs', 'required-bolt-server.conf'))
         else
           TransportConfig.new
         end

Logging.logger[:root].add_appenders Logging.appenders.stderr(
  'console',
  layout: Bolt::Logger.default_layout,
  level: config.loglevel
)

if config.logfile
  stdout_redirect config.logfile, config.logfile, true
end

# TODO: use ssl_bind
bind_addr = +"ssl://#{config.host}:#{config.port}?"
bind_addr << "cert=#{config.ssl_cert}"
bind_addr << "&key=#{config.ssl_key}"
bind_addr << "&ca=#{config.ssl_ca_cert}"
bind_addr << "&verify_mode=force_peer"
bind_addr << "&ssl_cipher_filter=#{config.ssl_cipher_suites.join(':')}"
bind bind_addr

threads 0, config.concurrency

impl = TransportAPI.new
unless config.whitelist.nil?
  impl = TransportACL.new(impl, config.whitelist)
end

app impl
