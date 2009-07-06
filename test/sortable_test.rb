require 'test/unit'
require 'rubygems'

args = ['activerecord']
args << ENV['ACTIVE_RECORD_VERSION'] if ENV['ACTIVE_RECORD_VERSION']
send(:gem, *args)

require 'active_record'
require File.dirname(__FILE__) + '/../lib/sortable'

ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => ':memory:'

def create_tables
  silence_stream(STDOUT) do
    ActiveRecord::Schema.define(:version => 1) do
      create_table :todos do |t|
        t.integer  :project_id
        t.string   :type
        t.string   :action
        t.integer  :client_priority
        t.integer  :developer_priority
        t.integer  :position
      end
      
      create_table :users do |t|
        t.string   :type
        t.string   :name
        t.integer  :position
        t.integer  :steves_position
        t.boolean  :topuser
        t.integer  :topuser_position
      end
    end
  end
end

# The table needs to exist before defining the class
create_tables

class Todo < ActiveRecord::Base
  sortable :scope => :project_id, :conditions => 'todos.action IS NOT NULL'
  sortable :scope => :project_id, :column => :client_priority, :list_name => :client
  sortable :scope => :project_id, :column => :developer_priority, :list_name => :developer
end

class TodoChild < Todo
end

class User < ActiveRecord::Base
  sortable :scope => :type
  sortable :conditions => { :name => 'steve' }, :column => :steves_position, :list_name => :steves
  sortable :scope => :topuser, :column => :topuser_position, :list_name => :topusers
end

class Admin < User
end

class SortableTest < Test::Unit::TestCase
  
  def setup
    ActiveRecord::Base.connection.tables.each { |table| ActiveRecord::Base.connection.drop_table(table) }
    create_tables
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
    @todo_2 = Todo.create :project_id => 1
    @todo_3 = Todo.create
    assert_equal @todo, @todo_3.item_at_offset(-1, :client)
  end
  
  def test_item_at_offset_should_return_next_item
    @todo = Todo.create
    @todo_2 = Todo.create :project_id => 1
    @todo_3 = Todo.create
    assert_equal @todo_3, @todo.item_at_offset(1, :client)
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
  
  def test_should_move_down
    @todo = Todo.create
    Todo.create
    assert_equal 1, @todo.client_priority
    @todo.move_down!(:client)
    assert_equal 2, @todo.client_priority
  end
  
  def test_should_move_up
    Todo.create
    @todo = Todo.create
    assert_equal 2, @todo.client_priority
    @todo.move_up!(:client)
    assert_equal 1, @todo.client_priority
  end
  
  def test_should_move_to_bottom
    @todo = Todo.create
    Todo.create
    Todo.create
    assert_equal 1, @todo.client_priority
    @todo.move_to_bottom!(:client)
    assert_equal 3, @todo.client_priority
  end
  
  def test_should_move_to_top
    Todo.create
    Todo.create
    @todo = Todo.create
    assert_equal 3, @todo.client_priority
    @todo.move_to_top!(:client)
    assert_equal 1, @todo.client_priority
  end
  
  def test_should_return_next_item
    @todo = Todo.create
    @todo_2 = Todo.create
    assert_equal @todo_2, @todo.next_item(:client)
    assert_nil @todo_2.next_item(:client)
  end
  
  def test_should_return_previous_item
    @todo = Todo.create
    @todo_2 = Todo.create
    assert_equal @todo, @todo_2.previous_item(:client)
    assert_nil @todo.previous_item(:client)
  end
  
  def test_should_clear_sortable_scope_changes_when_reloading
    @todo = Todo.create
    @todo.project_id = 1
    assert @todo.sortable_scope_changed?
    @todo.reload
    assert !@todo.sortable_scope_changed?
  end
  
  def test_should_remove_from_list
    @todo = Todo.create
    @todo_2 = Todo.create
    assert_equal 1, @todo.client_priority
    assert_equal 2, @todo_2.client_priority
    @todo.remove_from_list!(:client)
    @todo_2.reload
    assert_nil @todo.client_priority
    assert_equal 1, @todo_2.client_priority
  end
  
  def test_should_return_boolean_for_sortable_scope_changed?
    @todo = Todo.new
    assert !@todo.sortable_scope_changed?
    @todo.project_id = 1
    assert !@todo.sortable_scope_changed?
    assert @todo.save
    @todo.reload
    @todo.project_id = 2
    assert @todo.sortable_scope_changed?
  end
  
  def test_should_list_attrs_in_sortable_scope_changes
    @todo = Todo.new
    assert_equal [], @todo.sortable_scope_changes
    @todo.project_id = 1
    assert_equal [], @todo.sortable_scope_changes
    assert @todo.save
    @todo.reload
    @todo.project_id = 2
    assert [:project_id], @todo.sortable_scope_changes
  end
  
  def test_should_raise_invalid_sortable_list_error_if_list_does_not_exist
    @todo = Todo.create
    assert_raises ::Huberry::Sortable::InvalidSortableList do
      @todo.move_up!(:invalid)
    end
  end
  
  def test_should_use_conditions
    @todo = Todo.create
    @todo_2 = Todo.create :action => 'test'
    @todo_3 = Todo.create
    @todo_4 = Todo.create :action => 'test again'
    @todo_5 = Todo.create
    @todo_6 = Todo.create
    assert_equal 1, @todo.position
    assert_equal 1, @todo_2.position
    assert_equal 2, @todo_3.position
    assert_equal 2, @todo_4.position
    assert_equal 3, @todo_5.position
    assert_equal 3, @todo_6.position
  end
  
  def test_should_scope_with_base_class
    @todo = Todo.create :action => 'test'
    @todo_2 = TodoChild.create :action => 'test'
    @todo_3 = Todo.create :action => 'test'
    assert_equal 1, @todo.position
    assert_equal 2, @todo_2.position
    assert_equal 3, @todo_3.position
  end
  
  def test_should_not_scope_with_base_class
    @user = User.create
    @admin = Admin.create
    @user_2 = User.create
    @admin_2 = Admin.create
    assert_equal 1, @user.position
    assert_equal 2, @user_2.position
    assert_equal 1, @admin.position
    assert_equal 2, @admin_2.position
  end
  
  def test_should_accept_hash_conditions
    @user = User.create :name => 'steve'
    @user_2 = User.create :name => 'bob'
    @user_3 = User.create :name => 'steve'
    assert_equal 1, @user.steves_position
    assert_equal 2, @user_2.steves_position
    assert_equal 2, @user_3.steves_position
  end
  
  def test_should_return_higher_items
    @user = User.create
    @user_2 = User.create
    @user_3 = User.create
    assert_equal [@user, @user_2], @user_3.higher_items
  end
  
  def test_should_return_lower_items
    @user = User.create
    @user_2 = User.create
    @user_3 = User.create
    assert_equal [@user_2, @user_3], @user.lower_items
  end
  
  def test_should_work_with_boolean_scope
    @user = User.create :topuser => false
    @user_2 = User.create :topuser => false
    assert_equal 1, @user.topuser_position
    assert_equal 2, @user_2.topuser_position
    @user_2.topuser = true
    @user_2.save
    assert_equal 1, @user_2.topuser_position
  end
  
end