require 'active_record'

module QueryableWith
  
  def self.included(active_record)
    active_record.send :extend, QueryableWith::ClassMethods
  end
  
  module ClassMethods
    def query_set(set_name, &block)
      @query_sets ||= {}.with_indifferent_access
      set = QueryableWith::QuerySet.new(self)
      set.instance_eval(&block) if block_given?
      @query_sets[set_name] = set
      
      class_eval <<-RUBY
        def self.#{set_name}(params={})
          @query_sets["#{set_name}"].query(params)
        end
      RUBY
    end
  end
  
  class QuerySet
    
    def initialize(base_scope)
      @base_scope = base_scope
      @queryables = []
    end
    
    def queryable_with(expected_parameter)
      @queryables << QueryableWith::Parameter.new(expected_parameter)
    end
    
    def query(params={})
      @queryables.inject(@base_scope) do |scope, queryer|
        queryer.query(@base_scope, params)
      end
    end
    
  end
  
  class Parameter
    
    def initialize(expected_parameter)
      @expected_parameter = expected_parameter
    end
    
    def query(queryer, params={})
      queryer.scoped(:conditions => params.with_indifferent_access.slice(@expected_parameter))
    end
    
  end
  
end

module ActiveRecord
  class Base
    include QueryableWith
  end
end