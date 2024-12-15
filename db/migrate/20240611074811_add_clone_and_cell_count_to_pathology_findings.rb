class AddCloneAndCellCountToPathologyFindings < ActiveRecord::Migration[7.1]
  def change
    add_column :pathology_case_findings, :clone_name, :string
    add_column :pathology_case_findings, :subclone, :boolean
    add_column :pathology_case_findings, :cell_count, :string
    add_column :pathology_case_findings, :chromosome_count, :string
    add_column :pathology_case_findings, :sex, :string
  end
end
