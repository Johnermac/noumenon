class AddResultsToScans < ActiveRecord::Migration[7.1]
  def change
    add_column :scans, :results, :text
  end
end
