class CreateGeneAbnormality < ActiveRecord::Migration[7.1]
  def change
    create_table :gene_abnormalities do |t|
      t.string        :gene_abnormality
      t.string        :gene_abnormality_type
      t.string        :source
      t.timestamps
    end
  end
end
