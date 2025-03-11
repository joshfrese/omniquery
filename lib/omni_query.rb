class OmniQuery
  attr_reader :query_file, :query_string, :connection_pool, :sqlite_filename

  # @param connection_settings [Hash]
  # @param query_file [String]
  def initialize(connection_settings, query_file)
    @query_file = query_file
    @query_string = File.read(query_file)
    @connection_pool = OmniQueryConnectionPool.new(connection_settings)
    @sqlite_filename = File.basename(query_file).gsub(File.extname(query_file), "_#{datetime_stamp}.sqlite")
  end

  # @return [String]
  def datetime_stamp
    Time.now.utc.to_s.gsub(/[\:\-]+/,'').gsub(' UTC','').gsub(' ','_')
  end

  # @return [Array<String>]
  def subquery_strings
    query_string.scan(/\(.*?\) (?:as )?\w+__\w+/m)
  end

  # @return [Array<OmniQuery::Subquery>]
  def subqueries
    @subqueries ||= subquery_strings.map { |subquery_string| OmniQuery::Subquery.new(subquery_string, self) }
  end

  # @return [OmniQuery::Subquery,Nil]
  def subquery_find(name)
    subqueries.find { |q| q.table == name }
  end

  # @return [Sequel::JDBC::Database]
  def sqlite
    @sqlite ||= Sequel.connect("jdbc:sqlite:#{sqlite_filename}").tap { |obj| build_sqlite(obj) }
  end

  # @param sqlite_object [Sequel::JDBC::Database]
  def build_sqlite(sqlite_object)
    subqueries.each do |subquery|
      sqlite_object.create_table subquery.table.to_sym do
        subquery.dataset.columns.each do |column|
          column column, String
        end
      end
      sqlite_object[subquery.table.to_sym].multi_insert(subquery.results)
      puts "Created local table #{subquery.table} from #{subquery.connection_name}"
    end
    puts "Created #{sqlite_filename} with results from #{subqueries.count} subqueries"
  end

  # @return [String]
  def sql
    subqueries.each_with_object(query_string.dup) do |subquery, final_query|
      final_query.gsub!(subquery.subquery_string, subquery.table)
    end
  end

  # @return [String]
  def csv_filename
    sqlite_filename.gsub('.sqlite','.csv')
  end

  # @return [Array<Hash>]
  def results
    @results ||= sqlite[sql].to_a
  end

  def build_csv!
    CSV.open(csv_filename, 'w') do |csv_output|
      csv_output << results.first.keys
      results.each { |result| csv_output << result.values }
    end
    puts "Created #{csv_filename} with #{results.count} results after running sqlite query"
  end
end