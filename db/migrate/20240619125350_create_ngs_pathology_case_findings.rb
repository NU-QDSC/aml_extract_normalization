class CreateNgsPathologyCaseFindings < ActiveRecord::Migration[7.1]
  def change
    create_table :ngs_pathology_case_findings do |t|
      t.belongs_to :ngs_pathology_case, index: true
      t.string      :raw_finding
      t.string      :gene
      t.string      :variant_name
      t.string      :variant_type
      t.string      :allelic_frequency
      t.string      :transcript
      t.string      :significance
      t.string      :status      
      t.timestamps
    end
  end
end
