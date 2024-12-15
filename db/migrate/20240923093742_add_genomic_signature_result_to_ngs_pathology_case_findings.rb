class AddGenomicSignatureResultToNgsPathologyCaseFindings < ActiveRecord::Migration[7.1]
  def change
    add_column :ngs_pathology_case_findings, :genomic_signature_result, :string
  end
end
