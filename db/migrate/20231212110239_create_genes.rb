class CreateGenes < ActiveRecord::Migration[7.1]
  def change
    create_table :genes do |t|
      t.string        :hgnc_id
      t.string        :hgnc_symbol
      t.string        :name
      t.string        :location
      t.string        :alias_symbol
      t.string        :alias_name
      t.string        :prev_symbol
      t.string        :prev_name
      t.string        :gene_group
      t.timestamps
    end
  end
end



