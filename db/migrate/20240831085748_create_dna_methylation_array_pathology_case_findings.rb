class CreateDnaMethylationArrayPathologyCaseFindings < ActiveRecord::Migration[7.1]
  def change
    create_table :dna_methylation_array_pathology_case_findings do |t|
      t.belongs_to    :dna_methylation_array_pathology_case, index: true
      t.string        :methylation_class
      t.string        :methylation_subclass
      t.string        :score
      t.string        :interpretation
      t.timestamps
    end
  end
end
