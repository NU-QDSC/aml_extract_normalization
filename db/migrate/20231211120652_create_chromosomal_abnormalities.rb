class CreateChromosomalAbnormalities < ActiveRecord::Migration[7.1]
  def change
    create_table :chromosomal_abnormalities do |t|
      t.string        :abnormality
      t.string        :abnormality_type
      t.string        :abnormality_class
      t.string        :source
      t.timestamps
    end
  end
end
