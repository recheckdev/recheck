# Recheck Checker API Documentation
#
# This file documents the complete Checker API for Recheck.
# Use this as a reference when creating your own checkers.

# All checkers must inherit from Recheck::Checker::Base to be registered
class SampleChecker < Recheck::Checker::Base
  #
  # CHECKER LIFECYCLE AND HOOKS
  # ==========================
  #
  # Checkers have a simple lifecycle with four hooks:
  #
  # 1. initialize - Optional setup
  # 2. query_* methods - Required to fetch records to check
  # 3. check_* methods - Required to validate each record
  # 4. Metadata methods - Optional for routing and prioritization
  #

  # Hook 1: initialize (optional)
  # ----------------------------
  # Use initialize to set up any resources needed by your checks.
  # This runs once when the checker is instantiated.
  def initialize
    # You can:
    # - Connect to external services
    # - Load reference data
    # - Set up caches or other shared resources
    # - Configure the checker based on environment

    @external_service = ExternalService.new(api_key: ENV["API_KEY"])
    @reference_data = load_reference_data
    @cache = {}
  end

  # You can use helper methods to organize your code
  def load_reference_data
    # Load data from a file, database, or API
    # This is just a helper method, not part of the Checker API
    {}
  end

  # Hook 2: query_* methods (one required)
  # ---------------------------------
  # At least one query method is required. Query methods must:
  # - Start with "query" (or they won't be detected)
  # - Return an Enumerable of records to check
  # - Be efficient (they often run against production databases)

  # Basic query method - returns all records of a type
  def query
    # The simplest query just returns all records
    # Use find_each with ActiveRecord for batching
    Model.find_each
  end

  # You can have multiple query methods to:
  # - Check different record types
  # - Optimize performance with targeted queries
  # - Focus on specific subsets of data
  def query_recent
    # Focus on recently created/updated records
    Model.where("updated_at > ?", 1.day.ago).find_each
  end

  def query_problematic
    # Target records that might have issues
    Model.where(status: "error")
      .or(Model.where(processed_at: nil))
      .includes(:related_records) # Eager load associations
      .find_each
  end

  # Query methods can return any Enumerable, not just ActiveRecord
  def query_external_data
    # You can check data from external sources
    @external_service.fetch_records.map do |record|
      # Transform external data if needed
      {id: record["id"], data: record["payload"]}
    end
  end

  # Query methods can return arrays, hashes, or custom objects
  def query_composite
    # You can join data from multiple sources
    [
      {type: "config", value: AppConfig.settings},
      {type: "status", value: SystemStatus.current}
    ]
  end

  # Hook 3: check_* methods (one required)
  # ---------------------------------
  # Check methods must:
  # - Start with "check_" (or they won't be detected)
  # - Take a single record parameter
  # - Return false/nil for failing records, anything else for passing

  # Basic check - validates a single aspect of a record
  def check_record_is_valid(record)
    # The simplest check just calls ActiveRecord validations
    # Returns false if invalid, true if valid
    record.valid?
  end

  # Checks can implement complex business rules
  def check_business_rule(record)
    # Implement any business logic
    # Return false/nil for failing records
    if record.status == "completed" && record.completed_at.nil?
      # This is a failing condition
      return false
    end

    # Any non-false/nil return is considered passing
    true
  end

  # Checks can integrate with external systems
  def check_external_consistency(record)
    # Check that record matches external system
    external_data = @external_service.find(record.external_id)

    # Return false if inconsistent
    return false if external_data.nil?
    return false if external_data["status"] != record.status

    # Return true if consistent
    true
  end

  # Checks can automatically fix issues (use carefully!)
  def check_and_fix(record)
    # Check if there's an issue
    if record.calculated_total != record.stored_total
      # Fix the issue
      record.stored_total = record.calculated_total
      record.save!

      # Log the fix
      LoggingService.info("Fixed total for record #{record.id}")
    end

    # Return true since we've fixed the issue
    true
  end

  # Checks can handle different record types from different queries
  def check_config_is_valid(record)
    # Handle records from query_composite
    if record[:type] == "config"
      # Check config settings
      return record[:value].valid?
    elsif record[:type] == "status"
      # Check system status
      return record[:value].ok?
    end

    # Skip records this check doesn't understand
    true
  end

  #
  # METADATA METHODS
  # ===============
  #
  # These optional methods provide metadata about your checker
  # for use by reporters and the Recheck runner.
  #

  # Team responsible for this checker
  # Used by reporters to route notifications
  def team
    :data_integrity
  end

  # Priority of this checker
  # Used by reporters to prioritize notifications
  def priority
    :high # :high, :medium, :low
  end

  # Tags for this checker
  # Used for filtering and categorization
  def tags
    [:critical, :customer_facing]
  end

  # Documentation URL
  # Link to runbook or documentation
  def documentation_url
    "https://internal-docs.example.com/data-integrity/sample-checker"
  end

  # Slack channel for notifications
  # Used by SlackReporter
  def slack_channel
    "#data-alerts"
  end

  # Email recipients for notifications
  # Perhaps used by EmailReporter
  def email_recipients
    ["data-team@example.com", "oncall@example.com"]
  end
end
