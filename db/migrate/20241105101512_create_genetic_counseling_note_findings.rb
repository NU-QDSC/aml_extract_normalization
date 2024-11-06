class CreateGeneticCounselingNoteFindings < ActiveRecord::Migration[7.1]
  def change
    create_table :genetic_counseling_note_findings do |t|
      t.belongs_to :genetic_counseling_note, index: true
      t.string      :raw_finding
      t.string      :gene
      t.string      :variant_name
      t.string      :hgvs_c
      t.string      :hgvs_p
      t.string      :status
      t.timestamps
    end
  end
end
