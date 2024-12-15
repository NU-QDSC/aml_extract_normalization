require 'pp'

module BeLoadedAsNgsPathologyCasesAndFindings
  class NgsPathologyCasesAndFindingsMatcher
    include RSpec::Matchers::Composable

    attr_reader :failure_message

    def initialize; end

    def matches?(case_name)
      expected_case = YAML.load_file("spec/fixtures/ngs_pathology_cases.yml")[case_name]
      unless values_match?(1, NgsPathologyCase.where(expected_case).count)
        @failure_message = "The expected NGS Pathology Case was not loaded: \n#{expected_case.pretty_inspect}"
        return false
      end

      actual_case = NgsPathologyCase.where(expected_case).first
      expected_case_findings = YAML.load_file("spec/fixtures/ngs_pathology_case_findings.yml").select do |k, _|
        k.starts_with?("#{case_name}_case_findings")
      end

      expected_case_findings.each do |_, expected_case_finding|
        expected_case_finding.reject! { |k, _| k ==  "ngs_pathology_case" }
        unless values_match?(1, actual_case.ngs_pathology_case_findings.where(expected_case_finding).count)
          @failure_message = "The NGS pathology case is missing the following finding: \n#{expected_case_finding.pretty_inspect}"
          return false
        end
      end

      unless values_match?(expected_case_findings.count, actual_case.ngs_pathology_case_findings.count)
        additional_findings = actual_case.ngs_pathology_case_findings.reject do |actual_case_finding|
          expected_case_findings.any? do |_, expected_case_finding|
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
    expect(Dir).to receive(:glob).with(anything).once.and_return(["spec/fixtures/files/#{case_name.humanize.titleize}.xlsx"])
    task.invoke
  end
end