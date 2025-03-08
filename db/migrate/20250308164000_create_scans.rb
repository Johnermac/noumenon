class CreateScans < ActiveRecord::Migration[7.1]
  def change
    create_table :scans do |t|
      t.string :domain
      t.string :status

      t.timestamps
    end
  end
end
