require 'rails_helper'
require 'support/tasks_helper'
require 'support/load_ngs_pathology_cases_and_findings_matcher'

describe 'rake normalizer:load_ngs_pathology_cases_and_findings' do
  after {
    task.reenable
  }

  it 'loads the Nm Expanded Solid Tumor Ngs Panel Genomic Signature report' do
    expect(:nm_expanded_solid_tumor_ngs_panel_genomic_signature).to be_loaded_as_ngs_pathology_cases_and_findings(task)
  end

  it 'loads the Nm Expanded Solid Tumor Ngs Panel Significant Cnv report' do
    expect(:nm_expanded_solid_tumor_ngs_panel_significant_cnv).to be_loaded_as_ngs_pathology_cases_and_findings(task)
  end

  it 'loads the Nm Expanded Solid Tumor Ngs Panel Significant Snv report' do
    expect(:nm_expanded_solid_tumor_ngs_panel_significant_snv).to be_loaded_as_ngs_pathology_cases_and_findings(task)
  end

  it 'loads the Pan Heme Ngs Panel Found report' do
    expect(:pan_heme_ngs_panel_found).to be_loaded_as_ngs_pathology_cases_and_findings(task)
  end

  it 'loads the Pan Heme Ngs Panel None Identified report' do
    expect(:pan_heme_ngs_panel_none_identified).to be_loaded_as_ngs_pathology_cases_and_findings(task)
  end
end