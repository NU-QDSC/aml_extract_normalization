class AddFusionColumsToNgsPathologyCaseFindings < ActiveRecord::Migration[7.1]
  def change
    add_column :ngs_pathology_case_findings, :gene_position, :string
    add_column :ngs_pathology_case_findings, :fusion_gene, :string
    add_column :ngs_pathology_case_findings, :fusion_gene_position, :string
  end
end