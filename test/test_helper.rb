ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "sidekiq/testing"

Sidekiq::Testing.fake!

class FakeRedis
  def initialize
    @sets = Hash.new { |hash, key| hash[key] = [] }
    @strings = {}
  end

  def smembers(key)
    @sets[key]
  end

  def get(key)
    @strings[key]
  end

  def set(key, value)
    @strings[key] = value
  end

  def expire(_key, _seconds)
    true
  end

  def add_set(key, *values)
    @sets[key].concat(values)
  end

  def set_string(key, value)
    @strings[key] = value
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
