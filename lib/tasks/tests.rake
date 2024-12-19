namespace :tests do
  # bundle exec rake tests:extract_fixtures
  desc "extracting data for fixtures"
  task :extract_fixtures => :environment do
    tables=['ngs_pathology_cases', 'ngs_pathology_case_findings']
    extract_fixtures(tables)
  end

  # bundle exec rake tests:create_ngs_pathology_fixture ACCESSION_NBR=00NM-000000000 NAME=next_pathology_example
  desc "saving an NGS Pathology Case example to a new fixture"
  task :create_ngs_pathology_fixture => :environment do #expects case and findings with the given accession number already exist
    require 'rubyXL'
    require 'rubyXL/convenience_methods/cell'
    require 'rubyXL/convenience_methods/workbook'
    require 'rubyXL/convenience_methods/worksheet'

    accession_nbr = ENV["ACCESSION_NBR"]
    raise "Accession Number is a required environment variable" unless accession_nbr

    name = ENV["NAME"]
    raise "Name is a required environment variable" unless name

    ngs_pathology_case = NgsPathologyCase.find_by_accession_nbr_formatted(accession_nbr)
    raise "No NgsPathologyCase found with accession number: #{accession_nbr}" unless ngs_pathology_case

    ignorable_attributes = %w[id created_at updated_at ngs_pathology_case_id gene_position fusion_gene fusion_gene_position]
    fixtures_path = Rails.root.join("spec", "fixtures", "ngs_pathology_cases")

    ngs_pathology_case_attributes = ngs_pathology_case.attributes.except(*ignorable_attributes)
    ngs_pathology_case_attributes.transform_values!{ |v| v.is_a?(Date) ? v.to_s : v }
    ngs_pathology_case_attributes['ngs_pathology_case_findings'] = ngs_pathology_case.ngs_pathology_case_findings
                                                                                     .map(&:attributes)
                                                                                     .map{ |attributes| attributes.except(*ignorable_attributes) }

    File.write(fixtures_path.join("#{name}.yml"), ngs_pathology_case_attributes.to_yaml)

    workbook = RubyXL::Parser.parse(fixtures_path.join("files", "Example Ngs Pathology Case.xlsx"))
    worksheet = workbook[0]
    worksheet[1][0].change_contents(ngs_pathology_case.patient_ir_id) # patient ir id
    worksheet[1][1].change_contents(ngs_pathology_case.west_mrn) # west mrn
    worksheet[1][2].change_contents(ngs_pathology_case.source_system_name) # source system name
    worksheet[1][3].change_contents(ngs_pathology_case.source_system_id) # source system id
    worksheet[1][4].change_contents(ngs_pathology_case.accession_nbr_formatted) # accession nbr formatted
    worksheet[1][5].change_contents(ngs_pathology_case.accessioned_date_key) # accessioned_date_key
    worksheet[1][6].change_contents(ngs_pathology_case.case_collect_date_key) # case collect date key
    worksheet[1][7].change_contents(ngs_pathology_case.group_name) # group name
    worksheet[1][8].change_contents(ngs_pathology_case.group_desc) # group desc
    worksheet[1][9].change_contents(ngs_pathology_case.report_description) # report description
    worksheet[1][10].change_contents(ngs_pathology_case.section_description) # section description
    worksheet[1][11].change_contents(ngs_pathology_case.note_text) # note text
    workbook.write(fixtures_path.join("files", "#{name.humanize.titleize}.xlsx"))
  end
end

def extract_fixtures(tables)
  sql  = "SELECT * FROM %s"
  tables.each do |table_name|
    i = "000"
    File.open("#{Rails.root}/lib/setup/data_out/#{table_name}.yml", 'w' ) do |file|
      data = ActiveRecord::Base.connection.select_all(sql % table_name)
      file.write data.inject({}) { |hash, record|
        hash["#{table_name}_#{i.succ!}"] = record
        hash
      }.to_yaml
    end
  end
end