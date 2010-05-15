require 'active_record'

# See README.rdoc for an extended introduction. The QueryableWith::ClassMethods#query_set, 
# QueryableWith::QuerySet#queryable_with and QueryableWith::QuerySet#add_scope methods may also
# be of interest.
module QueryableWith

  def self.included(active_record) # :nodoc:
    active_record.send :extend, QueryableWith::ClassMethods
  end
  
  module ClassMethods
    def query_sets # :nodoc:
      read_inheritable_attribute(:query_sets) || write_inheritable_hash(:query_sets, {})
    end
    
    # Defines a query set with the given name. This has the effect of defining a method that calls
    # every implicit or explicit scope added to that query set.
    #
    # When a block is given, that block is evaluated in the context of either a newly-created query
    # set or (in the case of inherited classes) the pre-existing set of that name. See 
    # QueryableWith::QuerySet#queryable_with and QueryableWith::QuerySet#add_scope for more details.
    #
    # When <tt>parent</tt> is given as an option, the new query set will inherit all of the scopes from
    # the named parent.
    def query_set(set_name, options={}, &block) # :yields:
      set = query_set_for(set_name, options).tap { |s| s.instance_eval(&block) if block_given? }
      
      class_eval <<-RUBY
        def self.#{set_name}(params={})
          self.query_sets["#{set_name}"].query(self, params)
        end
      RUBY
    end
    
    protected
    
      def query_set_for(set_name, options) # :nodoc:
        query_sets[set_name.to_s] || query_sets.store(set_name.to_s, QueryableWith::QuerySet.new(options))
      end
  end
  
  class QuerySet
    
    def initialize(options={}) # :nodoc:
      @queryables = []
      
      if options.has_key?(:parent)
        @queryables << QueryableWith::ImplicitScopeParameter.new(options[:parent])
      end
    end
    
    # Make this QuerySet queryable with the named parameter(s). If no other options are given,
    # this will result in a query on either the column or (if defined) scope of the same
    # name of the base scope and values passed to #query. It also accepts the following options:
    #
    # * <tt>scope</tt> - Map the incoming parameter to this scope. The argument by be a symbol (name of the 
    #   scope), a Hash (scope conditions) or a lambda.
    # * <tt>column</tt> - Map the incoming parameter to this column.
    # * <tt>default</tt> - Default the incoming parameter to this value even if it isn't provided.
    # * <tt>wildcard</tt> - If true, generate a SQL LIKE query with the incoming parameter. Used only 
    #   if the <tt>scope</tt> option is absent or a block is not provided.
    # * <tt>allow_blank</tt> - If true, treat incoming parameters mapped to nil or a blank string as
    #   IS NULL for the purposes of SQL query generation. Used only if the <tt>scope</tt> option is absent.
    #
    # If a block is provided, incoming parameters to the query will be passed through that function first. 
    # For example,
    #
    #   queryable_with(:company_name, :scope => :by_company) do |name| 
    #     Company.find_by_name(name)
    #   end
    #
    # will attempt to look up a company name first, then pass it to a pre-defined scope called 
    # <tt>by_company</tt>.
    def queryable_with(*expected_parameters, &block)
      options = expected_parameters.extract_options!
      
      @queryables += expected_parameters.map do |parameter|
        QueryableWith::QueryableParameter.new(parameter, options, &block)
      end
    end
    
    # Add a scope that is always applied to any calls to #query. This may be a symbol (the name of
    # the scope to add), a Hash (scope conditions) or a lambda. Useful when, for example, you only
    # ever want to see records with an <tt>active</tt> flag set to true.
    #
    #   add_scope :active
    #   add_scope :conditions => { :active => true }
    def add_scope(scope)
      @queryables << QueryableWith::ImplicitScopeParameter.new(scope)
    end
    
    # Applies all of the defined queryable and added scopes in this query set to the given base scope
    # (usually an ActiveRecord class, but can also be a pre-existing NamedScope object) based on the
    # query parameters and returns a new scope, ready to be queried.
    def query(base_scope, params={}) # :nodoc:
      @queryables.inject(base_scope) do |scope, queryer|
        queryer.query(scope, params)
      end.scoped({})
    end
    
  end
  
  class ImplicitScopeParameter # :nodoc:
    
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
  
  class QueryableParameter # :nodoc:
    attr_reader :expected_parameter, :column_name
    
    def initialize(expected_parameter, options={}, &block)
      @scope, @wildcard, @default_value, @allow_blank = options.values_at(:scope, :wildcard, :default, :allow_blank)
      @expected_parameter = expected_parameter.to_sym
      @column_name = options[:column] || @expected_parameter.to_s
      @value_mapper = block || lambda {|o| o}
    end
    
    def scoped?; !@scope.blank?; end
    def wildcard?; @wildcard == true; end
    def blank_allowed?; @allow_blank == true; end
    def has_default?; !@default_value.nil?; end
    def scope_name; @scope || self.expected_parameter; end
    
    def query(queryer, params={})
      params = params.with_indifferent_access
      params_contain_queryable_value, queried_value = determine_queried_value(params[@expected_parameter])
      
      return queryer unless params_contain_queryable_value
      queried_value = @value_mapper.call(queried_value)
      
      if scoped? || queryer_scoped?(queryer)
        queryer.send scope_name, queried_value
      else
        queryer.scoped(:conditions => conditions_for(queryer, queried_value))
      end
    end
    
    protected
    
      def determine_queried_value(value_in_params)
        if value_in_params.blank? && value_in_params != false
          if blank_allowed?
            return true, nil
          elsif has_default?
            return true, @default_value
          else
            return false, nil
          end
        else
          return true, value_in_params
        end
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
        
        final_values = [ value ].flatten.map do |value|
          wildcard? ? "%#{value}%" : value
        end
        
        final_query_string = ( [ query_string ] * final_values.size ).join(" OR ")
        
        [ final_query_string ] + final_values
      end
    
  end
  
end

module ActiveRecord # :nodoc:
  class Base # :nodoc:
    include QueryableWith
  end
end