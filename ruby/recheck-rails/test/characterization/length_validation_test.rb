require "active_record"

class LengthValidation < Test
  class User < ActiveRecord::Base
    self.table_name = :users

    def self.name = "User"
  end

  def setup
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    # ActiveRecord::Base.logger = Logger.new($stdout)

    ActiveRecord::Schema.define do
      create_table :users do |t|
        t.string :username
        t.string :email
        t.integer :age
      end
    end
  end

  def test_length_with_two_attributes
    model = Class.new(User) do
      validates :username, :email, length: {minimum: 4}
    end

    # both can fail
    user = model.new username: "bob", email: "use"
    refute user.valid?
    assert_equal [:username, :email], user.errors.to_hash.keys

    # the validation applies independently to each attribute, not both
    user = model.new username: "alice", email: "use"
    refute user.valid?
    assert_equal [:email], user.errors.to_hash.keys
  end

  def test_length_with_allow_blank
    model = Class.new(User) do
      validates :username, length: {is: 5}, allow_blank: true
    end

    # allows length 5 string
    user = model.new username: "alice"
    assert user.valid?

    # allows empty string
    user = model.new username: ""
    assert user.valid?

    # allows nil
    user = model.new username: nil
    assert user.valid?
  end

  def test_length_with_allow_nil
    model = Class.new(User) do
      validates :username, length: {is: 5}, allow_nil: true
    end

    # allows length 5 string
    user = model.new username: "alice"
    assert user.valid?

    # does not allow empty string
    user = model.new username: ""
    refute user.valid?

    # allows nil
    user = model.new username: nil
    assert user.valid?
  end
end
