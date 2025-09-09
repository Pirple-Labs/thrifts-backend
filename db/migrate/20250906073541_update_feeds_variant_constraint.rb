class UpdateFeedsVariantConstraint < ActiveRecord::Migration[8.0]
  def up
    # Drop the existing check constraint
    execute "ALTER TABLE feeds DROP CONSTRAINT IF EXISTS check_feeds_variant"
    
    # Add the new check constraint that includes 'llm'
    execute "ALTER TABLE feeds ADD CONSTRAINT check_feeds_variant CHECK (variant IN ('control', 'operator', 'llm'))"
  end

  def down
    # Drop the new constraint
    execute "ALTER TABLE feeds DROP CONSTRAINT IF EXISTS check_feeds_variant"
    
    # Restore the original constraint
    execute "ALTER TABLE feeds ADD CONSTRAINT check_feeds_variant CHECK (variant IN ('control', 'operator'))"
  end
end
