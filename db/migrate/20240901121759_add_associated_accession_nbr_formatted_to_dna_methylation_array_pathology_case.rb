class AddAssociatedAccessionNbrFormattedToDnaMethylationArrayPathologyCase < ActiveRecord::Migration[7.1]
  def change
    add_column :dna_methylation_array_pathology_cases, :associated_accession_nbr_formatted, :string
    add_column :dna_methylation_array_pathology_cases, :associated_accession_nbr_formatted_block, :string
    add_column :dna_methylation_array_pathology_cases, :associated_accession_nbr_formatted_block_tumor_percentage, :string
  end
end