class CreateGeneticCounselingNotes < ActiveRecord::Migration[7.1]
  def change
    create_table :genetic_counseling_notes do |t|
      t.integer       :patient_ir_id
      t.string        :west_mrn
      t.string        :source_system_name
      t.integer       :source_system_id
      t.date          :encounter_start_date_key
      t.text          :note_text
      t.timestamps
    end
  end
end
