class OmniQuery::Subquery
  attr_reader :subquery_string, :original_sql, :connection_name, :table, :omni_query

  # @param subquery_string [String]
  # @param omni_query [OmniQuery]
  def initialize(subquery_string, omni_query)
    @subquery_string = subquery_string
    @original_sql = subquery_match[:sql]
    @connection_name = subquery_match[:connection_name]
    @table = subquery_match[:table]
    @omni_query = omni_query
  end

  # @return [MatchData]
  def subquery_match
    @subquery_match ||= subquery_string.match(/\((?<sql>.*?)\) (?:as )?(?<connection_name>\w+)__(?<table>\w+)/m)
  end

  # Within the SQL, are there any comments that are references to results from other subqueries?
  #
  # @return [Array<String>]
  def result_references
    original_sql.scan(/\/\* ([\w\s]*?)(\w+|\*)\.(\w+) \*\//)
  end

  # @return [Sequel::JDBC::Database]
  def connection
    omni_query.connection_pool.find(connection_name)
  end

  # @return [Sequel::JDBC::Postgres::Dataset]
  def dataset
    @dataset ||= connection[sql]
  end

  # original_sql is what the user gave us, but if there are references to
  # external results, we need to substitute those
  #
  # @return [String]
  def sql
    return original_sql unless result_references.any?

    result_references.dup.each_with_object(original_sql.dup) do |(options, table, column), final_sql|
      final_sql.gsub!("/* #{options}#{table}.#{column} */", result_values(options, table, column))
    end
  end

  # @param options [String]
  # @param table [String]
  # @param column [String]
  # @return [String]
  def result_values(options, table, column)
    values = results_for(table, column)
    return 'null' if values.empty? && options.include?('nullable')

    values.uniq! unless options.include?('nonunique')
    options.include?('unquoted') ? values.join(',') : "'#{values.join("','")}'"
  end

  # @param table [String]
  # @param column [String]
  def results_for(table, column)
    return all_results(column) if table == '*'

    omni_query.subquery_find(table).results.map { |result| result[column.to_sym] }
  end

  # @param column [String]
  def all_results(column)
    omni_query.subqueries.flat_map do |subquery|
      next if subquery == self
      next unless subquery.results.first.key? column.to_sym

      subquery.results.map { |result| result[column.to_sym] }
    end.compact
  end

  # @return [Array<Hash>]
  def results
    @results ||= dataset.to_a
  end
end