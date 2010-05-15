require 'active_record'

module QueryableWith
  
  def self.included(active_record)
    active_record.send :extend, QueryableWith::ClassMethods
  end
  
  module ClassMethods
    def query_sets
      @query_sets ||= {}
    end
    
    def query_set(set_name, &block)
      query_sets[set_name.to_s] = QueryableWith::QuerySet.new(self).tap do |set|
        set.instance_eval(&block) if block_given?
      end
      
      class_eval <<-RUBY
        def self.#{set_name}(params={})
          self.query_sets["#{set_name}"].query(params)
        end
      RUBY
    end
  end
  
  class QuerySet
    
    def initialize(base_scope)
      @base_scope = base_scope
      @queryables = []
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
    
    def query(params={})
      @queryables.inject(@base_scope) do |scope, queryer|
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
        queryer.send @scope
      else
        queryer.scoped @scope
      end
    end
    
  end
  
  class QueryableParameter
    attr_reader :expected_parameter, :column_name
    
    def initialize(expected_parameter, options={}, &block)
      @scope, @wildcard = options.values_at(:scope, :wildcard)
      @expected_parameter = expected_parameter.to_sym
      @column_name = options[:column] || @expected_parameter.to_s
      @value_mapper = block || lambda {|o| o}
    end
    
    def scoped?; !@scope.blank?; end
    def wildcard?; @wildcard == true; end
    
    def query(queryer, params={})
      params = params.with_indifferent_access
      return queryer unless params.has_key?(@expected_parameter)
      actual_parameter = @value_mapper.call(params[@expected_parameter])
      
      if scoped? 
        queryer.send @scope, actual_parameter
      elsif queryer_scoped?(queryer)
        queryer.send expected_parameter, actual_parameter
      else
        queryer.scoped(:conditions => conditions_for(queryer, actual_parameter))
      end
    end
    
    protected
    
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