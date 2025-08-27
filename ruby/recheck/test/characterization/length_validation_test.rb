class LengthValidation < Test
  class User < ActiveRecord::Base
    self.table_name = :users

    def self.name = "User"
  end

  def setup
    ActiveRecord::Schema.define do
      create_table :users do |t|
        t.string :username
        t.string :email
        t.integer :age
        t.boolean :active
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
      validates :username, length: {minimum: 4}, allow_blank: true
    end

    # does not allow length 3 string
    user = model.new username: "bob"
    refute user.valid?

    # allows length 5 string
    user = model.new username: "alice"
    assert user.valid?

    # allows empty string
    user = model.new username: ""
    assert user.valid?

    # allows length 3 "blank" string string
    user = model.new username: "   "
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

  def test_validator_in_range_becomes_min_max
    model = Class.new(User) do
      # order of elements in the hash doesn't matter here
      validates :username, length: {in: 3..5, minimum: 2}
    end
    options = model.validators.first.options
    assert_equal 3, options[:minimum] # not 2
    assert_equal 5, options[:maximum]
    refute options.include? :in

    # half-open range doesn't set nil, leaves min or max
    model = Class.new(User) do
      # order of elements in the hash doesn't matter here
      validates :username, length: {in: ..5, minimum: 2}
    end
    options = model.validators.first.options
    assert_equal 2, options[:minimum]
    assert_equal 5, options[:maximum]
  end

  def test_length_non_overlapping_is_and_range
    model = Class.new(User) do
      validates :username, length: {is: 2, in: 3..5}
    end
    user = model.new username: "ab"
    refute user.valid?
    user = model.new username: "abc"
    refute user.valid?
    # I guess don't do this
  end

  def test_length_on_integer
    model = Class.new(User) do
      validates :age, length: {minimum: 2}
    end

    # it's length converted to string
    user = model.new age: 31
    assert user.valid?

    # so that includes a sign character
    user = model.new age: -2
    assert user.valid?

    user = model.new age: 3
    refute user.valid?
  end

  # ...yeah, it's calling to_s.length, but this is nonsense in mariadb
  # that uses 0/1 for booleans, so always length(bool) = 1
  def test_length_on_boolean
    model = Class.new(User) do
      validates :active, length: {minimum: 2}
    end
    user = model.new active: true
    assert user.valid?
  end
end
