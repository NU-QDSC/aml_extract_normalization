class CreateChromosomalAbnormalityGenes < ActiveRecord::Migration[7.1]
  def change
    create_table :chromosomal_abnormality_genes do |t|
      t.belongs_to :chromosomal_abnormality, index: true
      t.belongs_to :gene_abnormality
      t.string     :gene
      t.timestamps
    end
  end
end
