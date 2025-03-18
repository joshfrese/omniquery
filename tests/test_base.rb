#!jruby

$LOAD_PATH.unshift(File.expand_path('lib'))

require 'pry'
require 'json'
require 'sequel'
require 'csv'

require 'omni_query'
require 'omni_query_subquery'
require 'omni_query_connection_pool'

class OmniQueryTest
  attr_reader :query, :name

  def initialize(name)
    @name = name
    @query = OmniQuery.new({}, 'README.md')
    @test_count = 0
  end

  def method_missing(method, *args, &block)
    query.public_send(method, *args, &block) if query.respond_to?(method)
  end

  def query_string=(new_query_string)
    query.instance_variable_set('@query_string', new_query_string)
  end

  def expect(given, expected)
    return success(given, expected) if given == expected

    raise "#{name} - Test ##{@test_count += 1} FAIL: #{given} was expected to match #{expected}"
  end

  def success(given, expected)
    puts "#{name} - Test ##{@test_count += 1}: #{given} == #{expected}"
  end
end