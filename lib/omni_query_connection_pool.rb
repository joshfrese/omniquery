class OmniQueryConnectionPool
  attr_reader :connection_settings, :connections

  def initialize(connection_settings)
    @connection_settings = connection_settings
    @connections = {}
  end

  # @param connection_name [String]
  # @return [Sequel::JDBC::Database]
  def find(connection_name)
    return connections[connection_name] if connections[connection_name]

    @connections[connection_name] = connect(connection_name)
  end

  # @param connection_name [String]
  # @return [Sequel::JDBC::Database]
  def connect(connection_name)
    raise "Invalid connection reference: #{connection_name}" unless (settings = connection_settings[connection_name])

    puts "Connecting to #{connection_name}"
    Sequel.connect(settings['connection'], user: settings['user'], password: settings['password'])
  end
end