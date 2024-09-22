class AddCopyNumberToNgsPathologyCaseFindings < ActiveRecord::Migration[7.1]
  def change
    add_column :ngs_pathology_case_findings, :copy_number, :string
  end
end
