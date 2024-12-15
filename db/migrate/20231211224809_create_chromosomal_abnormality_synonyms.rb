class CreateChromosomalAbnormalitySynonyms < ActiveRecord::Migration[7.1]
  def change
    create_table :chromosomal_abnormality_synonyms do |t|
      t.belongs_to :chromosomal_abnormality, index: true
      t.string     :chromosomal_abnormality_synonym
      t.timestamps
    end
  end
end
