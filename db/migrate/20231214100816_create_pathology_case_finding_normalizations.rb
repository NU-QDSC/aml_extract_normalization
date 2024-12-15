class CreatePathologyCaseFindingNormalizations < ActiveRecord::Migration[7.1]
  def change
    create_table :pathology_case_finding_normalizations do |t|
      t.belongs_to :pathology_case_finding, index: true
      t.string     :normalization_name
      t.string     :normalization_type
      t.string     :gene_1
      t.string     :gene_2
      t.string     :match_token
      t.timestamps
    end
  end
end
