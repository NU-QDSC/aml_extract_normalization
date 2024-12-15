class CreateChromosomalAbnormalityAssociations < ActiveRecord::Migration[7.1]
  def change
    create_table :chromosomal_abnormality_associations do |t|
      t.string        :abnormality
      t.string        :chromosome
      t.string        :arm
      t.string        :band
      t.string        :gene
      t.string        :abnormality_type
      t.string        :abnormality_class
      t.string        :morph_name
      t.string        :morph
      t.string        :topo_name
      t.string        :topo
      t.string        :case_count
      t.timestamps
    end
  end
end
