class CreateGeneAbnormalitySynonyms < ActiveRecord::Migration[7.1]
  def change
    create_table :gene_abnormality_synonyms do |t|
      t.belongs_to :gene_abnormality, index: true
      t.string     :gene_abnormality_synonym
      t.timestamps
    end
  end
end
