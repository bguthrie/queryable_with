require File.dirname(__FILE__) + "/spec_helper"

describe QueryableWith do
  before :each do
    User.delete_all
  end
  
  it "includes itself in ActiveRecord" do
    ActiveRecord::Base.ancestors.should include(QueryableWith)
  end
  
  class User < ActiveRecord::Base
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
      guybrush = User.create! :first_name => "Guybrush"
      elaine   = User.create! :first_name => "Elaine"
      User.query_set(:test) { queryable_with(:first_name) }
      
      User.test(:first_name => "Guybrush").should == [ guybrush ]
    end
    
    it "maps multiple parameters, each to their own column" do
      guybrush = User.create! :first_name => "Guybrush", :last_name => "Threepwood"
      elaine   = User.create! :first_name => "Elaine", :last_name => "Threepwood"
      User.query_set(:test) { queryable_with(:first_name, :last_name) }
      
      User.test(:first_name => "Guybrush").should == [ guybrush ]
      User.test(:last_name => "Threepwood").should include(guybrush, elaine)
    end
    
    it "returns the receiver if queried with an empty set of params" do
      User.query_set(:test) { queryable_with(:first_name, :last_name) }
      User.test.should == User
    end
    
    it "applies multiple parameters if multiple parameters are queried" do
      guybrush = User.create! :first_name => "Guybrush", :last_name => "Threepwood"
      elaine   = User.create! :first_name => "Elaine", :last_name => "Threepwood"
      herrman  = User.create! :first_name => "Herrman", :last_name => "Toothrot"
      User.query_set(:test) { queryable_with(:first_name, :last_name) }
      
      User.test(:first_name => "Guybrush", :last_name => "Threepwood").should == [ guybrush ]
    end
    
    it "delegates the underlying filter to a pre-existing named scope if one of that name is defined" do
      User.named_scope(:first_name) { |name| { :conditions => { :first_name => "%#{name}%" } } }
      User.query_set(:test) { queryable_with(:first_name) }
    end
  end
  
end