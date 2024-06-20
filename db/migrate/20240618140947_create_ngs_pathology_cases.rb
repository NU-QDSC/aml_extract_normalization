class CreateNgsPathologyCases < ActiveRecord::Migration[7.1]
  def change
    create_table :ngs_pathology_cases do |t|
      t.integer       :patient_ir_id
      t.string        :west_mrn
      t.string        :source_system_name
      t.integer       :source_system_id
      t.string        :accession_nbr_formatted
      t.date          :accessioned_datetime
      t.date          :case_collect_date_key
      t.string        :group_name
      t.string        :group_desc
      t.string        :report_description
      t.string        :section_description
      t.text          :note_text
      t.timestamps
    end
  end
end