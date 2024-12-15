class DnaMethylationArrayPathologyCase < ApplicationRecord
  has_many :dna_methylation_array_pathology_case_findings, dependent: :destroy
end