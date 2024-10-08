RSpec::Matchers.define :be_loaded_as_ngs_pathology_cases_and_findings do
  match do |case_name|
    expect(Dir).to receive(:glob).with(anything).once.and_return(["spec/fixtures/files/#{case_name.to_s.humanize.titleize}.xlsx"])
    task.invoke

    expected_case = YAML.load_file("spec/fixtures/ngs_pathology_cases.yml")[case_name.to_s]
    expect(NgsPathologyCase.where(expected_case).count).to eq 1
    actual_case = NgsPathologyCase.where(expected_case).first

    expected_case_findings = YAML.load_file("spec/fixtures/ngs_pathology_case_findings.yml").select do |k, _|
      k.starts_with?("#{case_name}_case_findings")
    end
    expected_case_findings.each do |_, expected_case_finding|
      expected_case_finding.reject! { |k, _| k ==  "ngs_pathology_case" }
      expect(actual_case.ngs_pathology_case_findings.where(expected_case_finding).count).to eq 1
    end
    expect(actual_case.ngs_pathology_case_findings.count).to eq expected_case_findings.count
  end
end