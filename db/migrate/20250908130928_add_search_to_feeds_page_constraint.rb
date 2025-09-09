class AddSearchToFeedsPageConstraint < ActiveRecord::Migration[8.0]
  def up
    # Drop the existing constraint
    execute "ALTER TABLE feeds DROP CONSTRAINT chk_feeds_page"
    
    # Add the new constraint with 'search' included
    execute <<-SQL
      ALTER TABLE feeds ADD CONSTRAINT chk_feeds_page 
      CHECK (page::text = ANY (ARRAY['home'::character varying, 'pdp'::character varying, 'profile'::character varying, 'cart'::character varying, 'checkout'::character varying, 'search'::character varying]::text[]))
    SQL
  end

  def down
    # Drop the new constraint
    execute "ALTER TABLE feeds DROP CONSTRAINT chk_feeds_page"
    
    # Restore the original constraint without 'search'
    execute <<-SQL
      ALTER TABLE feeds ADD CONSTRAINT chk_feeds_page 
      CHECK (page::text = ANY (ARRAY['home'::character varying, 'pdp'::character varying, 'profile'::character varying, 'cart'::character varying, 'checkout'::character varying]::text[]))
    SQL
  end
end
