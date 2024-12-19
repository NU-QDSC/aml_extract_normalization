require 'pp'

module BeLoadedAsNgsPathologyCasesAndFindings
  class NgsPathologyCasesAndFindingsMatcher
    include RSpec::Matchers::Composable

    attr_reader :failure_message

    def initialize; end

    def matches?(case_name)
      expected_case = YAML.load_file("spec/fixtures/ngs_pathology_cases/#{case_name}.yml")
      expected_case_findings = expected_case.delete("ngs_pathology_case_findings")

      actual_case = NgsPathologyCase.where(accession_nbr_formatted: expected_case["accession_nbr_formatted"])
      unless values_match?(1, actual_case.count)
        @failure_message = "There were #{actual_case.count} NGS Pathology Cases with accession number #{expected_case["accession_nbr_formatted"]}."
        return false
      end

      actual_case = actual_case.first
      actual_attributes = actual_case.attributes.slice(*expected_case.keys)
      actual_attributes.transform_values!{ |v| v.is_a?(Date) ? v.to_s : v }
      unless values_match?(expected_case, actual_attributes)
        diff_attributes = (expected_case.to_a - actual_attributes.to_a).map(&:first)
        @failure_message = <<~MESSAGE
          The attributes of the NGS Pathology Case does not match the expectation.
        
          Expected:
          #{expected_case.slice(*diff_attributes).pretty_inspect}
          
          Actual:
          #{actual_attributes.pretty_inspect}
        MESSAGE
        return false
      end

      expected_case_findings.each do |expected_case_finding|
        unless values_match?(1, actual_case.ngs_pathology_case_findings.where(expected_case_finding).count)
          @failure_message = "The NGS pathology case is missing the following finding: \n#{expected_case_finding.pretty_inspect}"
          return false
        end
      end

      unless values_match?(expected_case_findings.count, actual_case.ngs_pathology_case_findings.count)
        additional_findings = actual_case.ngs_pathology_case_findings.reject do |actual_case_finding|
          expected_case_findings.any? do |expected_case_finding|
            (expected_case_finding.to_a - actual_case_finding.attributes.to_a).empty?
          end
        end
        @failure_message = "The NGS pathology case has found #{additional_findings.count} additional #{'finding'.pluralize(additional_findings.count)}: \n#{additional_findings.pretty_inspect}"
        return false
      end
      return true
    end
  end

  def be_loaded_as_ngs_pathology_cases_and_findings
    NgsPathologyCasesAndFindingsMatcher.new
  end

  def invoke_task(case_name)
    expect(Dir).to receive(:glob).with(anything).once.and_return(["spec/fixtures/ngs_pathology_cases/files/#{case_name.humanize.titleize}.xlsx"])
    task.invoke
  end
end