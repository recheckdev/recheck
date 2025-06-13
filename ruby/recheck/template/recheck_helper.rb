# This file is automatically required before running any checks.
# Customize it to load your application environment and provide utility methods.

# For Rails applications:
require File.expand_path("../config/environment", __dir__)

# For non-Rails applications, you might want to do something like:
# $LOAD_PATH.unshift File.expand_path('../../lib', __dir__)
# require 'your_app'

# Load custom reporters
Dir.glob("#{__dir__}/reporter/**/*.rb").sort.each { |file| require_relative file }

# Add any other setup here.
# You could also share code by writing a YourAppChecker class (or classes) for your checkers to inherit from.
