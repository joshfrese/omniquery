$LOAD_PATH.unshift(File.expand_path('tests'))
require 'test_base'

# Test that standard table references are not considered "subqueries" in the omniquery sense
# Test that the "as" is optional when aliasing a source
# Test that multiline subqueries work, even if there are more parenthesis in there
#
test = OmniQueryTest.new('Basic Tests')
test.query_string = <<-SQL
  select * from things
  left join (/* remote query 1*/) data1__query1
  left join (/* not remote or special */) as data_things
  right join (/* remote query 2*/) as data2__query2
  join (
    /* ensure multi lines work; query 3 */
  ) as data3__query3
  join (
    select * from (select * from bar) as foo
  ) as data4__query4
SQL
test.expect(
  test.subqueries.map(&:table),
  ["query1", "query2", "query3", "query4"]
)

# Test that the subquery find method works as expected
#
test.expect(
  test.subquery_find('query2').class,
  OmniQuery::Subquery
)

# Test that the final SQL run on the sqlite file looks good
#
test.expect(
  test.sql.gsub(/\n/,'').gsub(/\s{2,}/,' ').strip,
  'select * from things left join query1 left join (/* not remote or special */) as data_things right join query2 join query3 join query4'
)
