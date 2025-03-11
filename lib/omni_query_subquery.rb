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
    original_sql.scan(/\/\* (\w+\.\w+) \*\//).flatten
  end

  # @return [Hash,Nil]
  def result_references_hash
    result_references.map { |ref| ref.split('.') }.to_h
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
    return original_sql unless result_references

    result_references_hash.each_with_object(original_sql) do |(table, column), final_sql|
      value_array = omni_query.subquery_find(table).results.map { |result| result[column.to_sym] }.uniq
      final_sql.gsub!("/* #{table}.#{column} */", "'#{value_array.join("','")}'")
    end
  end

  # @return [Array<Hash>]
  def results
    @results ||= dataset.to_a
  end
end