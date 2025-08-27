class PresenceValidation < Test
  class User < ActiveRecord::Base
    self.table_name = :users

    def self.name = "User"
  end

  def setup
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

    ActiveRecord::Schema.define do
      create_table :users do |t|
        t.string :username, null: false
        t.string :email, null: true
        t.integer :age
        t.boolean :active
      end
    end
  end

  def test_presence
    model = Class.new(User) do
      validates :username, presence: true
    end

    user = model.new username: "alice"
    assert user.valid?

    user = model.new username: nil
    refute user.valid?
    assert_equal :blank, user.errors.where(:username).first.type

    user = model.new username: ""
    refute user.valid?
    assert_equal :blank, user.errors.where(:username).first.type

    # Presence uses .blank? so whitespace strings are invalid
    user = model.new username: "  "
    refute user.valid?
    assert_equal :blank, user.errors.where(:username).first.type
  end

  def test_allow_blank
    model = Class.new(User) do
      validates :username, presence: true, allow_blank: true
    end

    user = model.new username: "alice"
    assert user.valid?

    user = model.new username: nil
    assert user.valid?

    user = model.new username: ""
    assert user.valid?

    user = model.new username: "  "
    assert user.valid?
  end

  def test_allow_nil
    model = Class.new(User) do
      validates :username, presence: true, allow_nil: true
    end

    user = model.new username: "alice"
    assert user.valid?

    user = model.new username: nil
    assert user.valid?

    user = model.new username: ""
    refute user.valid?
    assert_equal :blank, user.errors.where(:username).first.type

    user = model.new username: "  "
    refute user.valid?
    assert_equal :blank, user.errors.where(:username).first.type
  end

  def test_allow_blank_and_allow_nil
    model = Class.new(User) do
      validates :username, presence: true, allow_blank: true, allow_nil: true
    end

    user = model.new username: "alice"
    assert user.valid?

    user = model.new username: nil
    assert user.valid?

    user = model.new username: ""
    assert user.valid?

    user = model.new username: "  "
    assert user.valid?
  end

  def test_allow_nil_when_column_not_null
    model = Class.new(User) do
      validates :email, presence: true, allow_nil: true
    end
    user = model.new email: nil
    assert user.valid?
    assert_raises(ActiveRecord::NotNullViolation) do
      user.save
    end
  end

  def test_boolean
    model = Class.new(User) do
      validates :active, presence: true
    end
    # not very useful because false is considered 'not present' so there's only one valid value
    user = model.new active: false
    assert user.active.blank?
    refute user.active.present?
    refute user.save
    assert_equal :blank, user.errors.where(:active).first.type
  end
end
