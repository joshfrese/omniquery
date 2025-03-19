class OmniQuery
  attr_reader :opts, :query_string, :connection_pool, :sqlite_filename

  # @param connection_settings [Hash]
  # @param opts [Slop::Result]
  def initialize(connection_settings, opts)
    @opts = opts
    @query_string = File.read(opts[:sql_file])
    @connection_pool = OmniQuery::ConnectionPool.new(connection_settings)
    @sqlite_filename = opts[:sqlite] || File.basename(opts[:sql_file]).gsub(File.extname(opts[:sql_file]), "_#{datetime_stamp}.sqlite")
    File.delete(sqlite_filename) if File.exist? sqlite_filename
  end

  # @return [String]
  def datetime_stamp
    Time.now.utc.to_s.gsub(/[\:\-]+/,'').gsub(' UTC','').gsub(' ','_')
  end

  # This seems complicated. Originally it was regular expressions. I couldn't find a way in regexp
  # to match beginning and ending parenthesis within nested sets and only find their correct counterpart.
  # My basic examples worked fine with regexp, but more complicated nesting caused problems.
  #
  # @return [Array<String>]
  def subquery_strings(stack = [])
    query_string.chars.each_with_object([]).with_index do |(char, results), index|
      stack << index if char == '('
      next unless char == ')' && (start = stack.pop)
      match = query_string[index..].gsub(/[\n\r]+/,'').match(/^\)\s+(as\s+|)\w+__\w+/)
      results << query_string[start..index] + match.to_s[1..] if match
    end
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

  # @return [Array<Hash>]
  def results
    @results ||= sqlite[sql].to_a
  end

  def build_csv!
    filename = opts[:csv] || sqlite_filename.gsub('.sqlite','.csv')
    CSV.open(filename, 'w') do |csv_output|
      csv_output << results.first.keys
      results.each { |result| csv_output << result.values }
    end
    puts "Created #{filename} with #{results.count} results"
  end
end