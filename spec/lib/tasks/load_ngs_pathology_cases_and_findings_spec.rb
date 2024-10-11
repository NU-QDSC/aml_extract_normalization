require 'rails_helper'
require 'support/tasks_helper'
require 'support/be_loaded_as_ngs_pathology_cases_and_findings'

describe 'rake normalizer:load_ngs_pathology_cases_and_findings' do
  include BeLoadedAsNgsPathologyCasesAndFindings

  after {
    task.reenable
  }

  it 'loads the Nm Expanded Solid Tumor Ngs Panel Genomic Signature report' do
    case_name = 'nm_expanded_solid_tumor_ngs_panel_genomic_signature'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end

  it 'loads the Nm Expanded Solid Tumor Ngs Panel Significant Cnv report' do
    case_name = 'nm_expanded_solid_tumor_ngs_panel_significant_cnv'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end

  it 'loads the Nm Expanded Solid Tumor Ngs Panel Significant Snv report' do
    case_name = 'nm_expanded_solid_tumor_ngs_panel_significant_snv'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end

  it 'loads the Pan Heme Ngs Panel Found report' do
    case_name = 'pan_heme_ngs_panel_found'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end

  it 'loads the Pan Heme Ngs Panel None Identified report' do
    case_name = 'pan_heme_ngs_panel_none_identified'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end
end