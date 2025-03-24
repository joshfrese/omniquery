#!jruby

VERSION = '1.2.0'
DEFAULT_CONNECTION_SETTINGS_FILE = 'omniquery_connection_settings.json'
$LOAD_PATH.unshift(File.expand_path('lib'))

require 'jdbc'
require 'jdbc/mysql'
require 'jdbc-postgresql'
require 'jdbc/sqlite3'
require 'jdbc/mssql'
require 'jdbc/mariadb'
require 'pry'
require 'json'
require 'sequel'
require 'csv'
require 'slop'

require 'omni_query'
require 'omni_query_subquery'
require 'omni_query_connection_pool'

opts = Slop.parse do |o|
  o.string '-s', '--connection_settings', 'path to the connection settings json file'
  o.string '-f', '--sql_file', 'path to the sql file to execute', required: true
  o.string '-c', '--csv', 'path to the csv file to create; will auto create if not specified'
  o.string '-l', '--sqlite', 'path to the sqlite file to create; will auto create if not specified'
  o.string '-o', '--final_sql', 'path to create the resulting sqlite query; optional'
  o.string '-db', '--dbeaver', 'path to dbeaver if using to open sqlite'
  o.string '-dbf', '--dbeaver_folder'
  o.bool '--nocsv', 'Option to prevent making a csv'
  o.bool '--pry', 'open pry to debug manually'
  o.on '--version', 'prints the version' do
    puts VERSION
    exit
  end
end

connection_settings_file = opts[:connection_settings] || DEFAULT_CONNECTION_SETTINGS_FILE

binding.pry if opts[:pry]

raise 'Connection Settings Not Specified or Found' unless File.exist?(connection_settings_file)
raise "Invalid SQL File: #{opts[:sql_file]}" unless File.exist?(opts[:sql_file])

connection_settings = JSON.load_file(connection_settings_file)

query = OmniQuery.new(connection_settings, opts)
query.results.count
File.write(opts[:final_sql], query.sql) if opts[:final_sql]
query.build_csv! unless opts[:nocsv]

exit unless opts[:dbeaver]

db_commands = [opts[:dbeaver], '-con', "driver=sqlite|database=#{File.expand_path(query.sqlite_filename)}|name=#{File.basename(query.sqlite_filename)}|openConsole=true"]
db_commands[2] += "|folder=#{opts[:dbeaver_folder]}" if opts[:dbeaver_folder]
db_commands += ['-f', opts[:final_sql]] if opts[:final_sql]

system(*db_commands)