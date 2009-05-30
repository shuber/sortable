= sortable

Allows you to sort ActiveRecord items similar to http://github.com/rails/acts_as_list but with added support for multiple scopes and lists

Requires ActiveRecord >= 2.0.0


== Installation

  gem install shuber-sortable --source http://gems.github.com
  OR
  script/plugin install git://github.com/shuber/sortable.git


== Examples

=== Simple

Works just like http://github.com/rails/acts_as_list

  class Todo < ActiveRecord::Base
    # schema
    #   id           :integer
    #   project_id   :integer
    #   description  :string
    #   position     :integer
    sortable :scope => :project_id
  end
  
  @todo = Todo.create(:description => 'do something', :project_id => 1)
  @todo_2 = Todo.create(:description => 'do something else', :project_id => 1)
  @todo_3 = Todo.create(:description => 'some other task', :project_id => 2)
  
  @todo.position # 1
  @todo_2.position # 2
  @todo_3.position # 1
  
  @todo.move_down!
  @todo_2.reload
  
  @todo.position # 2
  @todo_2.position # 1
  @todo_3.position # 1


=== Multiple scopes

Stories may or may not be in a sprint, but if we scoped just by :sprint_id, all stories with a nil :sprint_id 
would be sorted in one giant list instead of being sorted in each of their respective projects. Specifying an 
array of scopes fixes this problem.

  class Story < ActiveRecord::Base
    # schema
    #   id           :integer
    #   project_id   :integer
    #   sprint_id    :integer
    #   description  :string
    #   position     :integer
    sortable :scope => [:project_id, :sprint_id]
  end


=== Multiple lists

Your project management software needs to allow both clients and developers to prioritize todo items separately 
so that they can be discussed and reviewed during their next meeting. Multiple lists solves this problem.

  class Todo < ActiveRecord::Base
    # schema
    #   id                  :integer
    #   project_id          :integer
    #   description         :string
    #   client_priority     :integer
    #   developer_priority  :integer
    sortable :scope => :project_id, :column => :client_priority, :list_name => :client
    sortable :scope => :project_id, :column => :developer_priority, :list_name => :developer
  end
  
  @todo = Todo.create(:description => 'do something', :project_id => 1)
  @todo_2 = Todo.create(:description => 'do something else', :project_id => 1)
  
  @todo.client_priority # 1
  @todo.developer_priority # 1
  @todo_2.client_priority # 2
  @todo_2.developer_priority # 2
  
  @todo.move_down!(:client)
  @todo_2.reload
  
  @todo.client_priority # 2
  @todo.developer_priority # 1
  @todo_2.client_priority # 1
  @todo_2.developer_priority # 2


=== Switching scope

Any attributes specified as a :scope that are changed on an item cause the item to automatically switch lists when it is saved

  class Todo < ActiveRecord::Base
    # schema
    #   id           :integer
    #   project_id   :integer
    #   description  :string
    #   position     :integer
    sortable :scope => :project_id
  end
  
  @todo = Todo.create(:description => 'do something', :project_id => 1)
  @todo_2 = Todo.create(:description => 'do something else', :project_id => 1)
  
  @todo.position # 1
  @todo_2.position # 2
  
  @todo.project_id = 2
  @todo.save
  @todo_2.reload
  
  @todo.position # 1
  @todo_2.position # 1


== Instance methods

  # Adds the current item to the end of the specified list and saves
  #
  # If the current item is already in the list, it will remove it before adding it
  add_to_list!(list_name = nil)
  
  # Returns the first item in a list associated with the current item
  first_item(list_name = nil)
  
  # Returns a boolean after determining if the current item is the first item in the specified list
  first_item?(list_name = nil)
  
  # Returns an array of items higher than the current item in the specified list
  higher_items(list_name = nil)
  
  # Returns a boolean after determining if the current item is in the specified list
  in_list?(list_name = nil)
  
  # Inserts the current item at a certain position in the specified list and saves
  #
  # If the current item is already in the list, it will remove it before adding it
  #
  # Aliased as insert_at_position!
  insert_at!(position = 1, list_name = nil)
  
  # Returns the item with a position at a certain offset to the current item's position in the specified list
  #
  # Example
  #
  #   @todo = Todo.create
  #   @todo_2 = Todo.create
  #   @todo.item_at_offset(1) # returns @todo_2
  #
  # Returns nil if an item at the specified offset could not be found
  item_at_offset(offset, list_name = nil)
  
  # Returns the last item in a list associated with the current item
  last_item(list_name = nil)
  
  # Returns a boolean after determining if the current item is the last item in the specified list
  last_item?(list_name = nil)
  
  # Returns the position of the last item in a specified list
  #
  # Returns 0 if there are no items in the specified list
  last_position(list_name = nil)
  
  # Returns an array of items lower than the current item in the specified list
  lower_items(list_name = nil)
  
  # Moves the current item down one position in the specified list and saves
  move_down!(list_name = nil)
  
  # Moves the current item up one position in the specified list and saves
  move_up!(list_name = nil)
  
  # Moves the current item down to the bottom of the specified list and saves
  move_to_bottom!(list_name = nil)
  
  # Moves the current item up to the top of the specified list and saves
  move_to_top!(list_name = nil)
  
  # Returns the next lower item in the specified list
  next_item(list_name = nil)
  
  # Returns the previous higher item in the specified list
  previous_item(list_name = nil)
  
  # Removes the current item from the specified list and saves
  #
  # This will set the :position to nil
  remove_from_list!(list_name = nil)
  
  # Returns a boolean after determining if this item has changed any attributes specified in the :scope options
  sortable_scope_changed?
  
  # Stores an array of attributes specified as a :scope that have been changed
  sortable_scope_changes


== Contact

Problems, comments, and suggestions all welcome: shuber@huberry.com