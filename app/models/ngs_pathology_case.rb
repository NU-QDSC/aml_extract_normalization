class NgsPathologyCase < ApplicationRecord
  has_many :ngs_pathology_case_findings, dependent: :destroy
end