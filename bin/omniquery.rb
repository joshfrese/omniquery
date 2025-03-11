#!jruby

VERSION = '1.0.0'
DEFAULT_CONNECTION_SETTINGS_FILE = 'omniquery_connection_settings.json'
$LOAD_PATH.unshift(File.expand_path('lib'))

require 'jdbc'
require 'jdbc/mysql'
require 'jdbc/postgresql'
require 'jdbc/sqlite3'
require 'jdbc/mssql'
require 'jdbc/mariadb'
require 'pry'
require 'json'
require 'sequel'
require 'csv'

require 'omni_query'
require 'omni_query_subquery'
require 'omni_query_connection_pool'

raise 'Connection Settings Not Found' unless File.exist?(DEFAULT_CONNECTION_SETTINGS_FILE)
raise 'You must specify a SQL file to execute' if ARGV[0].nil?
raise "Invalid SQL File: #{ARGV[0]}" unless File.exist?(ARGV[0])

connection_settings = JSON.load_file(DEFAULT_CONNECTION_SETTINGS_FILE)

OmniQuery.new(connection_settings, ARGV[0]).build_csv!