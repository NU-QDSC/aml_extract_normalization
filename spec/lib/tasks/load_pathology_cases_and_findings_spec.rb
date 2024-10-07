require 'rails_helper'

describe 'rake normalizer:load_pathology_cases_and_findings' do
  fixtures 'ngs_pathology_cases', 'ngs_pathology_case_findings'

  after {
    task.invoke
    task.reenable
  }

  it 'loads the fixtures' do
    binding.break
  end
end