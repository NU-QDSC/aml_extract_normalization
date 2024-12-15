class AddFusionExonColumnsToNgsPathologyFindings < ActiveRecord::Migration[7.1]
  def change
    add_column :ngs_pathology_case_findings, :gene_exon, :string
    add_column :ngs_pathology_case_findings, :fusion_gene_exon, :string
  end
end
