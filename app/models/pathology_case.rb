class PathologyCase < ApplicationRecord
  has_many :pathology_case_findings
end