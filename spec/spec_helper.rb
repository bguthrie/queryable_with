$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'spec'
require 'queryable_with'

LOGFILE = File.open(File.dirname(__FILE__) + '/../tmp/database.log', 'a')
ActiveRecord::Base.logger = Logger.new(LOGFILE)
ActiveRecord::Base.configurations = true
ActiveRecord::Schema.verbose = false
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

ActiveRecord::Schema.define(:version => 1) do
  create_table :users do |t|
    t.string   "name"
    t.date     "birthdate"
    t.string   "email"
    t.string   "join_date"
    t.integer  "income"
    t.integer  "employer_id"
    t.string   "type"
    t.boolean  "active"
  end
  
  create_table :employers do |t|
    t.string "name"
    t.string "email"
    t.timestamps
  end
end

class User < ActiveRecord::Base
  belongs_to :employer
end

class Employer < ActiveRecord::Base
end