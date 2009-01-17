module Huberry
  module Sortable
    class InvalidSortableList < StandardError; end
    
    def assert_sortable_list_exists!(list_name)
      raise ::Huberry::Sortable::InvalidSortableList.new("sortable list '#{list_name}' does not exist") unless sortable_lists.has_key?(list_name.to_s)
    end
    
    def sortable(options = {})
      include InstanceMethods unless include?(InstanceMethods)
      
      cattr_accessor :sortable_lists unless respond_to?(:sortable_lists)
      self.sortable_lists ||= {}
      
      define_attribute_methods
      
      options = { :column => :position, :conditions => '1 = 1', :list_name => nil, :scope => [] }.merge(options)
      options[:scope] = [options[:scope]] unless options[:scope].is_a?(Array)
      
      options[:scope].each do |scope|
        (options[:conditions].is_a?(Array) ? options[:conditions].first : options[:conditions]) << " AND (#{table_name}.#{scope} = ?) "
        
        unless instance_methods.include?("#{scope}_with_sortable=")
          define_method "#{scope}_with_sortable=" do |value|
            sortable_scope_changes << scope unless sortable_scope_changes.include?(scope) || new_record? || value == send(scope) || !self.class.sortable_lists.any? { |list_name, configuration| configuration[:scope].include?(scope) }
            send("#{scope}_without_sortable=".to_sym, value)
          end
          alias_method_chain "#{scope}=".to_sym, :sortable
        end
      end
      
      self.sortable_lists[options.delete(:list_name).to_s] = options
    end
    
    module InstanceMethods
      def self.included(base)
        base.class_eval do
          before_create :add_to_lists
          before_destroy :remove_from_lists
          before_update :update_lists, :if => :sortable_scope_changed?
          alias_method_chain :reload, :sortable
        end
      end
      
      def add_to_list!(list_name = nil)
        remove_from_list!(list_name) if in_list?(list_name)
        add_to_list(list_name)
        save
      end
      
      def first_item(list_name = nil)
        options = evaluate_sortable_options(list_name)
        self.class.send("find_by_#{options[:column]}".to_sym, 1, :conditions => options[:conditions])
      end
      
      def first_item?(list_name = nil)
        self == first_item(list_name)
      end
      
      def in_list?(list_name = nil)
        !new_record? && !send(evaluate_sortable_options(list_name)[:column]).nil?
      end
      
      def insert_at!(position = 1, list_name = nil)
        remove_from_list!(list_name)
        if position > last_position(list_name)
          add_to_list!(list_name)
        else
          move_lower_items(:down, position - 1, list_name)
          send("#{evaluate_sortable_options(list_name)[:column]}=".to_sym, position)
          save
        end
      end
      alias_method :insert_at_position!, :insert_at!
      
      def item_at_offset(offset, list_name = nil)
        options = evaluate_sortable_options(list_name)
        in_list?(list_name) ? self.class.send("find_by_#{options[:column]}".to_sym, send(options[:column]) + offset) : nil
      end
      
      def last_item(list_name = nil)
        options = evaluate_sortable_options(list_name)
        (options[:conditions].is_a?(Array) ? options[:conditions].first : options[:conditions]) << " AND #{self.class.table_name}.#{options[:column]} IS NOT NULL "
        self.class.find(:last, :conditions => options[:conditions], :order => options[:column].to_s)
      end
      
      def last_item?(list_name = nil)
        self == last_item(list_name)
      end
      
      def last_position(list_name = nil)
        item = last_item(list_name)
        item.nil? ? 0 : item.send(evaluate_sortable_options(list_name)[:column])
      end
      
      def move_down!(list_name = nil)        
        in_list?(list_name) && (last_item?(list_name) || insert_at!(send(evaluate_sortable_options(list_name)[:column]) + 1, list_name))
      end
      
      def move_up!(list_name = nil)
        in_list?(list_name) && (first_item?(list_name) || insert_at!(send(evaluate_sortable_options(list_name)[:column]) - 1, list_name))
      end
      
      def move_to_bottom!(list_name = nil)
        in_list?(list_name) && (last_item?(list_name) || add_to_list!(list_name))
      end
      
      def move_to_top!(list_name = nil)
        in_list?(list_name) && (first_item?(list_name) || insert_at!(1, list_name))
      end
      
      def next_item(list_name = nil)
        item_at_offset(1, list_name)
      end
      
      def previous_item(list_name = nil)
        item_at_offset(-1, list_name)
      end
      
      def reload_with_sortable
        @sortable_scope_changes = nil
        reload_without_sortable
      end
      
      def remove_from_list!(list_name = nil)
        if in_list?(list_name)
          remove_from_list(list_name)
          save
        else
          false
        end
      end
      
      def sortable_scope_changed?
        !sortable_scope_changes.empty?
      end
      
      protected
        
        def add_to_list(list_name = nil)
          send("#{evaluate_sortable_options(list_name)[:column]}=".to_sym, last_position(list_name) + 1)
        end
        
        def add_to_lists
          self.class.sortable_lists.each { |list_name, options| add_to_list(list_name) }
        end
        
        def evaluate_sortable_options(list_name = nil)
          self.class.assert_sortable_list_exists!(list_name)
          options = self.class.sortable_lists[list_name.to_s].inject({}) { |hash, pair| hash[pair.first] = pair.last.nil? || pair.last.is_a?(Symbol) ? pair.last : pair.last.dup; hash }
          options[:scope].each do |scope|
            value = send(scope)
            if value.nil?
              (options[:conditions].is_a?(Array) ? options[:conditions].first : options[:conditions]).gsub!(/#{scope} \= \?/, "#{scope} IS NULL")
            else
              options[:conditions] = [options[:conditions]] unless options[:conditions].is_a?(Array)
              options[:conditions] << value
            end
          end
          options
        end
        
        def move_lower_items(direction, position, list_name = nil)
          options = evaluate_sortable_options(list_name)
          (options[:conditions].is_a?(Array) ? options[:conditions].first : options[:conditions]) << " AND #{self.class.table_name}.#{options[:column]} > '#{position}' AND #{self.class.table_name}.#{options[:column]} IS NOT NULL "
          self.class.update_all "#{options[:column]} = #{options[:column]} #{direction == :up ? '-' : '+'} 1", options[:conditions]
        end
        
        def remove_from_list(list_name = nil)
          options = evaluate_sortable_options(list_name)
          move_lower_items(:up, send(options[:column]), list_name)
          send("#{options[:column]}=".to_sym, nil)
        end
        
        def remove_from_lists
          self.class.sortable_lists.each { |list_name, options| remove_from_list(list_name) }
        end
        
        def sortable_scope_changes
          @sortable_scope_changes ||= []
        end
        
        def update_lists
          new_values = sortable_scope_changes.inject({}) { |hash, scope| hash[scope] = send(scope).dup rescue nil; hash }
          sortable_scope_changes.each { |scope| send("#{scope}=".to_sym, send("#{scope}_was".to_sym)) }
          remove_from_lists
          new_values.each { |scope, value| send("#{scope}=".to_sym, value) }
          add_to_lists
        end
    end
  end
end

ActiveRecord::Base.extend Huberry::Sortable