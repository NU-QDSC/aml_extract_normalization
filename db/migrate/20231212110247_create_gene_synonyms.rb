class CreateGeneSynonyms < ActiveRecord::Migration[7.1]
  def change
    create_table :gene_synonyms do |t|
      t.belongs_to :gene, index: true
      t.string     :synonym_name
      t.string     :synonym_type
      t.timestamps
    end
  end
end
