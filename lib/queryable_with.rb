require 'active_record'

module QueryableWith
  
  def self.included(active_record)
    active_record.send :extend, QueryableWith::ClassMethods
  end
  
  module ClassMethods
    def query_sets
      read_inheritable_attribute(:query_sets) || write_inheritable_hash(:query_sets, {})
    end
    
    def query_set(set_name, options={}, &block)
      set = query_set_for(set_name, options).tap { |s| s.instance_eval(&block) if block_given? }
      
      class_eval <<-RUBY
        def self.#{set_name}(params={})
          self.query_sets["#{set_name}"].query(self, params)
        end
      RUBY
    end
    
    protected
    
      def query_set_for(set_name, options)
        query_sets[set_name.to_s] || query_sets.store(set_name.to_s, QueryableWith::QuerySet.new(options))
      end
  end
  
  class QuerySet
    
    def initialize(options={})
      @queryables = []
      
      if options.has_key?(:parent)
        @queryables << QueryableWith::AddedScope.new(options[:parent])
      end
    end
    
    def queryable_with(*expected_parameters, &block)
      options = expected_parameters.extract_options!
      
      @queryables += expected_parameters.map do |parameter|
        QueryableWith::QueryableParameter.new(parameter, options, &block)
      end
    end
    
    def add_scope(scope)
      @queryables << QueryableWith::AddedScope.new(scope)
    end
    
    def query(base_scope, params={})
      @queryables.inject(base_scope) do |scope, queryer|
        queryer.query(scope, params)
      end
    end
    
  end
  
  class AddedScope
    
    def initialize(scope)
      @scope = scope
    end
    
    def query(queryer, params={})
      if @scope.is_a? Symbol
        queryer.send @scope, params
      else
        queryer.scoped @scope
      end
    end
    
  end
  
  class QueryableParameter
    attr_reader :expected_parameter, :column_name
    
    def initialize(expected_parameter, options={}, &block)
      @scope, @wildcard, @default_value = options.values_at(:scope, :wildcard, :default)
      @expected_parameter = expected_parameter.to_sym
      @column_name = options[:column] || @expected_parameter.to_s
      @value_mapper = block || lambda {|o| o}
    end
    
    def scoped?; !@scope.blank?; end
    def wildcard?; @wildcard == true; end
    def scope_name; @scope || self.expected_parameter; end
    
    def query(queryer, params={})
      params = params.with_indifferent_access
      return queryer unless should_apply_to?(params)
      
      if scoped? || queryer_scoped?(queryer)
        queryer.send scope_name, queried_parameter(params)
      else
        queryer.scoped(:conditions => conditions_for(queryer, queried_parameter(params)))
      end
    end
    
    protected
    
      def should_apply_to?(params)
        params.has_key?(@expected_parameter) || !@default_value.blank?
      end
      
      def queried_parameter(params)
        relevant_param = params[@expected_parameter].nil? ? @default_value : params[@expected_parameter]
        @value_mapper.call(relevant_param)
      end
    
      def queryer_scoped?(queryer)
        queryer.scopes.keys.include?(@expected_parameter)
      end
      
      def conditions_for(queryer, value)
        query_string = if wildcard?
          "(#{queryer.table_name}.#{self.column_name} LIKE ?)"
        else
          "(#{queryer.table_name}.#{self.column_name} = ?)"
        end
        
        final_values = Array(value).map do |value|
          wildcard? ? "%#{value}%" : value
        end
        
        final_query_string = ( [ query_string ] * final_values.size ).join(" OR ")
        
        [ final_query_string ] + final_values
      end
    
  end
  
end

module ActiveRecord
  class Base
    include QueryableWith
  end
end