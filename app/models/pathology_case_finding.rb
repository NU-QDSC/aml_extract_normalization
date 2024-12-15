class PathologyCaseFinding < ApplicationRecord
  belongs_to :pathology_case
  has_many :pathology_case_finding_normalizations, dependent: :destroy
end