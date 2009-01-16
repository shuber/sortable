require 'test/unit'
require 'rubygems'
gem 'activerecord'
require 'active_record'
require File.dirname(__FILE__) + '/../lib/sortable'

ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => ':memory:'

def create_todos_table
  silence_stream(STDOUT) do
    ActiveRecord::Schema.define(:version => 1) do
      create_table :todos do |t|
        t.integer  :project_id
        t.string   :action
        t.integer  :client_priority
        t.integer  :developer_priority
      end
    end
  end
end

# The table needs to exist before defining the class
create_todos_table

class Todo < ActiveRecord::Base
  sortable :scope => :project_id, :column => :client_priority, :list_name => :client
  sortable :scope => :project_id, :column => :developer_priority, :list_name => :developer
end

class SortableTest < Test::Unit::TestCase
  
  def setup
    ActiveRecord::Base.connection.tables.each { |table| ActiveRecord::Base.connection.drop_table(table) }
    create_todos_table
  end
  
  def test_should_add_to_lists
    @todo = Todo.create
    assert_equal 1, @todo.client_priority
    assert_equal 1, @todo.developer_priority
  end
  
  def test_should_increment_lists
    Todo.create    
    @todo = Todo.create
    assert_equal 2, @todo.client_priority
    assert_equal 2, @todo.developer_priority
  end
  
  def test_should_scope_lists
    Todo.create
    @todo = Todo.create :project_id => 1
    assert_equal 1, @todo.client_priority
    assert_equal 1, @todo.developer_priority
  end
  
  def test_should_remove_from_lists_on_destroy
    Todo.create
    @todo = Todo.create
    @todo_2 = Todo.create
    assert_equal 3, @todo_2.client_priority
    assert_equal 3, @todo_2.developer_priority
    @todo.destroy
    @todo_2.reload
    assert_equal 2, @todo_2.client_priority
    assert_equal 2, @todo_2.developer_priority
  end
  
  def test_should_return_first_item
    @todo = Todo.create
    @todo_2 = Todo.create
    assert_equal @todo, @todo_2.first_item(:client)
    assert_equal @todo, @todo_2.first_item(:developer)
  end
  
  def test_should_return_boolean_for_first_item?
    @todo = Todo.create
    @todo_2 = Todo.create
    assert @todo.first_item?(:client)
    assert !@todo_2.first_item?(:client)
  end
  
  def test_should_return_boolean_for_in_list?
    @todo = Todo.new
    assert !@todo.in_list?(:client)
    assert @todo.save
    assert @todo.in_list?(:client)
    @todo.remove_from_list!(:client)
    assert !@todo.in_list?(:client)
  end
  
  def test_should_insert_at!
    @todo = Todo.create
    @todo_2 = Todo.create
    @todo_3 = Todo.create
    @todo.insert_at!(2, :client)
    @todo_2.reload
    @todo_3.reload
    assert_equal 1, @todo_2.client_priority
    assert_equal 2, @todo.client_priority
    assert_equal 3, @todo_3.client_priority
  end
  
  def test_item_at_offset_should_return_previous_item
    @todo = Todo.create
    @todo_2 = Todo.create
    assert_equal @todo, @todo_2.item_at_offset(-1, :client)
  end
  
  def test_item_at_offset_should_return_next_item
    @todo = Todo.create
    @todo_2 = Todo.create
    assert_equal @todo_2, @todo.item_at_offset(1, :client)
  end
  
  def test_item_at_offset_should_return_nil_for_non_existent_offset
    @todo = Todo.create
    @todo_2 = Todo.create
    assert_nil @todo.item_at_offset(-1, :client)
    assert_nil @todo.item_at_offset(2, :client)
  end
  
  def test_should_return_last_item
    @todo = Todo.create
    @todo_2 = Todo.create
    assert_equal @todo_2, @todo.last_item(:client)
    assert_equal @todo_2, @todo.last_item(:developer)
  end
  
  def test_should_return_boolean_for_last_item?
    @todo = Todo.create
    @todo_2 = Todo.create
    assert @todo_2.last_item?(:client)
    assert !@todo.last_item?(:client)
  end
  
  def test_should_return_last_position
    assert_equal 0, Todo.new.last_position(:client)
    @todo = Todo.create
    assert_equal 1, @todo.last_position(:client)
    Todo.create
    assert_equal 2, @todo.last_position(:client)
  end
  
end