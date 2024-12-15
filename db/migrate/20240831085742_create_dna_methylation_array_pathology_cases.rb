class CreateDnaMethylationArrayPathologyCases < ActiveRecord::Migration[7.1]
  def change
    create_table :dna_methylation_array_pathology_cases do |t|
      t.string        :west_mrn
      t.integer       :pathology_case_key
      t.string        :source_system
      t.integer       :pathology_case_source_system_id
      t.string        :accession_nbr_formatted
      t.string        :group_desc
      t.string        :snomed_code
      t.string        :snomed_name
      t.date          :accessioned_date_key
      t.date          :case_collect_date_key
      t.string        :section_description
      t.text          :note_text
      t.timestamps
    end
  end
end
