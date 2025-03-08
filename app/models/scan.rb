class Scan < ApplicationRecord
  serialize :results, Hash # Stores scan results in JSON format
  validates :domain, presence: true
end
