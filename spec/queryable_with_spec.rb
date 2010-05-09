require File.dirname(__FILE__) + "/spec_helper"

describe QueryableWith do
  
  it "includes itself in ActiveRecord" do
    ActiveRecord::Base.ancestors.should include(QueryableWith)
  end
  
  class User < ActiveRecord::Base
  end
  
  describe "query_set" do
    it "exposes a query_set method" do
      User.methods.should include("query_set")
    end
    
    it "exposes a new method named after the defined query set" do
      User.query_set :filter_me
      User.methods.should include("filter_me")
    end
    
    it "returns the receiver if no params to filter are passed" do
      User.query_set :filter_me
      User.filter_me.should == User
    end
  end
  
  describe "queryable_with" do
    it "maps a parameter directly to a column, given no other parameters" do
      guybrush = User.create! :first_name => "Guybrush"
      elaine   = User.create! :first_name => "Elaine"
      User.query_set(:filter_me) { queryable_with(:first_name) }
      
      User.filter_me(:first_name => "Guybrush").should == [ guybrush ]
    end
  end
  
end