
$LOAD_PATH.unshift(File.expand_path('tests'))
require 'test_base'

# Test that no options on result references works
#
test = OmniQueryTest.new('No Result Reference Options')
test.query_string = <<-SQL
  select * from things
  join (
    select * from blahs where id in (/* table_name.column */)
  ) as datasource__another_table
SQL
sub = test.subqueries.first
test.expect(sub.result_references.first, ['', 'table_name', 'column'])

test = OmniQueryTest.new('Result Reference Unquoted Option')
test.query_string = <<-SQL
  select * from things
  left join (/* remote query 1*/) datasource__table_name,
  join (
    select * from blahs where id in (/* unquoted table_name.column */)
  ) as datasource__another_table
  join (
    select * from blahs where id in (/* table_name.column */)
  ) as datasource__third_table
  join (
    select * from blahs where id in (/* nonunique table_name.column */)
  ) as datasource__fourth_table
SQL

# Test that the table_name, datasource, original query, and result references were found
first = test.subqueries.first
test.expect(first.table, 'table_name')
test.expect(first.connection_name, 'datasource')
test.expect(first.original_sql, '/* remote query 1*/')

# Test that by default it uniques and that the unquoted command is found and used
second = test.subqueries[1]
second.singleton_class.define_method(:results_for) { |*args| [1,1,2,2,2,3] }
test.expect(second.result_references.first, ['unquoted ', 'table_name', 'column'])
test.expect(second.result_values(*second.result_references.first), '1,2,3')

# Test that it returns quoted things by default
third = test.subqueries[2]
third.singleton_class.define_method(:results_for) { |*args| [1,1,2,2,2,3] }
test.expect(third.result_references.first, ['', 'table_name', 'column'])
test.expect(third.result_values(*third.result_references.first), "'1','2','3'")

# Test that the nonunique keyword works
fourth = test.subqueries[3]
fourth.singleton_class.define_method(:results_for) { |*args| [1,1,2,2,2,3] }
test.expect(fourth.result_references.first, ['nonunique ', 'table_name', 'column'])
test.expect(fourth.result_values(*fourth.result_references.first), "'1','1','2','2','2','3'")

# Test that wildcard table references work as expected
#
test = OmniQueryTest.new('Wildcard Table Reference')
test.query_string = <<-SQL
  select * from things
  join () datasource__results1
  join () datasource__results2
  join () datasource__results3
  join (
    select * from blahs where id in (/* *.id */)
  ) as datasource__another_table
SQL
test.subqueries[0].singleton_class.define_method(:results) { |*args| [{ id: 1}, {id: 2}] }
test.subqueries[1].singleton_class.define_method(:results) { |*args| [{ id: 3}, {id: 4}] }
test.subqueries[2].singleton_class.define_method(:results) { |*args| [{ other: 5}, {other: 6}] }
test.subqueries[3].singleton_class.define_method(:results) { |*args| [{ id: 5}, {id: 6}] }

sub = test.subqueries[3]
# It should not include the values of itself
# It should skip and ignore result sets that do not contain the column in question
test.expect(sub.all_results('id'), [1,2,3,4])
test.expect(sub.result_values(*sub.result_references.first),"'1','2','3','4'")

# Test Default when there are no results references desired, which is ''
test.expect(sub.result_values('', '*', 'blah'), "''")

# Test the nullable option when there are no results
test.expect(sub.result_values('nullable', '*', 'blah'), 'null')
