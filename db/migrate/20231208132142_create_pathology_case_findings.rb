class CreatePathologyCaseFindings < ActiveRecord::Migration[7.1]
  def change
    create_table :pathology_case_findings do |t|
      t.belongs_to :pathology_case, index: true
      t.string      :genetic_abnormality_name
      t.string      :status
      t.string      :percentage
      t.text        :matched_og_phrase
      t.float       :score
      t.string      :extraction_status
      t.timestamps
    end
  end
end
