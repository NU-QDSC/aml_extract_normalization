module Parsers
  class GeneticCounselingNote
    attr_accessor :patient_ir_id
    attr_accessor :west_mrn
    attr_accessor :source_system_name
    attr_accessor :source_system_table
    attr_accessor :source_system_id
    attr_accessor :encounter_start_date_key
    attr_accessor :note_text

    def fields
      accessor_methods = self.methods - Object.methods - [:fields]
    end
  end
end