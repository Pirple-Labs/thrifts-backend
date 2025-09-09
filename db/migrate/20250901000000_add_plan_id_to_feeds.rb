class AddPlanIdToFeeds < ActiveRecord::Migration[7.0]
  def change
    add_column :feeds, :plan_id, :string
    add_index  :feeds, :plan_id
  end
end


