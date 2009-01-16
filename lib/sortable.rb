module Huberry
  module Sortable
    def assert_sortable_list_exists!(list_name)
      raise "sortable list '#{list_name}' does not exist" unless sortable_lists.has_key?(list_name.to_s)
    end
    
    def sortable(options = {})
      include InstanceMethods unless include?(InstanceMethods)
      
      cattr_accessor :sortable_lists unless respond_to?(:sortable_lists)
      sortable_lists ||= {}
      
      define_attribute_methods
      
      options = { :column => :position, :conditions => '1 = 1', :list_name => nil, :scope => [] }.merge(options)
      options[:scope] = [options[:scope]] unless options[:scope].is_a?(Array)
      
      options[:scope].each do |scope|
        (options[:conditions].is_a?(Array) ? options[:conditions].first : options[:conditions]) << " AND (#{table_name}.#{scope} = ?) "
        
        unless respond_to?("#{scope}_with_acts_as_sortable=".to_sym)
          define_method "#{scope}_with_acts_as_sortable=" do |value|
            unless new_record? || value == send(scope)
              self.class.sortable_lists.each do |list_name, configuration|
                if configuration[:scope].include?(scope)
                  remove_from_list!(list_name)
                  send("#{scope}_without_acts_as_sortable=".to_sym, value)
                  add_to_list!(list_name)
                end
              end
            end
          end
          alias_method_chain "#{scope}=".to_sym, :acts_as_sortable
        end
      end
      
      sortable_lists[options.delete(:list_name).to_s] = options
    end
    
    module InstanceMethods
      def self.included?(base)
        base.class_eval do
          before_create :add_to_lists
          before_destroy :remove_from_lists
        end
      end
      
      def add_to_list!(list_name = nil)
        remove_from_list!(list_name) if in_list?(list_name)
        add_to_list(list_name)
        save
      end
      
      def first_item(list_name = nil)
        options = evaluated_options(list_name)
        self.class.send("find_by_#{options[:column]}", 1, :conditions => options[:conditions])
      end
      
      def first_item?(list_name = nil)
        self == first_item(list_name)
      end
      
      def in_list?(list_name = nil)
        !new_record? && !send(evaluated_options(list_name)[:column]).nil?
      end
      
      def insert_at!(position = 1, list_name = nil)
        remove_from_list!(list_name)
        if position > last_position(list_name)
          add_to_list!(list_name)
        else
          move_lower_items_down(position - 1, list_name)
          send("#{evaluated_options(list_name)[:column]}=", position)
          save
        end
      end
      alias_method :insert_at_position!, :insert_at!
      
      def item_at_offset(offset, list_name)
        options = evaluated_options(list_name)
        in_list?(list_name) ? self.class.send("find_by_#{options[:column]}", send(options[:column]) + offset) : nil
      end
      
      def last_item(list_name = nil)
        options = evaluated_options(list_name)
        (options[:conditions].is_a?(Array) ? options[:conditions].first : options[:conditions]) << " AND #{self.class.table_name}.#{options[:column]} IS NOT NULL "
        self.class.find(:last, :conditions => options[:conditions], :order => options[:column])
      end
      
      def last_item?(list_name = nil)
        self == last_item(list_name)
      end
      
      def last_position(list_name = nil)
        item = last_item(list_name)
        item.nil? ? 0 : item.send(evaluated_options(list_name)[:column])
      end
      
      def move_down!(list_name = nil)        
        in_list?(list_name) && (last_item?(list_name) || insert_at!(send(evaluated_options(list_name)[:column]) + 1, list_name))
      end
      
      def move_up!(list_name = nil)
        in_list?(list_name) && (first_item?(list_name) || insert_at!(send(evaluated_options(list_name)[:column]) - 1, list_name))
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
      
      def remove_from_list!(list_name = nil)
        if in_list?(list_name)
          remove_from_list(list_name)
          save
        else
          false
        end
      end
      
      protected
        
        def add_to_list(list_name)
          send("#{evaluated_options(list_name)[:column]}=", last_position(list_name) + 1)
        end
        
        def add_to_lists
          self.class.sortable_lists.each { |list_name, options| add_to_list(list_name) }
        end
        
        def move_lower_items_down(position, list_name = nil)
          move_lower_items(:down, position, list_name)
        end
        
        def move_lower_items_up(position, list_name = nil)
          move_lower_items(:up, position, list_name)
        end
        
        def remove_from_list(list_name)
          options = evaluated_options(list_name)
          move_lower_items_up(send(options[:column]), list_name)
          send("#{options[:column]}=", nil)
        end
        
        def remove_from_lists
          self.class.sortable_lists.each { |list_name, options| remove_from_list(list_name) }
        end
        
        def evaluated_options(list_name)
          self.class.assert_sortable_list_exists!(list_name)
          options = self.class.sortable_lists[list_name.to_s].inject({}) { |hash, pair| hash[key] = value.dup rescue nil; hash }
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
          options = evaluated_options(list_name)
          (options[:conditions].is_a?(Array) ? options[:conditions].first : options[:conditions]) << " AND #{self.class.table_name}.#{options[:column]} > '#{position}' AND #{self.class.table_name}.#{options[:column]} IS NOT NULL "
          self.class.update_all "#{options[:column]} = #{options[:column]} #{direction == :up ? '-' : '+'} 1", options[:conditions]
        end
    end
  end
end

ActiveRecord::Base.extend Huberry::Sortable