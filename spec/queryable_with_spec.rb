require File.dirname(__FILE__) + "/spec_helper"

describe QueryableWith do
  before :each do
    User.delete_all
    User.query_sets.clear
  end
  
  it "includes itself in ActiveRecord" do
    ActiveRecord::Base.ancestors.should include(QueryableWith)
  end
  
  describe "query_set" do
    it "exposes a new method named after the defined query set" do
      User.query_set :test
      User.methods.should include("test")
    end
    
    it "returns the receiver if no params to filter are passed" do
      User.query_set :test
      User.test.should == User
    end
  end
  
  describe "queryable_with" do
    it "maps a parameter directly to a column" do
      guybrush = User.create! :name => "Guybrush"
      elaine   = User.create! :name => "Elaine"
      User.query_set(:test) { queryable_with(:name) }
      
      User.test(:name => "Guybrush").should == [ guybrush ]
    end
    
    it "maps multiple parameters, each to their own column" do
      guybrush = User.create! :name => "Guybrush", :active => true
      elaine   = User.create! :name => "Elaine", :active => false
      User.query_set(:test) { queryable_with(:name, :active) }
      
      # User.test(:name => "Guybrush").should == [ guybrush ]
      User.test(:active => false).should == [ elaine ]
    end
    
    it "uses the correct table name when referring to columns with potentially conflicting names" do
      # The employers table also has a name column.
      User.query_set(:test) { queryable_with(:name) }
      
      lambda do
        User.test(:name => "Guybrush").all(:joins => :employer)
      end.should_not raise_error(ActiveRecord::StatementInvalid)
    end
    
    it "selects any one of a given list of values" do
      guybrush = User.create! :name => "Guybrush"
      elaine   = User.create! :name => "Elaine"
      User.query_set(:test) { queryable_with(:name) }
      
      User.test(:name => ["Guybrush", "Elaine"]).should include(guybrush, elaine)
    end
    
    it "returns the receiver if queried with an empty set of params" do
      User.query_set(:test) { queryable_with(:name) }
      User.test.should == User
    end
    
    it "applies multiple parameters if multiple parameters are queried" do
      active_bob = User.create! :name => "Bob", :active => true
      lazy_bob   = User.create! :name => "Bob", :active => false
      User.query_set(:test) { queryable_with(:name, :active) }
      
      User.test(:name => "Bob", :active => true).should == [ active_bob ]
    end
    
    it "delegates the underlying filter to a pre-existing named scope if one of that name is defined" do
      guybrush = User.create! :name => "Guybrush"
      User.named_scope(:naym, lambda { |name| { :conditions => { :name => name } } })
      User.query_set(:test) { queryable_with(:naym) }
      
      User.test(:naym => "Guybrush").should == [ guybrush ]
      User.test(:naym => "Herrman").should == [ ]
    end
    
    describe ":scope => [scope_name]" do
      it "delegates the underlying filter to a pre-existing scope if passed as an option" do
        guybrush = User.create! :name => "Guybrush"
        User.named_scope(:naym, lambda { |name| { :conditions => { :name => name } } })
        User.query_set(:test) { queryable_with(:nizame, :scope => :naym) }
      
        User.test(:nizame => "Guybrush").should == [ guybrush ]
        User.test(:nizame => "Herrman").should == [ ]
      end
    end
    
    describe ":wildcard => true" do
      it "wildcards the given value" do
        guybrush = User.create! :name => "Guybrush"
        User.query_set(:test) { queryable_with(:name, :wildcard => true) }
        
        User.test(:name => "uybru").should == [ guybrush ]
        User.test(:name => "Elaine").should == [ ]
      end
      
      it "ORs multiple wildcarded values" do
        guybrush = User.create! :name => "Guybrush"
        elaine   = User.create! :name => "Elaine"
        User.query_set(:test) { queryable_with(:name, :wildcard => true) }
        
        User.test(:name => ["uybru", "lain"]).should include(guybrush, elaine)
      end
    end
    
    describe ":column => [column_name]" do
      it "maps the parameter to the given column name" do
        guybrush = User.create! :name => "Guybrush"
        elaine   = User.create! :name => "Elaine"
        User.query_set(:test) { queryable_with(:naym, :column => :name) }

        User.test(:naym => "Guybrush").should == [ guybrush ]
      end
    end
    
    describe ":default => [value]" do
      it "provides a default value if none is given in the query" do
        guybrush = User.create! :name => "Guybrush"
        elaine   = User.create! :name => "Elaine"
        User.query_set(:test) { queryable_with(:name, :default => "Guybrush") }
        
        User.test.should == [ guybrush ]
      end
    end
    
    describe "with a block" do
      it "permits you to transform the incoming value with a standard column lookup" do
        guybrush = User.create! :name => "Guybrush"
        elaine   = User.create! :name => "Elaine"
        User.query_set(:test) { queryable_with(:name) { |str| str.gsub(/fawkes/, "brush") } }
        
        User.test(:name => "Guyfawkes").should == [ guybrush ]
      end
      
      it "permits you to transform the incoming value with a scope" do
        guybrush1 = User.create! :name => "Guybrush", :employer => Employer.create!(:name => "Threepwood Nautical Services LLC")
        guybrush2 = User.create! :name => "Guybrush", :employer => Employer.create!(:name => "LeChuck LeLumber, Inc.")
        
        User.named_scope :by_employer, lambda { |employer| 
          { :conditions => { :employer_id => employer } } 
        }
        
        User.query_set(:test) do
          queryable_with :employer_name, :scope => :by_employer do |name|
            Employer.find_by_name(name)
          end
        end
        
        User.test(:employer_name => "Threepwood Nautical Services LLC").should == [ guybrush1 ]
      end
    end
  end
  
  describe "add_scope" do
    it "adds the given named scope to every query" do
      active   = User.create! :active => true
      inactive = User.create! :active => false
      User.named_scope(:only_active, :conditions => { :active => true })
      User.query_set(:test) { add_scope(:only_active) }

      User.test.all.should == [ active ]
    end
    
    it "adds the given ad hoc scope to every query" do
      active   = User.create! :active => true
      inactive = User.create! :active => false
      User.query_set(:test) { add_scope(:conditions => { :active => true }) }
      
      User.test.all.should == [ active ]
    end
  end
  
  describe "after subclassing" do
    it "inherits the query sets from its superclass" do
      User.query_set(:test) { add_scope(:conditions => { :active => true }) }
      class Pirate < User; end
      active   = Pirate.create! :active => true
      inactive = Pirate.create! :active => false
      
      Pirate.test.should == [ active ]
    end
    
    it "allows query sets to be extended by the subclass" do
      User.query_set(:test) { add_scope(:conditions => { :active => true }) }
      class Pirate < User; end
      Pirate.query_set(:test) { add_scope(:conditions => { :name => "Guybrush" }) }
      
      active_guy   = Pirate.create! :name => "Guybrush", :active => true
      inactive_guy = Pirate.create! :name => "Guybrush", :active => false
      
      Pirate.test.should == [ active_guy ]
    end
  end
  
end