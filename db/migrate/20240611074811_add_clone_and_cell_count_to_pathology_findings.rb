class AddCloneAndCellCountToPathologyFindings < ActiveRecord::Migration[7.1]
  def change
    add_column :pathology_case_findings, :clone, :string
    add_column :pathology_case_findings, :cell_count, :string
  end
end
