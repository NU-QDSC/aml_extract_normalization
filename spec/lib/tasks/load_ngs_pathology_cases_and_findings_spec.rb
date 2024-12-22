require 'rails_helper'
require 'support/tasks_helper'
require 'support/be_loaded_as_ngs_pathology_cases_and_findings'

describe 'rake normalizer:load_ngs_pathology_cases_and_findings' do
  include BeLoadedAsNgsPathologyCasesAndFindings

  after {
    task.reenable
  }

  it 'loads the Nm Expanded Solid Tumor Ngs Panel Genomic Signature report', :focuss do
    case_name = 'nm_expanded_solid_tumor_ngs_panel_genomic_signature'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end

  it 'loads the Nm Expanded Solid Tumor Ngs Panel Significant Cnv report', :focuss do
    case_name = 'nm_expanded_solid_tumor_ngs_panel_significant_cnv'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end

  it 'loads the Nm Expanded Solid Tumor Ngs Panel Significant Snv report', :focuss do
    case_name = 'nm_expanded_solid_tumor_ngs_panel_significant_snv'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end

  it 'loads the Nm Expanded Solid Tumor Ngs Panel pertinnt negatives with previous symbols report', :focus do
    case_name = 'nm_expanded_solid_tumor_ngs_panel_pertinent_negative_gene_prev_symbol'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end

  it 'loads the Pan Heme Ngs Panel Found report', :focuss do
    case_name = 'pan_heme_ngs_panel_found'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end

  it 'loads the Pan Heme Ngs Panel None Identified report', :focuss do
    case_name = 'pan_heme_ngs_panel_none_identified'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end

  it 'loads the FusionPlex_Solid_Tumor_Next_Generation_S_one_simple_fusion report', :focuss do
    case_name = 'fusionplex_solid_tumor_next_generation_s_one_simple_fusion'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end

  it 'loads the Fusionplex Solid Tumor Next Generation S report simple case', :focuss do
    case_name = 'FusionPlex_Solid_Tumor_Next_Generation_S_simple_case'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end

  it 'loads the Fusionplex Solid Tumor Next Generation S report simple case with X Chromosome', :focuss do
    case_name = 'FusionPlex_Solid_Tumor_Next_Generation_S_simple_case_X_chromosome'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end

  it 'loads the Fusionplex Solid Tumor Next Generation S report multiple fusions', :focuss do
    case_name = 'FusionPlex_Solid_Tumor_Next_Generation_S_multiple_fusions'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end

  it 'loads the Fusionplex Solid Tumor Next Generation S report multiline', :focuss do
    case_name = 'FusionPlex_Solid_Tumor_Next_Generation_S_multiline'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end

  it 'loads the Fusionplex Solid Tumor Next Generation S report exon variant 1', :focuss do
    case_name = 'FusionPlex_Solid_Tumor_Next_Generation_S_exon1'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end

  it 'loads the Fusionplex Solid Tumor Next Generation S report exon variant 2', :focuss  do
    case_name = 'FusionPlex_Solid_Tumor_Next_Generation_S_exon2'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end

  it 'loads the Fusionplex Solid Tumor Next Generation S report exon variant 3', :focuss do
    case_name = 'FusionPlex_Solid_Tumor_Next_Generation_S_exon3'
    invoke_task(case_name)
    expect(case_name).to be_loaded_as_ngs_pathology_cases_and_findings
  end
end