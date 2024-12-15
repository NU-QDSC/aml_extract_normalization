class ChromosomalAbnormalityGene < ApplicationRecord
  belongs_to :chromosomal_abnormality
  belongs_to :gene_abnormality
end