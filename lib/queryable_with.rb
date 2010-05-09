require 'active_record'

module QueryableWith
  
  def self.included(active_record)
    active_record.send :extend, QueryableWith::ClassMethods
  end
  
  module ClassMethods
    def query_sets
      @query_sets ||= {}.with_indifferent_access
    end
    
    def query_set(set_name, &block)
      set = QueryableWith::QuerySet.new(self)
      set.instance_eval(&block) if block_given?
      query_sets[set_name] = set
      
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
    
    def queryable_with(*expected_parameters)
      @queryables += expected_parameters.map do |parameter|
        QueryableWith::Parameter.new(parameter)
      end
    end
    
    def query(params={})
      @queryables.inject(@base_scope) do |scope, queryer|
        queryer.query(scope, params)
      end
    end
    
  end
  
  class Parameter
    
    def initialize(expected_parameter)
      @expected_parameter = expected_parameter.to_sym
    end
    
    def query(queryer, params={})
      params = params.with_indifferent_access
      return queryer unless params.has_key?(@expected_parameter)
      actual_parameter = params[@expected_parameter]
      
      if queryer.scopes.keys.include?(@expected_parameter)
        queryer.send @expected_parameter, actual_parameter
      else
        queryer.scoped(:conditions => {@expected_parameter => actual_parameter})
      end
    end
    
  end
  
end

module ActiveRecord
  class Base
    include QueryableWith
  end
end