require 'net/http'
require 'uri'
require 'json'
require 'cgi'

namespace :normalizer do
  # bundle exec rake normalizer:load_vocabulary
  desc "Load vocabulary from HGNC REST API"
  task(load_vocabulary: :environment) do |t, args|
    class HGNCDownloader
      BASE_URL = 'https://rest.genenames.org'
      BATCH_SIZE = 100

      def initialize
        @uri = URI.parse(BASE_URL)
        @http = Net::HTTP.new(@uri.host, @uri.port)
        @http.use_ssl = true
      end

      def fetch_protein_coding_genes
        genes = []
        start = 0

        path = "/fetch/locus_group/#{CGI.escape('protein-coding gene')}"
        response = make_request(path)
        return [] if response.nil?

        data = JSON.parse(response.body)
        total_genes = data['response']['numFound']
        puts "Found #{total_genes} approved protein-coding genes"

        genes.concat(data['response']['docs'])
        start += BATCH_SIZE

        while genes.length < total_genes
          path = "/fetch/locus_group/#{CGI.escape('protein-coding gene')}?start=#{start}"
          response = make_request(path)
          break if response.nil?

          batch = JSON.parse(response.body)['response']['docs']
          break if batch.empty?

          genes.concat(batch)
          puts "Retrieved #{genes.length} of #{total_genes} genes..."
          start += BATCH_SIZE
        end

        genes.select! { |gene| gene['status'] == 'Approved' }
        puts "Found #{genes.length} approved genes after filtering"

        genes
      end

      private

      def make_request(path)
        request = Net::HTTP::Get.new(path, { 'Accept' => 'application/json' })

        begin
          response = @http.request(request)

          if response.code != '200'
            puts "Error: #{response.code} - #{response.body}"
            return nil
          end

          response
        rescue => e
          puts "Request failed: #{e.message}"
          nil
        end
      end
    end

    puts "Cleaning existing data..."
    Gene.delete_all
    GeneSynonym.delete_all

    puts "Fetching genes from HGNC..."
    downloader = HGNCDownloader.new
    genes = downloader.fetch_protein_coding_genes

    if genes.empty?
      puts "No genes were retrieved!"
      exit 1
    end

    puts "\nProcessing gene data..."
    genes_with_details = []
    synonyms_by_gene_index = {}

    genes.each_with_index do |gene_details, index|
      print "Processing gene #{index + 1} of #{genes.length}: #{gene_details['symbol']}\r"

      synonyms = []
      if gene_details['alias_symbol']&.is_a?(Array)
        synonyms += gene_details['alias_symbol'].map { |alias_symbol|
          { synonym_name: alias_symbol, synonym_type: 'symbol' }
        }
      end
      if gene_details['alias_name']&.is_a?(Array)
        synonyms += gene_details['alias_name'].map { |alias_name|
          { synonym_name: alias_name, synonym_type: 'name' }
        }
      end

      synonyms_by_gene_index[index] = synonyms if synonyms.present?

      genes_with_details << {
        hgnc_id: gene_details['hgnc_id'],
        hgnc_symbol: gene_details['symbol'],
        name: gene_details['name'],
        location: gene_details['location'],
        alias_symbol: gene_details['alias_symbol']&.join('|'),
        alias_name: gene_details['alias_name']&.join('|'),
        prev_symbol: gene_details['prev_symbol']&.join('|'),
        prev_name: gene_details['prev_name']&.join('|'),
        gene_group: gene_details['gene_group']&.join('|')
      }
    end
    puts "\n"

    puts "Inserting #{genes_with_details.length} genes into database..."
    genes = Gene.insert_all!(genes_with_details).to_a

    puts "Inserting synonyms..."
    synonym_records = synonyms_by_gene_index.map do |gene_index, synonyms|
      synonyms.map { |synonym| synonym.merge({ gene_id: genes[gene_index]['id'] }) }
    end.flatten

    GeneSynonym.insert_all!(synonym_records)

    puts "Done! Loaded #{genes.length} genes and #{synonym_records.length} synonyms."
  end

  # bundle exec rake normalizer:load_pathology_cases_and_findings
  desc "Load pathology cases and findings"
  task :load_pathology_cases_and_findings, [:west_mrn] => :environment do |t, args|
    puts 'you need to care'
    puts args[:west_mrn]
    directory_path = 'lib/setup/data/normalization_method/llm/'
    files = Dir.glob(File.join(directory_path, '*.xlsx'))
    files = files.sort_by { |file| File.stat(file).mtime }

    load_pathology_cases(files, west_mrn: args[:west_mrn], normalization_method: 'llm')
    load_pathology_findings
  end

  # export ACCESSION_NBR_FORMATTED=''
  # bundle exec rake normalizer:load_fish_pathology_cases_and_findings_regular_expression
  # bundle exec rake normalizer:normalize["fish regular expression"]
  desc "Load FISH pathology cases and findings regular expression"
  task :load_fish_pathology_cases_and_findings_regular_expression, [:west_mrn] => :environment do |t, args|
    puts 'you need to care'
    # puts args[:west_mrn]
    directory_path = Rails.application.credentials.nmedw[Rails.env.to_sym][:files]
    directory_path = "#{directory_path}/STU00220340/"
    # directory_path = 'lib/setup/data/normalization_method/regular_expression/fish'
    files = Dir.glob(File.join(directory_path, 'FISH_pathology*.xlsx'))
    files = files.sort_by { |file| File.stat(file).mtime }
    normalization_method = 'fish regular expression'
    load_pathology_cases_v2(files, west_mrn: args[:west_mrn], normalization_method: normalization_method)
    load_fish_pathology_findings_regular_expression(normalization_method)
  end

  # export ACCESSION_NBR_FORMATTED=''
  # bundle exec rake normalizer:load_cytogenetic_pathology_cases_and_findings_regular_expression
  # bundle exec rake normalizer:normalize["cytogenetic regular expression"]
  desc "Load cytogenetic pathology cases and findings regular expression"
  task :load_cytogenetic_pathology_cases_and_findings_regular_expression, [:west_mrn] => :environment do |t, args|
    puts 'you need to care'
    # puts args[:west_mrn]
    directory_path = Rails.application.credentials.nmedw[Rails.env.to_sym][:files]
    directory_path = "#{directory_path}/STU00220340/"
    files = Dir.glob(File.join(directory_path, 'Cytogenetic_pathology_karyotype*.xlsx'))
    files = files.sort_by { |file| File.stat(file).mtime }

    normalization_method = 'cytogenetic regular expression'
    load_pathology_cases_v2(files, west_mrn: args[:west_mrn], normalization_method: normalization_method)
    load_cytogenetic_pathology_findings_regular_expression(normalization_method)
  end

  # export ACCESSION_NBR_FORMATTED=''
  # bundle exec rake normalizer:load_ngs_pathology_cases_and_findings
  desc "Load NGS pathology cases and findings"
  task :load_ngs_pathology_cases_and_findings, [:west_mrn] => :environment do |t, args|
    puts 'you need to care'
    puts args[:west_mrn]
    directory_path = 'lib/setup/data/ngs/'
    files = Dir.glob(File.join(directory_path, '*.xlsx'))
    files = files.sort_by { |file| File.stat(file).mtime }

    load_ngs_pathology_cases(files, west_mrn: args[:west_mrn])
    load_ngs_pathology_findings
  end

  # export ACCESSION_NBR_FORMATTED=''
  # bundle exec rake normalizer:load_dna_methylation_array_pathology_cases_and_findings
  desc "Load DNA methylation array pathology cases and findings"
  task :load_dna_methylation_array_pathology_cases_and_findings, [:west_mrn] => :environment do |t, args|
    puts 'you need to care'
    puts args[:west_mrn]
    directory_path = 'lib/setup/data/dna_methylation_array/'
    files = Dir.glob(File.join(directory_path, '*.xlsx'))
    files = files.sort_by { |file| File.stat(file).mtime }
    normalization_method = 'dna methylation array'
    load_dna_methylation_array_pathology_cases(files, west_mrn: args[:west_mrn], normalization_method: normalization_method)
    load_dna_methylation_array_pathology_findings
  end

  # export ACCESSION_NBR_FORMATTED=''
  # bundle exec rake normalizer:normalize["fish regular expression"]
  desc "Normalize"
  task :normalize, [:normalization_method] => :environment do |t, args|
    puts 'hello'
    puts args[:normalization_method]
    accession_nbr_formatted = nil
    puts ENV['ACCESSION_NBR_FORMATTED']
    if ENV['ACCESSION_NBR_FORMATTED'].present?
      accession_nbr_formatted = ENV['ACCESSION_NBR_FORMATTED']
    end
    if accession_nbr_formatted
      pathology_cases = PathologyCase.where(accession_nbr_formatted: accession_nbr_formatted).all
      pathology_cases.each do |pathology_case|
        puts pathology_case.pathology_case_findings.size
        pathology_case.pathology_case_findings.each do |pathology_case_finding|
          pathology_case_finding.pathology_case_finding_normalizations.each do |pathology_case_finding_normalization|
            pathology_case_finding_normalization.destroy!
          end
        end
      end
    else
      puts 'hello'
      pathology_cases = PathologyCase.where(normalization_method: args[:normalization_method])
      pathology_cases.each do |pathology_case|
        pathology_case.pathology_case_findings.each do |pathology_case_finding|
          pathology_case_finding.pathology_case_finding_normalizations.delete_all
        end
      end
    end
    puts 'how much?'
    puts pathology_cases.size

    pathology_cases.each do |pathology_case|
      pathology_case.pathology_case_findings.each_with_index do |pathology_case_finding, i|
        if pathology_case_finding.genetic_abnormality_name.present?
          genes = gene_list(pathology_case_finding.genetic_abnormality_name, discard_substrings: true)
          # puts '------------------------'
          # puts 'genetic_abnormality_name'
          # puts pathology_case_finding.genetic_abnormality_name
          genes.each do |gene|
            # puts '||||||||||||||||||||'
            # puts 'gene'
            # puts gene
            gene_abnormalities = []
            gene_abnormalities << { gene: gene, normalization_type: 'gene amplification', normalization: "#{gene} amplification", pre_abnormality_tokens: ['amplification of', 'amplifications of', 'gain of', 'amplification', 'amplifications', 'gain', 'gains'], post_abnormality_tokens: ['amplification','amplifications', 'gain'] }
            gene_abnormalities << { gene: gene, normalization_type: 'gene rearrangement', normalization: "#{gene} rearrangement", pre_abnormality_tokens: ['rearrangement of', 'rearrangements of', 'rearrangement'], post_abnormality_tokens: ['rearrangement', 'rearrangements'] }
            gene_abnormalities << { gene: gene, normalization_type: 'gene deletion', normalization: "#{gene} deletion", pre_abnormality_tokens: ['deletion of', 'deletions of', 'loss of', 'deletion', 'deletions'], post_abnormality_tokens: ['deletion', 'deletions', 'loss', 'losses'] }
            gene_abnormalities << { gene: gene, normalization_type: 'gene translocation', normalization: "#{gene} translocation", pre_abnormality_tokens: ['translocation of', 'translocation'], post_abnormality_tokens: ['translocation'] }

            gene_abnormalities.each do |gene_abnormality|
              regular_expressions = []
              gene_abnormality[:pre_abnormality_tokens].each do |pre_abnormality_token|
                regular_expressions << prepare_interspersed_regex(pre_abnormality_token, gene)
              end
              gene_abnormality[:post_abnormality_tokens].each do |post_abnormality_token|
                regular_expressions << prepare_interspersed_regex(gene, post_abnormality_token)
              end
              normalize_gene_abnormality(pathology_case_finding, regular_expressions, gene_abnormality)
            end
          end
          genes = gene_list(pathology_case_finding.genetic_abnormality_name, discard_substrings: false)
          gene_parings = generate_gene_parings(genes)
          gene_parings.each do |gene_paring|
            normalize_fusion(pathology_case_finding, gene_paring)
          end

          normalize_numerical_chromosomal_abnormality(pathology_case_finding)
          normalize_structural_chromosomal_abnormality(pathology_case_finding)
        end
      end
    end

    PathologyCaseFindingNormalization.select('pathology_case_finding_id, count(*) AS normalization_count').where("gene_1 IS NOT NULL AND normalization_type != 'fusion'").group(:pathology_case_finding_id).having('count(*) > 1').map { |pathology_case_finding_normalization| PathologyCaseFinding.where("id = ? AND genetic_abnormality_name like '%with concurrent%'", pathology_case_finding_normalization.pathology_case_finding_id).first }.compact.each do |pathology_case_finding|
      pathology_case_finding.pathology_case_finding_normalizations.where("gene_1 IS NOT NULL AND normalization_type !='fusion'").group_by { |pathology_case_finding_normalization| pathology_case_finding_normalization.gene_1 }.each do |gene, pathology_case_finding_normalizations|
        before, after = pathology_case_finding.genetic_abnormality_name.split('with concurrent')
        puts 'genetic_abnormality_name'
        puts pathology_case_finding.genetic_abnormality_name
        puts 'before'
        puts before
        puts 'after'
        puts after
        puts 'gene'
        puts gene
        puts 'normalizations'
        pathology_case_finding_normalizations.each do |pathology_case_finding_normalization|
          puts 'normalization_name'
          puts pathology_case_finding_normalization.normalization_name
          puts 'normalization_type'
          puts pathology_case_finding_normalization.normalization_type
          puts 'match_token'
          puts pathology_case_finding_normalization.match_token

          found = [before, after].detect { |match_token| match_token.include?(pathology_case_finding_normalization.match_token) }
          if !found
            puts 'kill me!'
            pathology_case_finding_normalization.destroy!
          else
            puts 'let me live!'
          end
        end
      end
    end
  end

  # bundle exec rake normalizer:compare_gold_standard
  desc "Compare to gold standard"
  task(compare_gold_standard: :environment) do |t, args|
    file = 'lib/setup/data/normalization_gold_standard/gold_normalizations.xlsx'
    gold_normalizations_form_file = Roo::Spreadsheet.open(file)
    gold_normalizations_form_file = gold_normalizations_form_file.sheet(0).to_a
    headers = gold_normalizations_form_file.first
    gold_normalizations = gold_normalizations_form_file.drop(1).map do |row|
      Hash[headers.zip(row)]
    end
    puts gold_normalizations

    file = 'lib/setup/data/normalization_gold_standard/normalizations.xlsx'
    normalizations_form_file = Roo::Spreadsheet.open(file)
    normalizations_form_file = normalizations_form_file.sheet(0).to_a
    headers = normalizations_form_file.first
    normalizations = normalizations_form_file.drop(1).map do |row|
      Hash[headers.zip(row)]
    end
    puts normalizations

    file_path = "lib/setup/data/normalization_gold_standard/normalizations_compared.csv"
    CSV.open(file_path, "w") do |csv|
      headers = normalizations.first.keys

      headers.unshift('status')
      headers.unshift('evaluation')
      headers.unshift('gold_standard_status')
      csv << headers
      normalizations.each do |normalization|
        gold_normalization = gold_normalizations.detect { |gold_normalization| gold_normalization['accession_nbr_formatted'] == normalization['accession_nbr_formatted'] && gold_normalization['genetic_abnormality_name'] == normalization['genetic_abnormality_name'] && gold_normalization['normalization_name'] == normalization['normalization_name'] }
        if gold_normalization
          gold_standard_status = 'match'
          evaluation = gold_normalization['evaluation']
          status= gold_normalization['status']
        else
          gold_standard_status = 'no match'
          gold_normalization = gold_normalizations.detect { |gold_normalization| gold_normalization['accession_nbr_formatted'] == normalization['accession_nbr_formatted'] && gold_normalization['genetic_abnormality_name'] == normalization['genetic_abnormality_name'] }
          evaluation = gold_normalization['evaluation']
          status= gold_normalization['status']
        end
        values = normalization.values
        values.unshift(status)
        values.unshift(evaluation)
        values.unshift(gold_standard_status)
        csv << values
      end
      gold_normalizations.each do |gold_normalization|
        if gold_normalization['normalization_name'].present?
          normalization = normalizations.detect { |normalization| normalization['accession_nbr_formatted'] == gold_normalization['accession_nbr_formatted'] && normalization['genetic_abnormality_name'] == gold_normalization['genetic_abnormality_name'] && normalization['normalization_name'] == gold_normalization['normalization_name'] }
          if normalization
            puts 'gold matched new, nothing to do'
          else
            values = gold_normalization.values
            gold_standard_status = 'no match from gold standard'
            values.unshift(gold_standard_status)
            csv << values
          end
        end
      end
    end
  end

  # bundle exec rake normalizer:extract_fixtures
  desc "extracting data for fixtures"
  task :extract_fixtures => :environment do
    tables=['ngs_pathology_cases', 'ngs_pathology_case_findings']
    extract_fixtures(tables)
  end
  
  # bundle exec rake normalizer:append_ngs_pathology_fixtures ACCESSION_NBR=00NM-000000000 NAME=next_pathology_example
  desc "appending NGS Pathology data to fixtures"
  task :append_ngs_pathology_fixtures => :environment do #expects case and findings with the given accession number already exist
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
    fixtures_path = Rails.root.join("spec","fixtures")
    File.open(fixtures_path.join("ngs_pathology_cases.yml"), "a") do |f|
      ngs_pathology_case_attributes = ngs_pathology_case.attributes.except(*ignorable_attributes)
      ngs_pathology_case_attributes.transform_values!{ |v| v.is_a?(Date) ? v.to_s : v }
      ngs_pathology_case_as_yaml = {
        name => ngs_pathology_case_attributes
      }.to_yaml
      ngs_pathology_case_as_yaml = ngs_pathology_case_as_yaml[4..] # Remove leading ---
      f.write(ngs_pathology_case_as_yaml)
    end

    File.open(fixtures_path.join("ngs_pathology_case_findings.yml"), "a") do |f|
      ngs_pathology_case.ngs_pathology_case_findings.each_with_index do |finding,index|
        ngs_pathology_case_finding_name = '%s_case_findings_%03d' % [name, index + 1]
        ngs_pathology_case_finding_attributes = finding.attributes.except(*ignorable_attributes)
        ngs_pathology_case_finding_attributes = {
          "ngs_pathology_case" => name
        }.merge(ngs_pathology_case_finding_attributes)
        ngs_pathology_case_finding_as_yaml = {
          ngs_pathology_case_finding_name => ngs_pathology_case_finding_attributes
        }.to_yaml
        ngs_pathology_case_finding_as_yaml = ngs_pathology_case_finding_as_yaml[4..] # Remove leading ---
        f.write(ngs_pathology_case_finding_as_yaml)
      end
    end

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

  # export SOURCE_SYSTEM_ID=''
  # bundle exec rake normalizer:load_genetic_counseling_notes_and_findings
  desc "Load Genetic Counseling Notes"
  task(load_genetic_counseling_notes_and_findings: :environment) do |t, args|
    directory_path = 'lib/setup/data/genetic_counseling_notes/'
    files = Dir.glob(File.join(directory_path, '*.xml'))
    files = files.sort_by { |file| File.stat(file).mtime }
    load_genetic_counseling_notes_and_findings(files)
  end
end

def load_pathology_cases(files, options= {})
  puts 'hello'
  accession_nbr_formatted = nil
  puts ENV['ACCESSION_NBR_FORMATTED']
  if ENV['ACCESSION_NBR_FORMATTED'].present?
    accession_nbr_formatted = ENV['ACCESSION_NBR_FORMATTED']
  end

  PathologyCase.where(normalization_method: options[:normalization_method]).destroy_all
  files.each do |file|
    puts file
    pathology_cases = Roo::Spreadsheet.open(file)
    pathology_case_map = {
       'west mrn' => 0,
       'source system' => 1,
       'pathology case key' => 2,
       'pathology case source system id' => 3,
       'accession nbr formatted' => 4,
       'group desc' => 5,
       'snomed code' => 6,
       'snomed name' => 7,
       'accessioned date key' => 8,
       'section description'   => 9,
       'note text' => 10
    }

    for i in 2..pathology_cases.sheet(0).last_row do
      if accession_nbr_formatted.nil? || accession_nbr_formatted == pathology_cases.sheet(0).row(i)[pathology_case_map['accession nbr formatted']]
        pathology_case = PathologyCase.new
        pathology_case.west_mrn = pathology_cases.sheet(0).row(i)[pathology_case_map['west mrn']]
        pathology_case.source_system = pathology_cases.sheet(0).row(i)[pathology_case_map['source system']]
        pathology_case.pathology_case_key = pathology_cases.sheet(0).row(i)[pathology_case_map['pathology case key']]
        pathology_case.pathology_case_source_system_id = pathology_cases.sheet(0).row(i)[pathology_case_map['pathology case source system id']]
        pathology_case.accession_nbr_formatted = pathology_cases.sheet(0).row(i)[pathology_case_map['accession nbr formatted']]
        pathology_case.group_desc = pathology_cases.sheet(0).row(i)[pathology_case_map['group desc']]
        pathology_case.snomed_code = pathology_cases.sheet(0).row(i)[pathology_case_map['snomed code']]
        pathology_case.snomed_name = pathology_cases.sheet(0).row(i)[pathology_case_map['snomed name']]
        pathology_case.accessioned_date_key = pathology_cases.sheet(0).row(i)[pathology_case_map['accessioned date key']]
        pathology_case.section_description = pathology_cases.sheet(0).row(i)[pathology_case_map['section description']]
        pathology_case.note_text = pathology_cases.sheet(0).row(i)[pathology_case_map['note text']]
        pathology_case.normalization_method  = options[:normalization_method]
        pathology_case.save!
      end
    end
  end
end

def load_pathology_cases_v2(files, options= {})
  puts 'hello'
  accession_nbr_formatted = nil
  puts ENV['ACCESSION_NBR_FORMATTED']
  if ENV['ACCESSION_NBR_FORMATTED'].present?
    accession_nbr_formatted = ENV['ACCESSION_NBR_FORMATTED']
  end

  PathologyCase.where(normalization_method: options[:normalization_method]).destroy_all
  files.each do |file|
    puts file
    pathology_cases = Roo::Spreadsheet.open(file)
    pathology_case_map = {
       'west mrn' => 0,
       'source system' => 1,
       'pathology case key' => 2,
       'pathology case source system id' => 3,
       'accession nbr formatted' => 4,
       'group desc' => 5,
       'snomed code' => 6,
       'snomed name' => 7,
       'accessioned date key' => 8,
       'case collect date key' => 9,
       'section description'   => 10,
       'note text' => 11
    }

    for i in 2..pathology_cases.sheet(0).last_row do
      if accession_nbr_formatted.nil? || accession_nbr_formatted == pathology_cases.sheet(0).row(i)[pathology_case_map['accession nbr formatted']]
        pathology_case = PathologyCase.new
        pathology_case.west_mrn = pathology_cases.sheet(0).row(i)[pathology_case_map['west mrn']]
        pathology_case.source_system = pathology_cases.sheet(0).row(i)[pathology_case_map['source system']]
        pathology_case.pathology_case_key = pathology_cases.sheet(0).row(i)[pathology_case_map['pathology case key']]
        pathology_case.pathology_case_source_system_id = pathology_cases.sheet(0).row(i)[pathology_case_map['pathology case source system id']]
        pathology_case.accession_nbr_formatted = pathology_cases.sheet(0).row(i)[pathology_case_map['accession nbr formatted']]
        pathology_case.group_desc = pathology_cases.sheet(0).row(i)[pathology_case_map['group desc']]
        pathology_case.snomed_code = pathology_cases.sheet(0).row(i)[pathology_case_map['snomed code']]
        pathology_case.snomed_name = pathology_cases.sheet(0).row(i)[pathology_case_map['snomed name']]
        pathology_case.accessioned_date_key = pathology_cases.sheet(0).row(i)[pathology_case_map['accessioned date key']]
        pathology_case.case_collect_date_key = pathology_cases.sheet(0).row(i)[pathology_case_map['case collect date key']]
        pathology_case.section_description = pathology_cases.sheet(0).row(i)[pathology_case_map['section description']]
        pathology_case.note_text = pathology_cases.sheet(0).row(i)[pathology_case_map['note text']]
        pathology_case.normalization_method  = options[:normalization_method]
        pathology_case.save!
      end
    end
  end
end

def load_ngs_pathology_cases(files, options= {})
  puts 'hello'
  accession_nbr_formatted = nil
  puts ENV['ACCESSION_NBR_FORMATTED']
  if ENV['ACCESSION_NBR_FORMATTED'].present?
    accession_nbr_formatted = ENV['ACCESSION_NBR_FORMATTED']
  end

  NgsPathologyCase.destroy_all
  files.each do |file|
    puts file
    ngs_pathology_cases = Roo::Spreadsheet.open(file)
    ngs_pathology_case_map = {
       'patient ir id' => 0,
       'west mrn' => 1,
       'source system name' => 2,
       'source system id' => 3,
       'accession nbr formatted' => 4,
       'accessioned date key' => 5,
       'case collect date key' => 6,
       'group name' => 7,
       'group desc' => 8,
       'report description'   => 9,
       'section description' => 10,
       'note text' => 11
    }

    for i in 2..ngs_pathology_cases.sheet(0).last_row do
      if accession_nbr_formatted.nil? || accession_nbr_formatted == ngs_pathology_cases.sheet(0).row(i)[ngs_pathology_case_map['accession nbr formatted']]
        ngs_pathology_case = NgsPathologyCase.new
        ngs_pathology_case.patient_ir_id = ngs_pathology_cases.sheet(0).row(i)[ngs_pathology_case_map['patient ir id']]
        ngs_pathology_case.west_mrn = ngs_pathology_cases.sheet(0).row(i)[ngs_pathology_case_map['west mrn']]
        ngs_pathology_case.source_system_name = ngs_pathology_cases.sheet(0).row(i)[ngs_pathology_case_map['source system name']]
        ngs_pathology_case.source_system_id = ngs_pathology_cases.sheet(0).row(i)[ngs_pathology_case_map['source system id']]
        ngs_pathology_case.accession_nbr_formatted = ngs_pathology_cases.sheet(0).row(i)[ngs_pathology_case_map['accession nbr formatted']]
        ngs_pathology_case.accessioned_date_key = ngs_pathology_cases.sheet(0).row(i)[ngs_pathology_case_map['accessioned date key']]
        ngs_pathology_case.case_collect_date_key = ngs_pathology_cases.sheet(0).row(i)[ngs_pathology_case_map['case collect date key']]
        ngs_pathology_case.group_name = ngs_pathology_cases.sheet(0).row(i)[ngs_pathology_case_map['group name']]
        ngs_pathology_case.group_desc = ngs_pathology_cases.sheet(0).row(i)[ngs_pathology_case_map['group desc']]
        ngs_pathology_case.report_description = ngs_pathology_cases.sheet(0).row(i)[ngs_pathology_case_map['report description']]
        ngs_pathology_case.section_description = ngs_pathology_cases.sheet(0).row(i)[ngs_pathology_case_map['section description']]
        ngs_pathology_case.note_text = ngs_pathology_cases.sheet(0).row(i)[ngs_pathology_case_map['note text']]
        ngs_pathology_case.save!
      end
    end
  end
end

def load_pathology_findings()
  directory_path = 'lib/setup/data/results/'
  results_files = Dir.glob(File.join(directory_path, '*.csv'))
  results_files = results_files.sort_by { |file| File.stat(file).mtime }

  results_files.each do |result_file|
    puts 'begin new pathology case finding file'
    pathology_case_findings = CSV.new(File.open(result_file), headers: true, col_sep: ",", return_headers: false,  quote_char: "\"")

    pathology_case_findings.each do |pathology_case_finding|
      puts 'begin new pathology case finding'
      puts pathology_case_finding['Report Excerpt']

      identiifers = pathology_case_finding['Report Excerpt'].split('__')

      pathology_case = PathologyCase.where(snomed_name: identiifers[0], source_system: identiifers[1], pathology_case_source_system_id: identiifers[2], normalization_method: 'llm')

      if pathology_case.length == 1
        pathology_case = pathology_case.first
        puts 'hello'
        puts pathology_case_finding['Genetic Abnormality Name']
        pcf = PathologyCaseFinding.new
        pcf.pathology_case_id = pathology_case.id
        pcf.genetic_abnormality_name = pathology_case_finding['Genetic Abnormality Name']
        pcf.status = pathology_case_finding['Status']
        pcf.percentage = pathology_case_finding['Percentage']
        pcf.matched_og_phrase = pathology_case_finding['Matched OG Phrase']
        pcf.score = pathology_case_finding['Score']
        pcf.save!
      else
        puts 'We did not find a pathology case!'
      end
    end
  end
end

def load_fish_pathology_findings_regular_expression(normalization_method)
  PathologyCase.where(normalization_method: normalization_method).all.each do |pathology_case|
    puts 'not so much'
    puts pathology_case.note_text
    pathology_case.note_text.split("\n").each do |line|
      puts 'hello'
      if !line.match?(/^\|\|.*\|\|$/)
        status_matches = line.scan(/positive|negative/i)
        if status_matches.any?
          puts line
          if status_matches.size >= 1
            pcf = PathologyCaseFinding.new
            pcf.pathology_case_id = pathology_case.id
            if status_matches.size == 1
              pcf.status = status_matches.first.to_s.upcase
            else
              pcf.status = 'AMBIGIOUS'
            end
            pcf.genetic_abnormality_name = line
            # percentage_matches = line.scan(/\b\d+%/)
            percentage_matches = line.scan(/(\d*\.?\d+)%/)
            if percentage_matches.size >=1
              if percentage_matches.size == 1
                pcf.percentage = percentage_matches.first.first.to_s
              else
                pcf.percentage = percentage_matches.map { |percentage_match| percentage_match.first.to_s }.join('|')
              end
            end
            pcf.matched_og_phrase = line
            pcf.save!
          end
        end
      end
    end
  end
end

def extract_to_regular_expression(text, end_marker)
  # Extract the substring up to the end_marker
  extraction = text.split("\n").take_while { |line| !line.match?(end_marker) }.join("\n")
  extraction.strip
end

def extract_between_regular_expressions(text, start_marker, end_marker)
  # Extract the substring using regular expressions
  if end_marker
    extraction = text.split("\n").drop_while { |line| !line.match?(start_marker) }.drop(1).take_while { |line| !line.match?(end_marker) }.join("\n")
  else
    extraction = text.split(start_marker).last
  end

  extraction.strip
end

def extract_between_regular_expression_and_empty_newline(text, start_marker)
  match_and_fragment = text.split(start_marker, 2)
  if match_and_fragment.size == 2
    extraction = match_and_fragment.last.split(/\n\s*\r?\n/, 2).first.strip
  end
end

def extract_between_regular_expressions_or_empty_newline(text, start_marker, end_markers)
  extraction = nil

  end_markers.each do |end_marker|
    if text.match?(end_marker)
      extraction = extract_between_regular_expressions(text, start_marker, end_marker)
    end
  end

  if extraction.blank?
    extraction = extract_between_regular_expression_and_empty_newline(text, start_marker)
  end
  extraction
end

def extract_accross_lines_between_regular_expressions(text, start_marker, end_marker)
  return text.strip if start_marker.nil? && end_marker.nil?

  if start_marker && end_marker
    # Find the start match
    start_match = text.match(start_marker)
    return "" unless start_match

    # Get the position right after the start match
    start_pos = start_match.end(0)

    # Find the end match, but only in the text after the start match
    remaining_text = text[start_pos..-1]
    end_match = remaining_text.match(end_marker)

    if end_match
      # Extract text between the end of start_marker and start of end_marker
      extraction = remaining_text[0...end_match.begin(0)]
    else
      # If no end marker is found, take all remaining text
      extraction = remaining_text
    end
  elsif start_marker
    # If only start marker is provided, take everything after it
    match = text.match(start_marker)
    extraction = match ? text[match.end(0)..-1] : ""
  else
    # If only end marker is provided, take everything before it
    match = text.match(end_marker)
    extraction = match ? text[0...match.begin(0)] : text
  end

  extraction.strip
end

def determine_version_ngs_pathology_case_cerner_central(note_text, classification_versions)
  version = nil
  classifications_version_2 = classification_versions[:versions].detect { |version|  version[:version] == 2 }
  classifications_version_2_markers = classifications_version_2[:classifications].map { |classification| classification[:marker] }

  classifications_version_1 = classification_versions[:versions].detect { |version|  version[:version] == 1 }
  classifications_version_1_markers = classifications_version_1[:classifications].map { |classification| classification[:marker] }

  if classifications_version_2_markers.detect { |marker| note_text.match?(marker ) }
    version = classifications_version_2
  elsif classifications_version_1_markers.detect { |marker| note_text.match?(marker ) }
    version = classifications_version_1
  end
  version
end

def load_ngs_pathology_findings
  genes = Gene.all.map(&:hgnc_symbol)
  NgsPathologyCase.all.each do |ngs_pathology_case|
    puts 'accession_nbr_formatted'
    puts ngs_pathology_case.accession_nbr_formatted
    puts ngs_pathology_case.group_desc
    case ngs_pathology_case.group_desc
    when 'FusionPlex Solid Tumor Next Generation S'
    puts 'Extracting Fusion...'

    start_marker = Regexp.new('^\s*(Results|Result)\s*', Regexp::IGNORECASE)
    end_marker = Regexp.new('^\s*(Comment|Assay\s*Description)\s*', Regexp::IGNORECASE)

    section_text = extract_between_regular_expressions(ngs_pathology_case.note_text, start_marker, end_marker)

    puts 'Begin section_text:'
    puts section_text
    puts 'End section_text'

    # Approach 2 - more flexible
    fusion_string_is_complete = true
    fusion_string = ''

    section_text.split("\n").each do |line|
      # if (genes.detect { |gene| line.match? Regexp.new("^\s*#{gene}:", Regexp::IGNORECASE) }) || !fusion_string_is_complete #original is faulty because sometimes you have gene and other characters before a colon
      if (genes.detect { |gene| line.match? Regexp.new("^\s*#{gene}.*?:", Regexp::IGNORECASE) }) || !fusion_string_is_complete #original is faulty because sometimes you have gene and other characters before a colon
        # Append current line to fusion string
        fusion_string += line
        # check if the fusion string spans multiple lines
        if !line.match?(/chr/i)
          fusion_string_is_complete = false
          next
        else
          fusion_string_is_complete = true
        end

        if fusion_string_is_complete
          raw_finding = fusion_string
          # Remove new lines from multiline fusion_strings
          fusion_string = fusion_string.gsub("\n","")
          # Replace multiple spaces with a single space in ruby
          fusion_string = fusion_string.gsub(/\s+/," ")
          # Replace multiple colons with a single colon
          fusion_string = fusion_string.gsub('::',':')
          puts 'Fusion String Start'
          puts fusion_string
          puts 'Fusion String End'
          # Extract fusion_breakpoints
          gene_position, fusion_gene_position = fusion_string.scan(/(chr\d+:\d+|chr[XY]:\d+)/i).flatten
          # Extract strings within parenthesis. Some of them contain single exons(e.g ex10) some contain both exons divided by a colon(ex10:ex12) some just need to be discarded
          potential_exons = fusion_string.scan(/\(.*?\)/)
          # Extracting the fusion portion of the string is now trivial. Simply remove all the parhentesis substrings.
          # Extract portion of string containing fusion genes. Initially it will also contain exons
          fusion_genes_substring = fusion_string.scan(/^.*?(?=chr.*)/i)[0]
          # create an empty array for exons
          extracted_exons = []
          potential_exons.each do |potential_exon_substring|
            # Remove parhentesis substrings from fusion_string
            # Escape potential_exon_substring in case it contains special characters
            fusion_genes_substring = fusion_genes_substring.gsub(potential_exon_substring, '')

            # Extract exons
            exons = potential_exon_substring.scan(/\s*ex.*?\d+/i)
            extracted_exons.concat(exons.map(&:downcase))
          end
          #remove extra spaces from fusion_genes_substring
          fusion_genes = fusion_genes_substring.gsub(/\s+/,"")
      
          gene, fusion_gene = fusion_genes.split(':')
          #If it found exons, extract them
          puts 'Exons Extracted Before If Start'
          puts extracted_exons
          puts 'Exons Extracted Before If End'
          if !extracted_exons.empty?
            if extracted_exons.length != 2
              puts 'Exons Extracted Start'
              puts extracted_exons
              puts 'Exons Extracted End'
              # raise 'THERE WAS A PROBLEM EXTRACTING EXONS!'
            else
              puts 'Exons Extracted Start'
              puts extracted_exons
              puts 'Exons Extracted End'
              gene_exon, fusion_gene_exon = extracted_exons
            end
          end

          #write data to model
          ngs_pathology_case_finding = NgsPathologyCaseFinding.new
          ngs_pathology_case_finding.ngs_pathology_case_id = ngs_pathology_case.id
          ngs_pathology_case_finding.raw_finding = fusion_string
          ngs_pathology_case_finding.significance = nil
          ngs_pathology_case_finding.status = 'positive'
          ngs_pathology_case_finding.variant_type = 'Fusion'
      
          ngs_pathology_case_finding.gene = gene
          ngs_pathology_case_finding.fusion_gene = fusion_gene
          ngs_pathology_case_finding.gene_position = gene_position
          ngs_pathology_case_finding.fusion_gene_position = fusion_gene_position

          ngs_pathology_case_finding.variant_name = fusion_genes

          ngs_pathology_case_finding.gene_exon = gene_exon
          ngs_pathology_case_finding.fusion_gene_exon = fusion_gene_exon

          ngs_pathology_case_finding.save!

          # Reset fusion string to blank
          fusion_string = ''
        end
      end
    end

    when 'Pan-Heme NGS Panel', 'NM Expanded Solid Tumor NGS Panel', 'Comprehensive Cancer NGS Panel (NMH/LFH)', 'Lymphoma Cancer NGS Panel (NMH/LFH)'
      classification_version = { version: 1, classifications: [{ significance: 'genomic signature', marker: Regexp.new('^\s*Genomic Signature\s*', Regexp::IGNORECASE)},
                                                               { significance: 'known', marker: Regexp.new('^\s*Variants of known clinical significance\s*', Regexp::IGNORECASE)},
                                                               { significance: 'known or possible', marker: Regexp.new('^\s*Variants of known or potential clinical significance\s*', Regexp::IGNORECASE)},
                                                               { significance: 'unknown', marker: Regexp.new('^\s*Variants of Unknown Significance\s*', Regexp::IGNORECASE) }] }
      puts classification_version[:version]
      case classification_version[:version]
      when 1
        found_classifications = []
        found_classifications = find_classifications(ngs_pathology_case, classification_version)
        germline_classification = { significance: 'germline', marker: Regexp.new('^\s*Variants suspicious for hereditary cancer predisposition:\s*', Regexp::IGNORECASE)}

        section_texts =[]
        found_classifications.each_with_index do |classification, i|
          if found_classifications[i+1]
            section_text = extract_between_regular_expressions(ngs_pathology_case.note_text, classification[:marker], found_classifications[i+1][:marker])
          else
            section_text = extract_between_regular_expressions(ngs_pathology_case.note_text, classification[:marker], nil)
          end
          section_texts << { section_text: section_text, classification: classification }
        end

        section_text_known = section_texts.detect { |section_text| section_text[:classification][:significance] == 'known or possible' || section_text[:classification][:significance] == 'known'  }

        if section_text_known && section_text_known[:section_text].match?(germline_classification[:marker])
          germline_in_known_classification = true
        else
          classification_version = { version: 1, classifications: [{ significance: 'genomic signature', marker: Regexp.new('^\s*Genomic Signature\s*', Regexp::IGNORECASE)},
                                                                   germline_classification,
                                                                   { significance: 'known', marker: Regexp.new('^\s*Variants of known clinical significance\^\s*', Regexp::IGNORECASE)},
                                                                   { significance: 'known or possible', marker: Regexp.new('^\s*Variants of known or potential clinical significance\s*', Regexp::IGNORECASE)},
                                                                   { significance: 'possible', marker: Regexp.new('^\s*Variants of possible clinical significance\^\s*', Regexp::IGNORECASE)},
                                                                   { significance: 'unknown', marker: Regexp.new('^\s*Variants of Unknown (Clinical )?Significance(\^)?\s*', Regexp::IGNORECASE) }] }
          found_classifications = find_classifications(ngs_pathology_case, classification_version)
          germline_in_known_classification = false
        end

        puts 'how many found classifications?'
        puts found_classifications.size
        if found_classifications.any?
          found_classifications.each_with_index do |classification, i|
            if found_classifications[i+1]
              section_text = extract_between_regular_expressions(ngs_pathology_case.note_text, classification[:marker], found_classifications[i+1][:marker])
            else
              section_text = extract_between_regular_expressions(ngs_pathology_case.note_text, classification[:marker], nil)
            end
            if section_text.present?
              puts 'significance section'
              puts  classification[:significance]
              puts 'begin section'
              puts section_text
              puts 'end section'
              subsections = []
              case classification[:significance]
              when 'germline'
                subsections <<  { subsection_text: section_text, variant_type: 'Germline' }
              when 'genomic signature'
                subsections <<  { subsection_text: section_text, variant_type: 'Genomic Signature' }
              when 'known', 'known or possible', 'possible'
                puts 'focus on them'
                markers = []
                markers << snv = { variant_type: 'SNV', trigger: Regexp.new('^\s*Alteration Variant Allele Proportion Drugs Associated with Sensitivity Drugs Associated with Resistance.*$', Regexp::IGNORECASE) }

                if germline_in_known_classification
                  markers << { variant_type: 'Germline', trigger: germline_classification[:marker] }
                end
                markers << { variant_type: 'CNV', trigger: Regexp.new('^Copy Number Variants\s*', Regexp::IGNORECASE) }
                markers << { variant_type: 'Rearrangement', trigger: Regexp.new('^Rearrangements\s*', Regexp::IGNORECASE) }
                markers << pertinent_negative = { variant_type: 'Pertinent Negative', trigger: Regexp.new('^Pertinent Negatives\s*', Regexp::IGNORECASE) }

                found_markers = []
                section_text.each_line.with_index(1) do |line, line_number|
                  markers.each do |marker|
                    if line.match?(marker[:trigger])
                      found_markers << marker.merge(line_number: line_number)
                    end
                  end
                end

                found_markers = found_markers.sort_by { |marker| marker[:line_number] }

                #reject any 'SNV' subsections found if after the first subsection.  Its 'trigger' is resused.
                found_markers.reject!.with_index do |found_marker, i|
                  i > 0 && found_marker[:variant_type] == 'SNV'
                end

                if section_text.match?(/\A\s*none identified\s*(?:\n|\z)/i)
                  if found_markers.none?
                    subsections << { subsection_text: section_text, variant_type: snv[:variant_type] }
                  else
                    subsections << { subsection_text: extract_to_regular_expression(section_text, found_markers.first[:trigger]), variant_type: snv[:variant_type] }
                  end
                end

                found_markers.each_with_index do |start_marker, i|
                  puts 'i'
                  puts i
                  puts 'size'
                  puts found_markers.size
                  if found_markers.size == i+1
                    subsections << { subsection_text: extract_between_regular_expression_and_empty_newline(section_text, start_marker[:trigger]), variant_type: start_marker[:variant_type] }
                  else
                    subsections << { subsection_text: extract_between_regular_expressions(section_text, start_marker[:trigger], found_markers[i+1][:trigger]), variant_type: start_marker[:variant_type] }
                  end
                end
              when 'unknown'
                if section_text.match?(/\s*none identified\s*/i)
                  subsections << { subsection_text: section_text, variant_type: 'SNV' }
                else
                  start_marker = Regexp.new('^\s*Gene Alteration VAF\s*', Regexp::IGNORECASE)
                  end_marker = Regexp.new('^\s*NOTE:', Regexp::IGNORECASE)
                  subsection_text = extract_between_regular_expressions_or_empty_newline(section_text, start_marker, [end_marker])

                  if subsection_text
                    subsections << { subsection_text: extract_between_regular_expressions_or_empty_newline(section_text, start_marker, [end_marker]), variant_type: 'SNV', declaration_type: 'single-line' }
                  end

                  if subsection_text.blank?
                    start_marker = Regexp.new('^\s*Alteration Variant Allele Proportion Drugs Associated with Sensitivity Drugs Associated with Resistance\s*', Regexp::IGNORECASE)
                    end_marker = Regexp.new('^\s*NOTE:', Regexp::IGNORECASE)
                    subsection_text = extract_between_regular_expressions_or_empty_newline(section_text, start_marker, [end_marker])

                    if subsection_text
                      subsections << { subsection_text: extract_between_regular_expressions_or_empty_newline(section_text, start_marker, [end_marker]), variant_type: 'SNV', declaration_type: 'multiline' }
                    end
                  end
                end
              end
              puts 'come on guy'
              subsections.each do |subsection|
                puts 'significance subsection'
                puts  classification[:significance]
                puts 'begin subsection'
                puts subsection[:variant_type]
                puts subsection[:subsection_text]
                puts 'end subsection'

                if subsection[:subsection_text].match?(/\s*none identified\s*/i)
                  puts 'hey ugo'
                  ngs_pathology_case_finding = NgsPathologyCaseFinding.new
                  ngs_pathology_case_finding.ngs_pathology_case_id = ngs_pathology_case.id
                  ngs_pathology_case_finding.variant_type = subsection[:variant_type]
                  ngs_pathology_case_finding.significance = classification[:significance]
                  ngs_pathology_case_finding.status = 'none identified'
                  ngs_pathology_case_finding.save!
                else
                  case classification[:significance]
                  when 'germline'
                    parse_germline(classification, ngs_pathology_case, subsection[:subsection_text], genes)
                  when 'genomic signature'
                    case subsection[:variant_type]
                    when
                      parse_genomic_signature(classification, ngs_pathology_case, subsection, genes)
                    end
                  when 'known', 'known or possible', 'possible'
                    case subsection[:variant_type]
                    when 'SNV'
                      parse_snv(classification, ngs_pathology_case, subsection, genes)
                    when 'CNV'
                      parse_cnv(classification, ngs_pathology_case, subsection, genes)
                    when 'Rearrangement'
                      parse_rearrangement(classification, ngs_pathology_case, subsection, genes)
                    when 'Pertinent Negative'
                      parse_pertinent_negative(classification, ngs_pathology_case, subsection, genes)
                    when 'Germline'
                      parse_germline(classification, ngs_pathology_case, subsection[:subsection_text], genes)
                    end
                  when 'unknown'
                    case subsection[:declaration_type]
                    when 'multiline'
                      parse_snv(classification, ngs_pathology_case, subsection, genes)
                    when 'single-line'
                      subsection[:subsection_text].split("\n").each do |variant|
                        ngs_pathology_case_finding = NgsPathologyCaseFinding.new
                        ngs_pathology_case_finding.ngs_pathology_case_id = ngs_pathology_case.id
                        ngs_pathology_case_finding.raw_finding = variant
                        ngs_pathology_case_finding.significance = classification[:significance]
                        ngs_pathology_case_finding.status = 'found'
                        variant_components = variant.split(' ').compact

                        puts 'gene'
                        puts variant_components[0]
                        if variant_components[0].present?
                          ngs_pathology_case_finding.gene = variant_components[0]
                        end

                        puts 'variant_name'
                        puts variant_components[1]
                        if variant_components[1].present?
                          ngs_pathology_case_finding.variant_name = variant_components[1]
                        end

                        ngs_pathology_case_finding.variant_type = subsection[:variant_type]
                        puts 'allelic frequency raw'
                        allelic_frequency_raw = variant_components[2]
                        puts allelic_frequency_raw
                        if allelic_frequency_raw.present?
                          percentage_matches = allelic_frequency_raw.scan(/(\d*\.?\d+)%/)
                          if percentage_matches.size >=1
                            if percentage_matches.size == 1
                              allelic_frequency = percentage_matches.first.first.to_s
                            else
                              allelic_frequency = percentage_matches.map { |percentage_match| percentage_match.first.to_s }.join('|')
                            end
                          end
                          puts 'allelic_frequency'
                          puts allelic_frequency
                          if allelic_frequency
                            ngs_pathology_case_finding.allelic_frequency = allelic_frequency
                          end
                        end
                        ngs_pathology_case_finding.save!
                      end
                    end
                  end
                end
              end
            end
          end
        else
          ngs_pathology_case_finding = NgsPathologyCaseFinding.new
          ngs_pathology_case_finding.ngs_pathology_case_id = ngs_pathology_case.id
          ngs_pathology_case_finding.status = 'insufficient'
          ngs_pathology_case_finding.save!
        end
      end
    when 'Myeloid Neoplasms NGS Panel'
      classification_version = { version: 1, classifications: [ { significance: 'known', marker: Regexp.new('^*\sThese variants of known clinical significance', Regexp::IGNORECASE)},
                                                                              { significance: 'possible', marker: Regexp.new('^*\sThese variants of possible clinical significance', Regexp::IGNORECASE)},
                                                                              { significance: 'unknown', marker: Regexp.new('^*\sThese variants of unknown clinical significance', Regexp::IGNORECASE)}] }
      puts classification_version[:version]
      case classification_version[:version]
      when 1
        found_classifications = []
        ngs_pathology_case.note_text.split("\n").each do |line|
          classification_version[:classifications].each do |classification|
            if line.match?(classification[:marker])
              found_classifications << classification
            end
          end
        end
        puts 'how many found found_classifications'
        puts found_classifications.size

        if found_classifications.any?
          found_classifications.each_with_index do |classification, i|
            if found_classifications[i+1]
              section_text = extract_between_regular_expressions(ngs_pathology_case.note_text, classification[:marker], found_classifications[i+1][:marker])
            else
              section_text = extract_between_regular_expressions(ngs_pathology_case.note_text, classification[:marker], nil)
            end

            if section_text.present?
              start_marker =  Regexp.new('^\s*Gene Amino Acid Change Coding Allele Frequency Transcript\s*', Regexp::IGNORECASE)
              subsection_text = extract_between_regular_expression_and_empty_newline(section_text, start_marker)
              puts 'begin subsection'
              puts subsection_text
              puts 'end subsection'
              if subsection_text.match?(/\s*none identified/i)
                ngs_pathology_case_finding = NgsPathologyCaseFinding.new
                ngs_pathology_case_finding.ngs_pathology_case_id = ngs_pathology_case.id
                ngs_pathology_case_finding.significance = classification[:significance]
                ngs_pathology_case_finding.status = 'none identified'
                ngs_pathology_case_finding.save!
              else
                subsection_text.split("\n").each do |variant|
                  puts 'hello variant'
                  puts variant
                  variant_components = variant.split(' ').compact
                  variant_components.reject!(&:empty?)
                  if variant_components.any?
                    if !['note', 'cancer', 'include', 'reports', 'pmid', 'indicated', 'cytogenetics'].detect{ |stop_phrase| variant.match?(Regexp.new("#{stop_phrase}", Regexp::IGNORECASE)) }
                      ngs_pathology_case_finding = NgsPathologyCaseFinding.new
                      ngs_pathology_case_finding.ngs_pathology_case_id = ngs_pathology_case.id
                      ngs_pathology_case_finding.raw_finding = variant
                      ngs_pathology_case_finding.significance = classification[:significance]
                      ngs_pathology_case_finding.status = 'found'

                      if variant_components.size > 5 && variant_components[1].downcase == 'splice' && variant_components[2].downcase == 'site'
                        variant_components[0] = "#{variant_components[0]} Splice site".strip
                        variant_components[1] = variant_components[3]
                        variant_components.delete_at(2)
                      end

                      if variant_components.size == 5
                        puts 'gene'
                        puts variant_components[0]
                        if variant_components[0].present?
                          ngs_pathology_case_finding.gene = variant_components[0]
                        end

                        puts 'variant_name'
                        puts variant_components[1]
                        if variant_components[1].present?
                          ngs_pathology_case_finding.variant_name = variant_components[1]
                        end

                        puts 'allelic_frequency raw'
                        puts variant_components[3]
                        if variant_components[3].present?
                          percentage_matches = variant_components[3].scan(/(\d*\.?\d+)%/)
                          if percentage_matches.size >=1
                            if percentage_matches.size == 1
                              allelic_frequency = percentage_matches.first.first.to_s
                            else
                              allelic_frequency = percentage_matches.map { |percentage_match| percentage_match.first.to_s }.join('|')
                            end
                          end
                          puts 'allelic_frequency'
                          puts allelic_frequency
                          if allelic_frequency
                            ngs_pathology_case_finding.allelic_frequency = allelic_frequency
                          end
                        end

                        puts 'transcript'
                        puts variant_components[4]
                        if variant_components[4].present?
                          ngs_pathology_case_finding.transcript = variant_components[4]
                        end
                      end
                    end

                    if variant_components.size == 5 || genes.any? { |gene| variant.match?(Regexp.new("^#{gene}", Regexp::IGNORECASE)) }
                      ngs_pathology_case_finding.save!
                    end
                  end
                end
              end
            end
          end
        else
          ngs_pathology_case_finding = NgsPathologyCaseFinding.new
          ngs_pathology_case_finding.ngs_pathology_case_id = ngs_pathology_case.id
          ngs_pathology_case_finding.status = 'insufficient'
          ngs_pathology_case_finding.save!
        end
      end
    when 'Molecular Genetics'
      classification_versions = { versions: [{ version: 1, classifications: [ { significance: 'known', marker: Regexp.new('^Variants of known clinical significance', Regexp::IGNORECASE)},
                                                                   { significance: 'possible', marker: Regexp.new('^Variants of possible clinical significance', Regexp::IGNORECASE)},
                                                                   { significance: 'unknown', marker: Regexp.new('^Variants of unknown clinical significance', Regexp::IGNORECASE)}]},
                                            { version: 2, classifications: [ { significance: 'known', marker: Regexp.new('^These variants of known clinical significance', Regexp::IGNORECASE)},
                                                                  { significance: 'possible', marker: Regexp.new('^These variants of possible clinical significance', Regexp::IGNORECASE)},
                                                                  { significance: 'unknown', marker: Regexp.new('^These variants of unknown clinical significance', Regexp::IGNORECASE)}] }]}

      classification_version = determine_version_ngs_pathology_case_cerner_central(ngs_pathology_case.note_text, classification_versions)
      if classification_version.present?
        puts 'we have a version'
        puts classification_version[:version]
        case classification_version[:version]
        when 1
          puts 'hello version 1'
          found_classifications = []
          ngs_pathology_case.note_text.split("\n").each do |line|
            classification_version[:classifications].each do |classification|
              if line.match?(classification[:marker])
                found_classifications << classification
              end
            end
          end
          puts 'how many found found_classifications'
          puts found_classifications.size
          found_classifications.each_with_index do |classification, i|
            if found_classifications[i+1]
              section_text = extract_between_regular_expressions(ngs_pathology_case.note_text, classification[:marker], found_classifications[i+1][:marker])
            else
              section_text = extract_between_regular_expressions(ngs_pathology_case.note_text, classification[:marker], nil)
            end
            if section_text.match?(/\s*none/i)
              ngs_pathology_case_finding = NgsPathologyCaseFinding.new
              ngs_pathology_case_finding.ngs_pathology_case_id = ngs_pathology_case.id
              ngs_pathology_case_finding.significance = classification[:significance]
              ngs_pathology_case_finding.status = 'none identified'
              ngs_pathology_case_finding.save!
            else
              puts 'this is the section text'
              puts section_text
              section_text.split(/\n\s*\r?\n/, -1).each do |variant|
                puts 'this is the variant'
                puts variant
                variant_components = variant.split("\n")
                if variant_components.any?
                  ngs_pathology_case_finding = NgsPathologyCaseFinding.new
                  ngs_pathology_case_finding.ngs_pathology_case_id = ngs_pathology_case.id
                  ngs_pathology_case_finding.raw_finding = variant
                  ngs_pathology_case_finding.significance = classification[:significance]
                  ngs_pathology_case_finding.status = 'found'
                  if variant_components.size == 4
                    puts 'gene'
                    puts variant_components[0]
                    if variant_components[0].present?
                      ngs_pathology_case_finding.gene = variant_components[0]
                    end

                    puts 'variant_name'
                    puts variant_components[1]
                    if variant_components[1].present?
                      ngs_pathology_case_finding.variant_name = variant_components[1]
                    end

                    puts 'transcript'
                    puts variant_components[2]
                    if variant_components[2].present?
                      ngs_pathology_case_finding.transcript = variant_components[2]
                    end

                    puts 'allelic_frequency raw'
                    puts variant_components[3]
                    if variant_components[3].present?
                      percentage_matches = variant_components[3].scan(/(\d*\.?\d+)%/)
                      if percentage_matches.size >=1
                        if percentage_matches.size == 1
                          allelic_frequency = percentage_matches.first.first.to_s
                        else
                          allelic_frequency = percentage_matches.map { |percentage_match| percentage_match.first.to_s }.join('|')
                        end
                      end
                      puts 'allelic_frequency'
                      puts allelic_frequency
                      if allelic_frequency
                        ngs_pathology_case_finding.allelic_frequency = allelic_frequency
                      end
                    end
                  end
                  ngs_pathology_case_finding.save!
                end
              end
            end
          end
        when 2
          puts 'hello version 2'
          found_classifications = []
          ngs_pathology_case.note_text.split("\n").each do |line|
            classification_version[:classifications].each do |classification|
              if line.match?(classification[:marker])
                found_classifications << classification
              end
            end
          end
          puts 'how many found found_classifications'
          puts found_classifications.size
          found_classifications.each_with_index do |classification, i|
            if found_classifications[i+1]
              section_text = extract_between_regular_expressions(ngs_pathology_case.note_text, classification[:marker], found_classifications[i+1][:marker])
            else
              section_text = extract_between_regular_expressions(ngs_pathology_case.note_text, classification[:marker], nil)
            end

            if section_text.present?
              start_marker =  Regexp.new('^Gene Amino Acid Change Coding Allele\s+Frequency Transcript', Regexp::IGNORECASE)
              subsection_text = extract_between_regular_expression_and_empty_newline(section_text, start_marker)
              puts 'begin subsection'
              puts subsection_text
              puts 'end subsection'
              if subsection_text.match?(/^\s*none/i)
                ngs_pathology_case_finding = NgsPathologyCaseFinding.new
                ngs_pathology_case_finding.ngs_pathology_case_id = ngs_pathology_case.id
                ngs_pathology_case_finding.significance = classification[:significance]
                ngs_pathology_case_finding.status = 'none identified'
                ngs_pathology_case_finding.save!
              else
                subsection_text.split("\n").each do |variant|
                  variant_components = variant.split(' ')

                  if variant_components.any? && genes.any? { |gene| variant.match?(Regexp.new("^\s*#{gene}", Regexp::IGNORECASE)) }
                    ngs_pathology_case_finding = NgsPathologyCaseFinding.new
                    ngs_pathology_case_finding.ngs_pathology_case_id = ngs_pathology_case.id
                    ngs_pathology_case_finding.raw_finding = variant
                    ngs_pathology_case_finding.significance = classification[:significance]
                    ngs_pathology_case_finding.status = 'found'
                    if variant_components.size == 5
                      puts 'gene'
                      puts variant_components[0]
                      if variant_components[0].present?
                        ngs_pathology_case_finding.gene = variant_components[0]
                      end

                      puts 'variant_name'
                      puts variant_components[1]
                      if variant_components[1].present?
                        ngs_pathology_case_finding.variant_name = variant_components[1]
                      end

                      puts 'allelic_frequency raw'
                      puts variant_components[3]
                      if variant_components[3].present?
                        percentage_matches = variant_components[3].scan(/(\d*\.?\d+)%/)
                        if percentage_matches.size >=1
                          if percentage_matches.size == 1
                            allelic_frequency = percentage_matches.first.first.to_s
                          else
                            allelic_frequency = percentage_matches.map { |percentage_match| percentage_match.first.to_s }.join('|')
                          end
                        end
                        puts 'allelic_frequency'
                        puts allelic_frequency
                        if allelic_frequency
                          ngs_pathology_case_finding.allelic_frequency = allelic_frequency
                        end
                      end

                      puts 'transcript'
                      puts variant_components[4]
                      if variant_components[4].present?
                        ngs_pathology_case_finding.transcript = variant_components[4]
                      end
                    end
                    ngs_pathology_case_finding.save!
                  end
                end
              end
            end
          end
        end
      else
        ngs_pathology_case_finding = NgsPathologyCaseFinding.new
        ngs_pathology_case_finding.ngs_pathology_case_id = ngs_pathology_case.id
        ngs_pathology_case_finding.status = 'insufficient'
        ngs_pathology_case_finding.save!
      end
    end
  end
end

def load_cytogenetic_pathology_findings_regular_expression(normalization_method)
  puts 'hello'
  accession_nbr_formatted = nil
  puts ENV['ACCESSION_NBR_FORMATTED']
  if ENV['ACCESSION_NBR_FORMATTED'].present?
    accession_nbr_formatted = ENV['ACCESSION_NBR_FORMATTED']
  end

  if accession_nbr_formatted
    pathology_cases = PathologyCase.where(normalization_method: normalization_method, accession_nbr_formatted: accession_nbr_formatted).all
  else
    pathology_cases = PathologyCase.where(normalization_method: normalization_method).all
  end

  pathology_cases.all.each do |pathology_case|
    puts 'not so much'
    puts pathology_case.note_text
    sections = pathology_case.note_text.split(/\|\|.*?\|\|/)
    sections.reject!(&:empty?)
    inadequate_triggers = ['see comments', 'see interpretation']
    inadequate = inadequate_triggers.any? { |inadequate_trigger| sections[0].downcase.include?(inadequate_trigger) }

    puts 'are we inadequate?'
    puts inadequate

    if !inadequate
      karyotypes = sections[0].gsub(/^\s+|\s+$/, '')
      clones = karyotypes.scan(/^(.*?):\s*(.*(?:\n(?!.*:).*)*)/)
      puts 'how many clones?'
      puts clones.size

      if clones.any?
        idem_sex = nil
        idem_tokens = []
        clones.each do |clone|
          puts 'have a clone'
          puts clone
          pcf = PathologyCaseFinding.new
          clone_name = clone[0].strip
          clone[1].strip!
          subclones = clone[1].split('/')

          puts 'how many subclones?'
          puts subclones.size
          if subclones.size == 1
            cell_count = clone[1].scan(/(?<!in)c?\[([^\]]+)\]$/m)
            puts 'cell_count'
            puts cell_count
            if cell_count.any?
              cell_count = cell_count.first.first.strip.gsub('cp','')
            end
            clone[1] = clone[1].sub(/(?<!in)c?\[.*\]$/, '')
            tokens = clone[1].split(',')

            chromosome_count = tokens.shift.strip
            sex = tokens.shift
            if sex
              sex.strip!
              if sex == 'idem'
                tokens.concat(idem_tokens)
                sex = idem_sex
              else
                idem_sex = sex
              end
              if tokens.any?
                tokens.each do |token|
                  idem_tokens << token.strip
                end
              end
            end
            if tokens.any?
              tokens.each do |token|
                puts 'we have a token'
                puts token
                PathologyCaseFinding.where(pathology_case_id: pathology_case.id, clone_name: clone_name, cell_count: cell_count, chromosome_count: chromosome_count, sex: sex, genetic_abnormality_name: token.strip).first_or_create
              end
            else
              pcf = PathologyCaseFinding.new
              pcf.pathology_case_id = pathology_case.id
              pcf.clone_name = clone_name
              pcf.cell_count = cell_count
              pcf.chromosome_count = chromosome_count
              pcf.sex = sex
              pcf.save!
            end
          else
            subclones.each_with_index do |subclone, i|
              puts 'we have a subclone'
              puts subclone
              cell_count = subclone.scan(/(?<!in)c?\[([^\]]+)\]$/m)
              puts 'cell_count'
              puts cell_count
              if cell_count.any?
                cell_count = cell_count.first.first.strip.gsub('cp', '')
              end
              subclone = subclone.sub(/(?<!in)c?\[.*\]$/, '')
              tokens = subclone.split(',').compact
              if tokens.any?
                chromosome_count = tokens.shift.try(:strip)
                sex = tokens.shift.try(:strip)
                if sex == 'idem'
                  tokens.concat(idem_tokens)
                  sex = idem_sex
                else
                  idem_sex = sex
                end
                if tokens.any?
                  tokens.each do |token|
                    idem_tokens << token.strip
                  end
                end
              end
              puts 'what am i'
              puts i
              if i > 0
                subclone = true
              else
                subclone = false
              end
              if tokens.any?
                tokens.each do |token|
                  PathologyCaseFinding.where(pathology_case_id: pathology_case.id, clone_name: clone_name, cell_count: cell_count, chromosome_count: chromosome_count, sex: sex, genetic_abnormality_name: token.strip, subclone: subclone).first_or_create
                end
              else
                pcf = PathologyCaseFinding.new
                pcf.pathology_case_id = pathology_case.id
                pcf.clone_name = clone_name
                pcf.cell_count = cell_count
                pcf.chromosome_count = chromosome_count
                pcf.sex = sex
                pcf.subclone = subclone
                pcf.save!
              end
            end
          end
        end
      else
        idem_sex = nil
        idem_tokens = []
        clones = sections[0].split("\n")
        clones.reject!(&:empty?)
        clones.each do |clone|
          clone.strip!
          clone_name = nil
          cell_count = clone.scan(/(?<!in)c?\[([^\]]+)\]$/m)

          if cell_count.any?
            cell_count = cell_count.first.first.gsub('cp','')
          end
          tokens = clone.sub(/(?<!in)c?\[.*\]$/, '').split(',')
          chromosome_count = tokens.shift
          sex = tokens.try(:shift)
          if sex == 'idem'
            tokens.concat(idem_tokens)
            sex = idem_sex
          else
            idem_sex = sex
          end
          if tokens.any?
            tokens.each do |token|
              idem_tokens << token.strip
            end
          end
          if tokens.any?
            tokens.each do |token|
              PathologyCaseFinding.where(pathology_case_id: pathology_case.id, clone_name: "Implicit Clone: #{token.try(:strip)}", cell_count: cell_count, chromosome_count: chromosome_count, sex: sex, genetic_abnormality_name: token.try(:strip), subclone: false).first_or_create
            end
          else
            pcf = PathologyCaseFinding.new
            pcf.pathology_case_id = pathology_case.id
            pcf.clone_name = clone
            pcf.cell_count = cell_count
            pcf.chromosome_count = chromosome_count
            pcf.sex = sex
            pcf.subclone = false
            pcf.save!
          end
        end
      end
    end
  end
end

def match_genetic_abnormality_target_file(target, genetic_abnormality_input_file)
  threshold_result = nil
  genetic_abnormality_target_file = 'lib/setup/data/fuzzy_matcher/genetic_abnormality_target_file.txt'
  File.open(genetic_abnormality_target_file, 'w') do |file|
    file.write(target)
  end

  matched_threshold_file = 'lib/setup/data/fuzzy_matcher/matched_threshold.txt'
  result = system("python lib/fuzzy_matcher/fuzzy_matcher.py #{genetic_abnormality_input_file} #{genetic_abnormality_target_file} #{matched_threshold_file}")
  if result
    threshold_result = File.read(matched_threshold_file)
  else
    puts "Python script execution failed."
  end
  threshold_result
end

def prepare_interspersed_regex(token_1, token_2)
  Regexp.new("\\b#{token_1}\\b(?:\(.*?\))?\\b#{token_2}\\b", Regexp::IGNORECASE)
end

def normalize_gene_abnormality(pathology_case_finding, regular_expressions, gene_abnormality)
  puts 'normalize_gene_abnormality'
  puts gene_abnormality
  regular_expressions.each do |regular_expression|
    m = pathology_case_finding.genetic_abnormality_name.match(regular_expression)
    if m
      pathology_case_finding.pathology_case_finding_normalizations.where(normalization_name: gene_abnormality[:normalization], normalization_type: gene_abnormality[:normalization_type], gene_1: gene_abnormality[:gene], match_token: m.to_s).first_or_create
      # pathology_case_finding.save!
      puts 'got you gene abnormality!'
    end
  end
end

def normalize_fusion(pathology_case_finding, gene_paring)
  fusion_delimiters = ['::', ':', '-', '/']
  fusion_delimiters.each do |fusion_delimiter|
    normalization = "#{gene_paring.first}::#{gene_paring.last} fusion"
    expression_1 = "#{gene_paring.first}" + '\s*' + "#{fusion_delimiter}" + '\s*' + "#{gene_paring.last}"
    regular_expression_1 = Regexp.new(expression_1, Regexp::IGNORECASE)

    m = pathology_case_finding.genetic_abnormality_name.match(regular_expression_1)
    if m
      pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: normalization, normalization_type: 'fusion', gene_1: gene_paring.first, gene_2: gene_paring.last, match_token: m.to_s)
      pathology_case_finding.save!
      puts 'got you fusion!'
    else
     fusion_delimiters = ['::', ':', '-']
      expression_2 = '\b' + "#{gene_paring.first}" + '\b\s*\([^)]*\)' + "#{fusion_delimiter}" +'\s*\b' + "#{gene_paring.last}" +'\b\s*\([^)]*\)'
      regular_expression_2 = Regexp.new(expression_2, Regexp::IGNORECASE)
      m = pathology_case_finding.genetic_abnormality_name.match(regular_expression_2)
      if m
        pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: normalization, normalization_type: 'fusion', gene_1: gene_paring.first, gene_2: gene_paring.last, match_token: m.to_s)
        pathology_case_finding.save!
        puts 'got you fusion 2!'
      end
    end
  end
end

def normalize_numerical_chromosomal_abnormality(pathology_case_finding)
  chromosomes = (0..22).to_a
  chromosomes.push('X')
  chromosomes.push('Y')
  chromosomes.each do |chromosome|
    normalization = "#{chromosome} monosomy"
    regular_expressions = []
    expression = '(?<!\w|\d)\-' + chromosome.to_s + '\b'
    regular_expressions << Regexp.new(expression, Regexp::IGNORECASE)
    ['monosomy', 'loss', 'losses', 'deletion', 'deletions', 'deletion of the long arm of', 'deletion of the short arm of'].each do |abnormality|
      expression = '\b' + abnormality + '(?: of)?(?: Chromosome)?(?: Chromosomes)?\s*' + chromosome.to_s+ '\b'
      puts expression
      regular_expressions << Regexp.new(expression, Regexp::IGNORECASE)
    end

    ['monosomy', 'loss', 'deletion', 'deletions'].each do |abnormality|
      expression = '\b' + '(?: Chromosome)?(?: Chromosome)?\s*' + chromosome.to_s + '\s*'+ abnormality +'\b'
      puts expression
      regular_expressions << Regexp.new(expression, Regexp::IGNORECASE)
    end

    regular_expressions.each do |regular_expression|
      m = pathology_case_finding.genetic_abnormality_name.match(regular_expression)
      if m
        pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: normalization, normalization_type: 'numerical chromosomal', match_token: m.to_s)
        pathology_case_finding.save!
        puts 'got you numerical_chromosomal_abnormality 1!'
      end
    end

    ['monosomy', 'loss', 'losses', 'deletion', 'deletions', 'deletion of the long arm of', 'deletion of the short arm of'].each do |abnormality|
      chromosomes.each do |other_chromosome|
        expression = '\b' + abnormality + '(?: of)?(?: Chromosomes)?\s*' + chromosome.to_s + '\s*and\s*' + other_chromosome.to_s + '\b'
        puts 'new guy'
        puts expression
        regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
        m = pathology_case_finding.genetic_abnormality_name.match(regular_expression)
        if m
          other_normalization = "#{other_chromosome} monosomy"
          pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: other_normalization, normalization_type: 'numerical chromosomal', match_token: m.to_s)
          pathology_case_finding.save!
          puts 'got you numerical_chromosomal_abnormality 1!'
        end
      end
    end

    normalization = "#{chromosome} trisomy"
    regular_expressions = []
    expression = '(?<!\w|\d)\+' + chromosome.to_s + '\b'
    regular_expressions << Regexp.new(expression, Regexp::IGNORECASE)

    ['trisomy', 'gain', 'gains', 'addition', 'additions'].each do |abnormality|
      expression = '\b' + abnormality + '(?: of)?(?: Chromosome)?(?: Chromosomes)?\s*' + chromosome.to_s+ '\b'
      regular_expressions << Regexp.new(expression, Regexp::IGNORECASE)
    end

    ['trisomy', 'gain', 'gains', 'addition', 'additions'].each do |abnormality|
      expression = '\b' + '(?: Chromosome)?(?: Chromosome)?\s*' + chromosome.to_s + '\s*'+ abnormality +'\b'
      regular_expressions << Regexp.new(expression, Regexp::IGNORECASE)
    end

    regular_expressions.each do |regular_expression|
      m = pathology_case_finding.genetic_abnormality_name.match(regular_expression)
      if m
        pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: normalization, normalization_type: 'numerical chromosomal', match_token: m.to_s)
        pathology_case_finding.save!
        puts 'got you numerical_chromosomal_abnormality 2!'
      end
    end

    ['trisomy', 'gain', 'gains', 'addition', 'additions'].each do |abnormality|
      chromosomes.each do |other_chromosome|
        expression = '\b' + abnormality + '(?: of)?(?: Chromosomes)?\s*' + chromosome.to_s + '\s*and\s*' + other_chromosome.to_s + '\b'
        puts 'new guy'
        puts expression
        regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
        m = pathology_case_finding.genetic_abnormality_name.match(regular_expression)
        if m
          other_normalization = "#{other_chromosome} trisomy"
          pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: other_normalization, normalization_type: 'numerical chromosomal', match_token: m.to_s)
          pathology_case_finding.save!
          puts 'got you numerical_chromosomal_abnormality 1!'
        end
      end
    end
  end
end

def normalize_structural_chromosomal_abnormality(pathology_case_finding)
  genes = gene_list(pathology_case_finding.genetic_abnormality_name, discard_substrings: true)
  #addition
  genetic_abnormality_name = pathology_case_finding.genetic_abnormality_name.dup
  genes.each do |gene|
    genetic_abnormality_name.gsub!(" #{gene}", '')
    genetic_abnormality_name.gsub!("/#{gene}", '')
    puts 'genetic_abnormality_name'
    puts genetic_abnormality_name
  end

  if genes.empty?
    normalize_structural_chromosomal_abnormality_addition(pathology_case_finding, pathology_case_finding.genetic_abnormality_name)
  else
    normalize_structural_chromosomal_abnormality_addition(pathology_case_finding, genetic_abnormality_name)
  end

  #deletion
  genetic_abnormality_name = pathology_case_finding.genetic_abnormality_name.dup
  genes.each do |gene|
    genetic_abnormality_name.gsub!(" #{gene}", '')
    genetic_abnormality_name.gsub!("/#{gene}", '')
    puts 'genetic_abnormality_name'
    puts genetic_abnormality_name
  end

  if genes.empty?
    normalize_structural_chromosomal_abnormality_deletion(pathology_case_finding, pathology_case_finding.genetic_abnormality_name)
  else
    normalize_structural_chromosomal_abnormality_deletion(pathology_case_finding, genetic_abnormality_name)
  end

  #derivation
  expression = '\bder\((?:[0-9]|1[0-9]|2[0-2]|X|Y)[\.\w]*\)'
  regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
  matches = pathology_case_finding.genetic_abnormality_name.scan(regular_expression)
  matches.each do |match|
    pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: match.to_s, normalization_type: 'structural chromosomal derivation', match_token: match.to_s)
    pathology_case_finding.save!
    puts 'got you normalize_structural_chromosomal_abnormality derivation!'
  end

  expression = 'der\(((?:2[0-2]|[01]?[0-9]|X|Y)[\w.]*;(?:(?:2[0-2]|[01]?[0-9]|X|Y)[\w.]*))\)'
  regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
  matches = pathology_case_finding.genetic_abnormality_name.scan(regular_expression)
  matches.each do |match|
    pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: "der(#{match.first.to_s})", normalization_type: 'structural chromosomal translocation', match_token: "der(#{match.first.to_s})")
    pathology_case_finding.save!
    puts 'got you normalize_structural_chromosomal_abnormality translocation!'
  end

  #dicentric chromosome
  expression = 'dic\(((?:2[0-2]|[01]?[0-9]|X|Y)[\w.]*;(?:(?:2[0-2]|[01]?[0-9]|X|Y)[\w.]*))\)'
  regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
  matches = pathology_case_finding.genetic_abnormality_name.scan(regular_expression)
  matches.each do |match|
    pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: "dic(#{match.first.to_s})", normalization_type: 'structural chromosomal translocation', match_token: "dic(#{match.first.to_s})")
    pathology_case_finding.save!
    puts 'got you normalize_structural_chromosomal_abnormality dicentric chromosome!'
  end

  #duplication
  expression = '\bdup\((?:[0-9]|1[0-9]|2[0-2]|X|Y)[\.\w]*\)'
  regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
  matches = pathology_case_finding.genetic_abnormality_name.scan(regular_expression)
  matches.each do |match|
    pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: match.to_s, normalization_type: 'structural chromosomal inversion', match_token: match.to_s)
    pathology_case_finding.save!
    puts 'got you normalize_structural_chromosomal_abnormality duplication!'
  end

  #inversion
  expression = '\binv\((?:[0-9]|1[0-9]|2[0-2]|X|Y)[\.\w]*\)'
  regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
  matches = pathology_case_finding.genetic_abnormality_name.scan(regular_expression)
  matches.each do |match|
    pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: match.to_s, normalization_type: 'structural chromosomal inversion', match_token: match.to_s)
    pathology_case_finding.save!
    puts 'got you normalize_structural_chromosomal_abnormality inversion!'
  end

  #translocation
  expression = 't\(((?:2[0-2]|[01]?[0-9]|X|Y)[\w.]*;(?:(?:2[0-2]|[01]?[0-9]|X|Y)[\w.]*))\)'
  regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
  matches = pathology_case_finding.genetic_abnormality_name.scan(regular_expression)
  matches.each do |match|
    pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: "t(#{match.first.to_s})", normalization_type: 'structural chromosomal translocation', match_token: "t(#{match.first.to_s})")
    pathology_case_finding.save!
    puts 'got you normalize_structural_chromosomal_abnormality translocation!'
  end
end

def normalize_structural_chromosomal_abnormality_addition(pathology_case_finding, genetic_abnormality_name)
  #prefix abnormality with structure in parentheses
  addition_synonyms = ['addition', 'additions', 'addition of', 'gain', 'gains', 'gain of', 'add'].each do |addition_synonym|
    expression = '\b' + addition_synonym + '\s*\(((2[0-2]|[01]?[0-9]|X|Y)(?![0-9])|(p|q)\d+)[\w.]*\)'
    puts 'expression'
    puts expression
    regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
    m = genetic_abnormality_name.match(regular_expression)
    if m
      if addition_synonym == 'add'
        normalization_name = m.to_s.downcase
      else
        regular_expression = Regexp.new(addition_synonym + '\s*', Regexp::IGNORECASE)
        normalization_name = m.to_s.downcase.gsub(regular_expression, 'add')
      end
      pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: normalization_name, normalization_type: 'structural chromosomal addition', match_token: m.to_s)
      pathology_case_finding.save!
      puts 'got you normalize_structural_chromosomal_abnormality addition!'
      puts 'here is the id'
      puts pathology_case_finding.pathology_case_finding_normalizations.last.id
    end
  end

  #prefix abnormality with structure not in parentheses
  addition_synonyms = ['addition', 'additions', 'addition of', 'gain', 'gains', 'gain of', 'add'].each do |addition_synonym|
    expression = '(\b|\))' + addition_synonym +'\s*(2[0-2]|[01]?[0-9]|X|Y)(?![0-9])[\w.]*\s*' + '(\b|\()'
    puts 'expression'
    puts expression
    regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
    genetic_abnormality_name.match(regular_expression)
    m = genetic_abnormality_name.match(regular_expression)
    if m
      if addition_synonym == 'add'
        normalization_name = m.to_s.downcase.gsub(regular_expression, 'add')
        add, chromosome  =  m.to_s.downcase.split('add')
        normalization_name = "add(#{chromosome})"
      else
        regular_expression = Regexp.new(addition_synonym, Regexp::IGNORECASE)
        normalization_name = m.to_s.downcase.gsub(regular_expression, 'add')
        add, chromosome  = normalization_name.split(' ')
        normalization_name = "#{add}(#{chromosome})"
      end

      pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: normalization_name, normalization_type: 'structural chromosomal addition', match_token: m.to_s)
      pathology_case_finding.save!
      puts 'got you normalize_structural_chromosomal_abnormality addition!'
    end
  end

  #postfix abnormality with structure not in parentheses
  addition_synonyms = ['add', 'addition', 'gain'].each do |addition_synonym|
    expression = '(\b|\))\s*(2[0-2]|[01]?[0-9]|X|Y)(?![0-9])[\w.]*\s*' + addition_synonym + '(\b|\))'
    puts 'expression'
    puts expression
    regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
    genetic_abnormality_name.match(regular_expression)
    m = genetic_abnormality_name.match(regular_expression)
    if m
      if addition_synonym == 'add'
        normalization_name = m.to_s
        chromosome, add = normalization_name.split('add')
        chromosome.gsub!('(', '')
        chromosome.gsub!(' ', '')
        normalization_name = "add(#{chromosome})"
      else
        regular_expression = Regexp.new(addition_synonym + '\s*', Regexp::IGNORECASE)
        normalization_name = m.to_s.downcase.gsub(regular_expression, 'add')
        chromosome, add = normalization_name.split(' ')
        chromosome.gsub!('(', '')
        normalization_name = "#{add}(#{chromosome})"
      end
      pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: normalization_name, normalization_type: 'structural chromosomal addition', match_token: m.to_s)
      pathology_case_finding.save!
      pathology_case_finding_normalization = pathology_case_finding.pathology_case_finding_normalizations.last

      puts 'got you normalize_structural_chromosomal_abnormality addition!'
    end
  end
end

def normalize_structural_chromosomal_abnormality_deletion(pathology_case_finding, genetic_abnormality_name)
  #prefix abnormality with structure in parentheses
  deletion_synonyms = ['deletion', 'deletions', 'deletion of', 'deletions of', 'loss', 'loss of', 'del'].each do |deletion_synonym|
    expression = '\b' + deletion_synonym + '\s*\(((2[0-2]|[01]?[0-9]|X|Y)(?![0-9])|(p|q)\d+)[\w.]*\)'
    puts 'expression'
    puts expression
    regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
    m = genetic_abnormality_name.match(regular_expression)
    if m
      if deletion_synonym == 'del'
        normalization_name = m.to_s.downcase
      else
        regular_expression = Regexp.new(deletion_synonym + '\s*', Regexp::IGNORECASE)
        normalization_name = m.to_s.downcase.gsub(regular_expression, 'del')
      end
      pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: normalization_name, normalization_type: 'structural chromosomal deletion', match_token: m.to_s)
      pathology_case_finding.save!
      puts 'got you normalize_structural_chromosomal_abnormality deletion!'
    end
  end

  #prefix abnormality with structure not in parentheses
  deletion_synonyms = ['deletion', 'deletions', 'deletion of', 'deletions of', 'deletion of chromosome', 'deletion of long arm of chromosome', 'deletion of short arm of chromosome', 'loss', 'loss of', 'del'].each do |deletion_synonym|
    expression = '(\b|\))' + deletion_synonym +'\s*(2[0-2]|[01]?[0-9]|X|Y)(?![0-9])[\w.]*\s*'+ '(\b|\()'
    puts 'expression'
    puts expression
    regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
    genetic_abnormality_name.match(regular_expression)
    m = genetic_abnormality_name.match(regular_expression)
    if m
      if deletion_synonym == 'del'
        normalization_name = m.to_s.downcase.gsub(regular_expression, 'del')
        del, chromosome  =  m.to_s.downcase.split('del')
        normalization_name = "del(#{chromosome})"
      else
        regular_expression = Regexp.new(deletion_synonym, Regexp::IGNORECASE)
        normalization_name = m.to_s.downcase.gsub(regular_expression, 'del')
        del,chromosome  = normalization_name.split(' ')
        normalization_name = "#{del}(#{chromosome})"
      end

      pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: normalization_name, normalization_type: 'structural chromosomal deletion', match_token: m.to_s)
      pathology_case_finding.save!
      puts 'got you normalize_structural_chromosomal_abnormality deletion!'
    end
  end

  #postfix abnormality with structure not in parentheses
  deletion_synonyms = ['deletion', 'deletions', 'loss'].each do |deletion_synonym|
    expression = '(\b|\))\s*(2[0-2]|[01]?[0-9]|X|Y)(?![0-9])[\w.]*\s*' + deletion_synonym + '(\b|\))'
    puts 'expression'
    puts expression
    regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
    genetic_abnormality_name.match(regular_expression)
    m = genetic_abnormality_name.match(regular_expression)
    if m
      regular_expression = Regexp.new(deletion_synonym + '\s*', Regexp::IGNORECASE)
      normalization_name = m.to_s.downcase.gsub(regular_expression, 'del')
      chromosome, del = normalization_name.split(' ')
      normalization_name = "#{del}(#{chromosome})"
      pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: normalization_name, normalization_type: 'structural chromosomal deletion', match_token: m.to_s)
      pathology_case_finding.save!
      puts 'got you normalize_structural_chromosomal_abnormality deletion!'
    end
  end

  #postfix abnormality with structure in parentheses
  deletion_synonyms = ['deletion', 'deletions', 'loss'].each do |deletion_synonym|
    expression = '\b\s*\((2[0-2]|[01]?[0-9]|X|Y)(?![0-9])[\w.]*\)\s*' + deletion_synonym + '\b'
    puts 'expression'
    puts expression
    regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
    genetic_abnormality_name.match(regular_expression)
    m = genetic_abnormality_name.match(regular_expression)
    if m
      regular_expression = Regexp.new(deletion_synonym + '\s*', Regexp::IGNORECASE)
      normalization_name = m.to_s.downcase.gsub(regular_expression, 'del')
      chromosome, del = normalization_name.split(' ')
      normalization_name = "#{del}#{chromosome}"
      pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: normalization_name, normalization_type: 'structural chromosomal deletion', match_token: m.to_s)
      pathology_case_finding.save!
      puts 'got you normalize_structural_chromosomal_abnormality deletion!'
    end
  end
end

def gene_list(genetic_abnormality_name, options = {})
  options = { discard_substrings: false }.merge(options)
  genes = Gene.where("? LIKE '%' || hgnc_symbol || '%'", genetic_abnormality_name).map{ |gene| gene.hgnc_symbol }
  if options[:discard_substrings]
    genes.sort_by!(&:length)
    genes = genes.reject do |gene|
      genes.any? { |other| other != gene && other.include?(gene) }
    end
  end

  ['MLL', 'AML1', 'EVI1', 'D20S108', 'D7S486', 'D13S319', 'D5S721', 'S7S486'].each do |dna_marker|
    expression = "#{dna_marker}"
    regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
    if genetic_abnormality_name.match(regular_expression)
      genes.push(dna_marker)
    end
  end

  genes
end

def generate_gene_parings(genes)
  pairings = []
  genes.each do |first_gene|
    genes.each do |second_gene|
      next if first_gene == second_gene
      pairings << [first_gene, second_gene]
    end
  end
  pairings
end

def load_dna_methylation_array_pathology_cases(files, options= {})
  puts 'hello'
  accession_nbr_formatted = nil
  puts ENV['ACCESSION_NBR_FORMATTED']
  if ENV['ACCESSION_NBR_FORMATTED'].present?
    accession_nbr_formatted = ENV['ACCESSION_NBR_FORMATTED']
  end

  DnaMethylationArrayPathologyCase.destroy_all
  files.each do |file|
    puts file
    pathology_cases = Roo::Spreadsheet.open(file)
    pathology_case_map = {
       'west mrn' => 0,
       'source system' => 1,
       'pathology case source system id' => 2,
       'accession nbr formatted' => 3,
       'group desc' => 4,
       'snomed code' => 5,
       'snomed name' => 6,
       'accessioned date key' => 7,
       'case collect date key' => 8,
       'section description'   => 9,
       'note text' => 10
    }

    for i in 2..pathology_cases.sheet(0).last_row do
      if pathology_cases.sheet(0).row(i)[pathology_case_map['accessioned date key']] >= Date.parse('2021-11-29')
        if accession_nbr_formatted.nil? || accession_nbr_formatted == pathology_cases.sheet(0).row(i)[pathology_case_map['accession nbr formatted']]
          pathology_case = DnaMethylationArrayPathologyCase.new
          pathology_case.west_mrn = pathology_cases.sheet(0).row(i)[pathology_case_map['west mrn']]
          pathology_case.source_system = pathology_cases.sheet(0).row(i)[pathology_case_map['source system']]
          pathology_case.pathology_case_source_system_id = pathology_cases.sheet(0).row(i)[pathology_case_map['pathology case source system id']]
          pathology_case.accession_nbr_formatted = pathology_cases.sheet(0).row(i)[pathology_case_map['accession nbr formatted']]
          pathology_case.group_desc = pathology_cases.sheet(0).row(i)[pathology_case_map['group desc']]
          pathology_case.snomed_code = pathology_cases.sheet(0).row(i)[pathology_case_map['snomed code']]
          pathology_case.snomed_name = pathology_cases.sheet(0).row(i)[pathology_case_map['snomed name']]
          pathology_case.accessioned_date_key = pathology_cases.sheet(0).row(i)[pathology_case_map['accessioned date key']]
          pathology_case.case_collect_date_key = pathology_cases.sheet(0).row(i)[pathology_case_map['case collect date key']]
          pathology_case.section_description = pathology_cases.sheet(0).row(i)[pathology_case_map['section description']]
          pathology_case.note_text = pathology_cases.sheet(0).row(i)[pathology_case_map['note text']]
          pathology_case.save!
        end
      end
    end
  end
end

def load_dna_methylation_array_pathology_findings
  DnaMethylationArrayPathologyCase.all.each do |dna_methylation_array_pathology_case|
    puts dna_methylation_array_pathology_case.group_desc
    puts dna_methylation_array_pathology_case.section_description
    case dna_methylation_array_pathology_case.section_description

    when 'Final Diagnosis'
      section_text_specimen = extract_between_regular_expressions(dna_methylation_array_pathology_case.note_text, 'Specimen', 'Result')
      if section_text_specimen
        puts 'here is the section_text_specimen begin'
        puts section_text_specimen
        puts 'here is the section_text_specimen end'

        match = section_text_specimen.match(/specimen\s+(.*?),/)

        if match
          associated_accession_nbr_formatted = match[1]
          puts "Captured associated_accession_nbr_formatted: #{associated_accession_nbr_formatted}"
          if associated_accession_nbr_formatted.size >= 5
            dna_methylation_array_pathology_case.associated_accession_nbr_formatted = associated_accession_nbr_formatted
          end
          # puts associated_accession_nbr_formatted.size
        else
          puts "No match found"
        end

        match = section_text_specimen.match(/block\s+(.*?)\s/)

        if match
          associated_accession_nbr_formatted_block = match[1]
          puts "Captured associated_accession_nbr_formatted_block: #{associated_accession_nbr_formatted_block}"
          associated_accession_nbr_formatted_block = associated_accession_nbr_formatted_block.split(',').first
          dna_methylation_array_pathology_case.associated_accession_nbr_formatted_block = associated_accession_nbr_formatted_block
          # puts associated_accession_nbr_formatted_block.size
        else
          puts "No match found"
        end

        match = section_text_specimen.match(/estimated\s+(\d+(?:\.\d+)?)%\s+tumor\s+cells/)
        if match
          associated_accession_nbr_formatted_block_tumor_percentage = match[1]
          begin
            associated_accession_nbr_formatted_block_tumor_percentage = Integer(associated_accession_nbr_formatted_block_tumor_percentage)
            associated_accession_nbr_formatted_block_tumor_percentage = associated_accession_nbr_formatted_block_tumor_percentage/100.to_f
          rescue Exception => e
            associated_accession_nbr_formatted_block_tumor_percentage = nil
          end

          puts "Captured associated_accession_nbr_formatted_block_tumor_percentage: #{associated_accession_nbr_formatted_block_tumor_percentage.to_s}"
          if associated_accession_nbr_formatted_block_tumor_percentage
            # puts associated_accession_nbr_formatted_block_tumor_percentage.to_s.size
            dna_methylation_array_pathology_case.associated_accession_nbr_formatted_block_tumor_percentage = associated_accession_nbr_formatted_block_tumor_percentage
          end
        else
          puts "No match found"
        end
        dna_methylation_array_pathology_case.save!
      end

      section_text_result = extract_between_regular_expressions(dna_methylation_array_pathology_case.note_text, 'Result', 'Comment')

      if section_text_result.blank?
        section_text_result = extract_between_regular_expressions(dna_methylation_array_pathology_case.note_text, 'Final Diagnosis', 'Comment')
      end

      puts 'here is the section_text_result begin'
      puts section_text_result
      puts 'here is the section_text_result end'

      if section_text_result.present?
        start_marker = Regexp.new('^Methylation Class\s+Score\s+Interpretation', Regexp::IGNORECASE)
        subsection_text_methylation_class = extract_between_regular_expression_and_empty_newline(section_text_result, start_marker)

        if subsection_text_methylation_class
          puts 'begin section_text_result begin subsection_text_methylation_class'
          puts subsection_text_methylation_class
          puts 'end section_text_result begin subsection_text_methylation_class'
          subsection_text_methylation_class.split("\n").each do |line|
            line.strip!
            puts 'got a line'
            puts line
            methylation_class = nil
            score = nil
            interpretation = nil
            if line =~ /^no match/i
              methylation_class = 'no match'
              score = '0'
              interpretation = 'no match'
            elsif line =~ /(\d+\.\d+)\s+((?:no\s+)?match)$/i
              puts 'take a look'
              score = $1
              interpretation = $2
              methylation_class = line.sub(/\s+#{Regexp.escape(score)}\s+#{Regexp.escape(interpretation)}$/i, '').strip
            end
            puts 'begin methylation_class'
            puts methylation_class
            puts 'end methylation_class'

            puts 'begin score'
            puts score
            puts 'end score'

            puts 'begin interpretation'
            puts interpretation
            puts 'end interpretation'

            if methylation_class.present?
             dna_methylation_array_pathology_case_finding = DnaMethylationArrayPathologyCaseFinding.new
             dna_methylation_array_pathology_case_finding.dna_methylation_array_pathology_case_id = dna_methylation_array_pathology_case.id
             dna_methylation_array_pathology_case_finding.methylation_class = methylation_class.strip
             # t.string "methylation_subclass"
             dna_methylation_array_pathology_case_finding.score = score.strip
             dna_methylation_array_pathology_case_finding.interpretation = interpretation.strip
             dna_methylation_array_pathology_case_finding.save!
            end
          end
        end

        start_marker = Regexp.new('^Methylation Subclass Score Interpretation', Regexp::IGNORECASE)
        subsection_text_methylation_subclass = extract_between_regular_expression_and_empty_newline(section_text_result, start_marker)

        if subsection_text_methylation_subclass
          puts 'begin section_text_result begin subsection_text_methylation_subclass'
          puts subsection_text_methylation_subclass
          puts 'end section_text_result begin subsection_text_methylation_subclass'

          subsection_text_methylation_subclass.split("\n").each do |line|
            line.strip!
            puts 'got a line'
            puts line
            methylation_subclass = nil
            score = nil
            interpretation = nil
            if line =~ /^no match/i
              methylation_subclass = 'no match'
              score = '0'
              interpretation = 'no match'
            elsif line =~ /(\d+\.\d+)\s+((?:no\s+)?match)$/i
              puts 'take a look'
              score = $1
              interpretation = $2
              methylation_subclass = line.sub(/\s+#{Regexp.escape(score)}\s+#{Regexp.escape(interpretation)}$/i, '').strip
            end
            puts 'begin methylation_subclass'
            puts methylation_subclass
            puts 'end methylation_subclass'

            puts 'begin score'
            puts score
            puts 'end score'

            puts 'begin interpretation'
            puts interpretation
            puts 'end interpretation'

            if methylation_subclass.present?
             dna_methylation_array_pathology_case_finding = DnaMethylationArrayPathologyCaseFinding.new
             dna_methylation_array_pathology_case_finding.dna_methylation_array_pathology_case_id = dna_methylation_array_pathology_case.id
             dna_methylation_array_pathology_case_finding.methylation_subclass = methylation_subclass.strip
             dna_methylation_array_pathology_case_finding.score = score.strip
             dna_methylation_array_pathology_case_finding.interpretation = interpretation.strip
             dna_methylation_array_pathology_case_finding.save!
            end
          end
        end
      end
    when 'Specimen'
      puts 'here is the section_text_specimen begin'
      puts dna_methylation_array_pathology_case.note_text
      puts 'here is the section_text_specimen end'

      match = dna_methylation_array_pathology_case.note_text.match(/formalin-fixed paraffin embedded [specimen]*\s*(.*?)\s*,*\s/i)

      if match
        associated_accession_nbr_formatted = match[1]
        puts "Captured associated_accession_nbr_formatted: #{associated_accession_nbr_formatted}"
        if associated_accession_nbr_formatted.size >= 5
          dna_methylation_array_pathology_case.associated_accession_nbr_formatted = associated_accession_nbr_formatted
        end
        # puts associated_accession_nbr_formatted.size
      else
        puts "No match found"
      end

      match = dna_methylation_array_pathology_case.note_text.match(/,\s+block\s+(.*?)\s/)

      if match
        associated_accession_nbr_formatted_block = match[1]
        associated_accession_nbr_formatted_block = associated_accession_nbr_formatted_block.split(',').first
        puts "Captured associated_accession_nbr_formatted_block: #{associated_accession_nbr_formatted_block}"
        dna_methylation_array_pathology_case.associated_accession_nbr_formatted_block = associated_accession_nbr_formatted_block
        # puts associated_accession_nbr_formatted_block.size
      else
        puts "No match found"
      end

      match = dna_methylation_array_pathology_case.note_text.match(/estimated\s+(\d+(?:\.\d+)?)%\s+tumor\s+cells/)
      if match
        associated_accession_nbr_formatted_block_tumor_percentage = match[1]
        begin
          associated_accession_nbr_formatted_block_tumor_percentage = Integer(associated_accession_nbr_formatted_block_tumor_percentage)
          associated_accession_nbr_formatted_block_tumor_percentage = associated_accession_nbr_formatted_block_tumor_percentage/100.to_f
        rescue Exception => e
          associated_accession_nbr_formatted_block_tumor_percentage = nil
        end

        puts "Captured associated_accession_nbr_formatted_block_tumor_percentage: #{associated_accession_nbr_formatted_block_tumor_percentage.to_s}"
        if associated_accession_nbr_formatted_block_tumor_percentage
          # puts associated_accession_nbr_formatted_block_tumor_percentage.to_s.size
          dna_methylation_array_pathology_case.associated_accession_nbr_formatted_block_tumor_percentage = associated_accession_nbr_formatted_block_tumor_percentage
        end
      else
        puts "No match found"
      end
      dna_methylation_array_pathology_case.save!
    when 'Pathology Interpretation'
      section_text_result = extract_between_regular_expressions(dna_methylation_array_pathology_case.note_text, 'Result', 'Comment')

      puts 'here is the section_text_result begin'
      puts section_text_result
      puts 'here is the section_text_result end'

      if section_text_result.present?
        if section_text_result.match(/not sufficient|insufficient/i).present?
          dna_methylation_array_pathology_case_finding = DnaMethylationArrayPathologyCaseFinding.new
          dna_methylation_array_pathology_case_finding.dna_methylation_array_pathology_case_id = dna_methylation_array_pathology_case.id
          dna_methylation_array_pathology_case_finding.interpretation = 'insufficient'
          dna_methylation_array_pathology_case_finding.save!
        else
          start_marker =  Regexp.new('^Methylation Class\s+Score\s+Interpretation', Regexp::IGNORECASE)
          subsection_text_methylation_class = extract_between_regular_expression_and_empty_newline(section_text_result, start_marker)
          if subsection_text_methylation_class.present?
            puts 'begin section_text_result begin subsection_text_methylation_class'
            puts subsection_text_methylation_class
            puts 'end section_text_result begin subsection_text_methylation_class'
             subsection_text_methylation_class.split("\n").each do |line|
               line.strip!
               puts 'got a line'
               puts line
               methylation_class = nil
               score = nil
               interpretation = nil
               if line =~ /^no match/i
                 methylation_class = 'no match'
                 score = '0'
                 interpretation = 'no match'
               elsif line =~ /(\d+\.\d+)\s+((?:no\s+)?match)$/i
                 puts 'take a look'
                 score = $1
                 interpretation = $2
                 methylation_class = line.sub(/\s+#{Regexp.escape(score)}\s+#{Regexp.escape(interpretation)}$/i, '').strip
               end
               puts 'begin methylation_class'
               puts methylation_class
               puts 'end methylation_class'

               puts 'begin score'
               puts score
               puts 'end score'

               puts 'begin interpretation'
               puts interpretation
               puts 'end interpretation'

               if methylation_class.present?
                 dna_methylation_array_pathology_case_finding = DnaMethylationArrayPathologyCaseFinding.new
                 dna_methylation_array_pathology_case_finding.dna_methylation_array_pathology_case_id = dna_methylation_array_pathology_case.id
                 dna_methylation_array_pathology_case_finding.methylation_class = methylation_class.strip
                 # t.string "methylation_subclass"
                 dna_methylation_array_pathology_case_finding.score = score.strip
                 dna_methylation_array_pathology_case_finding.interpretation = interpretation.strip
                 dna_methylation_array_pathology_case_finding.save!
               end
             end
          end
          start_marker =  Regexp.new('^Methylation Subclass Score Interpretation', Regexp::IGNORECASE)
          subsection_text_methylation_subclass = extract_between_regular_expression_and_empty_newline(section_text_result, start_marker)
          if subsection_text_methylation_subclass
            puts 'begin section_text_result begin subsection_text_methylation_subclass'
            puts subsection_text_methylation_subclass
            puts 'end section_text_result begin subsection_text_methylation_subclass'
            subsection_text_methylation_subclass.split("\n").each do |line|
              line.strip!
              puts 'got a line'
              puts line
              methylation_subclass = nil
              score = nil
              interpretation = nil
              if line =~ /^no match/i
                methylation_class = 'no match'
                score = '0'
                interpretation = 'no match'
              elsif line =~ /(\d+\.\d+)\s+((?:no\s+)?match)$/i
                puts 'take a look'
                score = $1
                interpretation = $2
                methylation_subclass = line.sub(/\s+#{Regexp.escape(score)}\s+#{Regexp.escape(interpretation)}$/i, '').strip
              end
              puts 'begin methylation_subclass'
              puts methylation_subclass
              puts 'end methylation_subclass'

              puts 'begin score'
              puts score
              puts 'end score'

              puts 'begin interpretation'
              puts interpretation
              puts 'end interpretation'

              if methylation_subclass.present?
               dna_methylation_array_pathology_case_finding = DnaMethylationArrayPathologyCaseFinding.new
               dna_methylation_array_pathology_case_finding.dna_methylation_array_pathology_case_id = dna_methylation_array_pathology_case.id
               dna_methylation_array_pathology_case_finding.methylation_subclass = methylation_subclass.strip
               dna_methylation_array_pathology_case_finding.score = score.strip
               dna_methylation_array_pathology_case_finding.interpretation = interpretation.strip
               dna_methylation_array_pathology_case_finding.save!
              end
            end
          end
        end
      end
    end
  end

  DnaMethylationArrayPathologyCase.where(section_description: 'Specimen').all.each do |dna_methylation_array_pathology_case|
    if dna_methylation_array_pathology_case.associated_accession_nbr_formatted.present? || dna_methylation_array_pathology_case.associated_accession_nbr_formatted_block.present? || dna_methylation_array_pathology_case.associated_accession_nbr_formatted_block_tumor_percentage
      dna_methylation_array_pathology_case_pathology_interpretation = DnaMethylationArrayPathologyCase.where(section_description: 'Pathology Interpretation', accession_nbr_formatted: dna_methylation_array_pathology_case.accession_nbr_formatted).first
      dna_methylation_array_pathology_case_pathology_interpretation.associated_accession_nbr_formatted =  dna_methylation_array_pathology_case.associated_accession_nbr_formatted
      dna_methylation_array_pathology_case_pathology_interpretation.associated_accession_nbr_formatted_block =  dna_methylation_array_pathology_case.associated_accession_nbr_formatted_block
      dna_methylation_array_pathology_case_pathology_interpretation.associated_accession_nbr_formatted_block_tumor_percentage =  dna_methylation_array_pathology_case.associated_accession_nbr_formatted_block_tumor_percentage
      dna_methylation_array_pathology_case_pathology_interpretation.save!
    end
  end
end

def parse_snv(classification, ngs_pathology_case, subsection, genes)
  lines = subsection[:subsection_text].split("\n")
  lines.each_with_index do |line, i|
    if match_gene?(genes, line)
      ngs_pathology_case_finding = NgsPathologyCaseFinding.new
      ngs_pathology_case_finding.ngs_pathology_case_id = ngs_pathology_case.id
      ngs_pathology_case_finding.significance = classification[:significance]
      ngs_pathology_case_finding.status = 'found'

      if i == lines.size-2 || match_gene?(genes, lines[i+2])
        ngs_pathology_case_finding.raw_finding = [line, lines[i+1]].join("\n")
        puts 'gene'
        puts line
        gene, transcript = line.split(' ').first
        if gene.present?
          ngs_pathology_case_finding.gene = gene
        end

        variant_name, allelic_frequency_raw = lines[i+1].strip.split(' ').take(2)

        puts 'variant_name'
        puts variant_name
        if variant_name.present?
          ngs_pathology_case_finding.variant_name = variant_name
        end

        puts 'transcript'
        puts transcript
        if transcript.present?
          ngs_pathology_case_finding.transcript = transcript
        end

        ngs_pathology_case_finding.variant_type = subsection[:variant_type]

        puts 'allelic frequency raw'
        puts allelic_frequency_raw
        if allelic_frequency_raw.present?
          percentage_matches = allelic_frequency_raw.scan(/(\d*\.?\d+)%/)
          if percentage_matches.size >=1
            if percentage_matches.size == 1
              allelic_frequency = percentage_matches.first.first.to_s
            else
              allelic_frequency = percentage_matches.map { |percentage_match| percentage_match.first.to_s }.join('|')
            end
          end
          puts 'allelic_frequency'
          puts allelic_frequency
          if allelic_frequency
            ngs_pathology_case_finding.allelic_frequency = allelic_frequency
          end
        end
        ngs_pathology_case_finding.save!
      elsif i == lines.size - 3 || match_gene?(genes, lines[i+3])
        ngs_pathology_case_finding.raw_finding = [line, lines[i+2]].join("\n")
        puts 'gene'
        puts line
        gene = line.split(' ').first
        if gene.present?
          ngs_pathology_case_finding.gene = gene
        end

        variant_name, transcript = lines[i+1].strip.split(' ')

        puts 'variant_name'
        puts variant_name
        if variant_name.present?
          ngs_pathology_case_finding.variant_name = variant_name
        end

        puts 'transcript'
        puts transcript
        if transcript.present?
          ngs_pathology_case_finding.transcript = transcript
        end

        ngs_pathology_case_finding.variant_type = subsection[:variant_type]

        c_dot, allelic_frequency_raw = lines[i+2].strip.split(' ').take(2)
        puts 'allelic frequency raw'
        puts allelic_frequency_raw
        if allelic_frequency_raw.present?
          percentage_matches = allelic_frequency_raw.scan(/(\d*\.?\d+)%/)
          if percentage_matches.size >=1
            if percentage_matches.size == 1
              allelic_frequency = percentage_matches.first.first.to_s
            else
              allelic_frequency = percentage_matches.map { |percentage_match| percentage_match.first.to_s }.join('|')
            end
          end
          puts 'allelic_frequency'
          puts allelic_frequency
          if allelic_frequency
            ngs_pathology_case_finding.allelic_frequency = allelic_frequency
          end
        end
        ngs_pathology_case_finding.save!
      end
    else
      next
    end
  end
end

def parse_cnv(classification, ngs_pathology_case, subsection, genes)
  subsection[:subsection_text].split("\n").drop(1).each_slice(2) do |variant|
    if genes.any? { |gene| variant[0].match?(Regexp.new("^\s*#{gene}", Regexp::IGNORECASE)) }
      ngs_pathology_case_finding = NgsPathologyCaseFinding.new
      ngs_pathology_case_finding.ngs_pathology_case_id = ngs_pathology_case.id
      ngs_pathology_case_finding.raw_finding = variant.join("\n")

      ngs_pathology_case_finding.significance = classification[:significance]
      ngs_pathology_case_finding.status = 'found'
      variant.compact
      if variant.size == 2
        puts 'gene'
        puts variant[0]
        gene = variant[0].split(' ').first

        copy_number_type, variant_name, copy_number = variant[1].strip.split(' ')

        if gene.present?
          ngs_pathology_case_finding.gene = "#{gene} #{copy_number_type}"
        end

        puts 'variant_name'
        puts variant_name
        if variant_name.present?
          ngs_pathology_case_finding.variant_name = variant_name
        end

        puts 'transcript'
        puts copy_number
        if copy_number.present?
          ngs_pathology_case_finding.copy_number = copy_number
        end

        ngs_pathology_case_finding.variant_type = subsection[:variant_type]

        ngs_pathology_case_finding.save!
      end
    end
  end
end

def parse_rearrangement(classification, ngs_pathology_case, subsection, genes)
  subsection[:subsection_text].split("\n").drop(1).each_slice(2) do |variant|
    if genes.any? { |gene| variant[0].match?(Regexp.new("^\s*#{gene}", Regexp::IGNORECASE)) }
      ngs_pathology_case_finding = NgsPathologyCaseFinding.new
      ngs_pathology_case_finding.ngs_pathology_case_id = ngs_pathology_case.id
      ngs_pathology_case_finding.raw_finding = variant.join("\n")

      ngs_pathology_case_finding.significance = classification[:significance]
      ngs_pathology_case_finding.status = 'found'
      variant.compact
      if variant.size == 2
        puts 'gene'
        puts variant[0]
        gene = variant[0].split(' ').first

        rearrangement_type, variant_name, variant_name_2, variant_name_3 = variant[1].strip.split(' ')

        if gene.present?
          ngs_pathology_case_finding.gene = "#{gene} #{rearrangement_type}"
        end


        variant_name = [variant_name, variant_name_2, variant_name_3].reject { |vn| vn == 'NA' }.join(' ')

        puts 'variant_name'
        puts variant_name
        if variant_name.present?
          ngs_pathology_case_finding.variant_name = variant_name
        end

        ngs_pathology_case_finding.variant_type = subsection[:variant_type]
        ngs_pathology_case_finding.save!
      end
    end
  end
end

def parse_pertinent_negative(classification, ngs_pathology_case, subsection, genes)
  subsection[:subsection_text].split("\n").drop(2).each do |pertinent_negative|
    if pertinent_negative.match?(/^\s*\*No mutations were identified./)
      break
    else
      ngs_pathology_case_finding = NgsPathologyCaseFinding.new
      ngs_pathology_case_finding.ngs_pathology_case_id = ngs_pathology_case.id
      ngs_pathology_case_finding.raw_finding = pertinent_negative

      ngs_pathology_case_finding.significance = classification[:significance]

      pertinent_negative = pertinent_negative.split(' ')
      gene = variant_name = pertinent_negative.shift
      status = pertinent_negative.join(' ')

      if gene.present? && gene.size <= 40
        ngs_pathology_case_finding.gene = gene
        ngs_pathology_case_finding.variant_name = variant_name
        ngs_pathology_case_finding.status = status
        ngs_pathology_case_finding.variant_type = subsection[:variant_type]
        ngs_pathology_case_finding.save!
      end
    end
  end
end

def parse_genomic_signature(classification, ngs_pathology_case, subsection, genes)
  subsection[:subsection_text].split("\n").drop(1).each do |genomic_signature|
    ngs_pathology_case_finding = NgsPathologyCaseFinding.new
    ngs_pathology_case_finding.ngs_pathology_case_id = ngs_pathology_case.id
    ngs_pathology_case_finding.raw_finding = genomic_signature
    ngs_pathology_case_finding.significance = classification[:significance]

    variant_name = genomic_signature.split(' ')
    genomic_signature_result = variant_name.pop(1).first
    variant_name = variant_name.join(' ')

    ngs_pathology_case_finding.variant_name = variant_name
    ngs_pathology_case_finding.genomic_signature_result = genomic_signature_result
    ngs_pathology_case_finding.variant_type = subsection[:variant_type]
    ngs_pathology_case_finding.save!
  end
end

def parse_germline(classification, ngs_pathology_case, text, genes)
  text.split("\n").each do |line|
    if match_gene?(genes, line)
      ngs_pathology_case_finding = NgsPathologyCaseFinding.new
      ngs_pathology_case_finding.ngs_pathology_case_id = ngs_pathology_case.id
      ngs_pathology_case_finding.raw_finding = line
      ngs_pathology_case_finding.significance = classification[:significance]

      gene, variant_name = line.split(' ')

      ngs_pathology_case_finding.gene = gene
      ngs_pathology_case_finding.variant_name = variant_name
      ngs_pathology_case_finding.variant_type = 'Germline'
      ngs_pathology_case_finding.save!
    end
  end
end

def match_gene?(genes, line)
  if line.present?
    genes.any? { |gene| line.match?(Regexp.new("^\s*#{gene}", Regexp::IGNORECASE)) }
  end
end

def match_genes(genes, text)
  matched_genes = []
  if text.present?
    matched_genes = genes.select { |gene| text.match?(Regexp.new("\\b#{gene}\\b", Regexp::IGNORECASE)) }
  end
  matched_genes
end

def find_classifications(ngs_pathology_case, classification_version)
  found_classifications = []
  ngs_pathology_case.note_text.split("\n").each do |line|
    classification_version[:classifications].each do |classification|
      # puts 'here is the line'
      # puts line
      # puts classification[:significance]
      # puts 'before bingo'
      if line.match?(classification[:marker])
        puts "that's a bingo"
        found_classifications << classification
      end
    end
  end
  found_classifications
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

def load_genetic_counseling_notes_and_findings(files, options= {})
  puts 'hello'
  source_system_id = nil
  puts ENV['SOURCE_SYSTEM_ID']
  if ENV['SOURCE_SYSTEM_ID'].present?
    source_system_id_in_focus = ENV['SOURCE_SYSTEM_ID']
  end

  options = { west_mrn: nil }.merge(options)
  GeneticCounselingNote.delete_all
  GeneticCounselingNoteFinding.delete_all
  genes = Gene.all.map(&:hgnc_symbol)
  files.each do |file|
    genetic_counseling_note_handler = Parsers::GeneticCounselingNoteHandler.new
    File.open(file) do |file|
      parser = Nokogiri::XML::SAX::Parser.new(genetic_counseling_note_handler)
      parser.parse(file)
    end

    genetic_counseling_notes = []
    if !options[:west_mrn].present?
      puts 'all baby'
      genetic_counseling_notes =  genetic_counseling_note_handler.genetic_counseling_notes
    else
      puts 'in clover'
      genetic_counseling_notes = genetic_counseling_note_handler.genetic_counseling_notes.select { |genetic_counseling_note| genetic_counseling_note.west_mrn ==  options[:west_mrn] }
    end

    genetic_counseling_notes.each_with_index do |genetic_counseling_note_from_file, i|

      # puts 'row'
      # puts i
      # puts 'patient_ir_id'
      patient_ir_id = genetic_counseling_note_from_file.patient_ir_id
      # puts patient_ir_id

      # puts 'row'
      # puts i
      # puts 'west_mrn'
      west_mrn = genetic_counseling_note_from_file.west_mrn
      # puts west_mrn

      # puts 'row'
      # puts i
      # puts 'source_system_name'
      source_system_name = genetic_counseling_note_from_file.source_system_name
      # puts source_system_name

      # puts 'row'
      # puts i
      # puts 'source_system_table'
      source_system_table = genetic_counseling_note_from_file.source_system_table
      # puts source_system_table

      # puts 'row'
      # puts i
      # puts 'source_system_id'
      source_system_id = genetic_counseling_note_from_file.source_system_id
      # puts source_system_id

      unless source_system_id_in_focus.blank?  || source_system_id_in_focus == source_system_id
        next
      end

      # puts 'row'
      # puts i
      # puts 'encounter_start_date_key'
      encounter_start_date_key = genetic_counseling_note_from_file.encounter_start_date_key
      # puts encounter_start_date_key

      # puts 'row'
      # puts i
      # puts 'encounter_start_date_key'
      note_text = genetic_counseling_note_from_file.note_text
      # puts note_text

      genetic_counseling_note = GeneticCounselingNote.new
      genetic_counseling_note.patient_ir_id = patient_ir_id
      genetic_counseling_note.west_mrn = west_mrn
      genetic_counseling_note.source_system_name = source_system_name
      genetic_counseling_note.source_system_id = source_system_id
      genetic_counseling_note.encounter_start_date_key = encounter_start_date_key
      genetic_counseling_note.note_text = note_text
      genetic_counseling_note.save!
    end
  end

  GeneticCounselingNote.all.each do |genetic_counseling_note|
    start_marker = Regexp.new('\.*Test Results\:\.*', Regexp::IGNORECASE)
    end_marker = Regexp.new('\.*Interpretation\:\.*', Regexp::IGNORECASE)
    augered_text = extract_accross_lines_between_regular_expressions(genetic_counseling_note.note_text, start_marker, end_marker)

    if !augered_text.blank?
      augered_text.gsub!(/^[[:space:]]+|[[:space:]]+$/, '')
      puts 'here is the augered_text'
      puts augered_text
      puts 'here is the source_system_id'
      puts genetic_counseling_note.source_system_id

      if augered_text.match?(/^\s*positive:?\s*/i) || augered_text.match?(/\b(VUS)\b/i) || augered_text.match?(/\bVariant of uncertain significance\b/i)
        puts 'we have a positive'
        if augered_text.match?(/(?=\s*No\s*variants?\s*identified:?\b)/i)
          puts 'hello in the place 1'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*No\s*variants?\s*identified:?\b)/i, 2)
        elsif augered_text.match?(/(?=\s*No\s*variants?\s*found:?\b)/i)
          puts 'hello in the place 3'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*No\s*variants?\s*found:?\b)/i, 2)
        elsif augered_text.match?(/(?=\s*No\s*variants?\s*detected?:\b)/i)
          puts 'hello in the place 4'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*No\s*variants?\s*detected?:\b)/i, 2)
        elsif augered_text.match?(/(?=\s*No\s*mutations?\s*identified:?\b)/i)
          puts 'hello in the place 5'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*No\s*mutations?\s*identified:?\b)/i, 2)
        elsif augered_text.match?(/(?=\s*No\s*mutations?\s*found:?\b)/i)
          puts 'hello in the place 6'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*No\s*mutations?\s*found:?\b)/i, 2)
        elsif augered_text.match?(/(?=\s*No\s*mutations?\s*detected:?\b)/i)
          puts 'hello in the place 7'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*No\s*mutations?\s*detected:?\b)/i, 2)
        elsif augered_text.match?(/(?=\s*No other variants of known\/unknown significance were identified\s*)/i)
          puts 'hello in the place 8'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*No other variants of known\/unknown significance were identified\s*)/i, 2)
        elsif augered_text.match?(/(?=\s*Invitae Common Hereditary Cancer panel:?\b)/i)
          puts 'hello in the place 9'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*Invitae Common Hereditary Cancer panel:?\b)/i, 2)
        elsif augered_text.match?(/(?=\s*Invitae Multi-Cancers Panel:?\b)/i)
          puts 'hello in the place 10'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*Invitae Multi-Cancers Panel:?\b)/i, 2)
        elsif augered_text.match?(/(?=\s*Ambry Genetics CustomNext-Cancer \+RNAinsight panel:?\b)/i)
          puts 'hello in the place 11'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*Ambry Genetics CustomNext-Cancer \+RNAinsight panel:?\b)/i, 2)
        elsif augered_text.match?(/(?=\s*Negative:?\b)/i)
          puts 'hello in the place 12'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*Negative:?\b)/i, 2)
        elsif augered_text.match?(/(?=\s*No other variants were identified\s*)/i)
          puts 'hello in the place 2'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*No other variants were identified\s*)/i, 2)
        else
          puts 'hello in the place 13'
          positive_augered_text = augered_text
          negative_augered_text = nil
        end
        matched_genes = match_genes(genes, positive_augered_text)
        if matched_genes.any?
          matched_genes.each do |matched_gene|
            genetic_counseling_note_finding = GeneticCounselingNoteFinding.new
            genetic_counseling_note_finding.genetic_counseling_note_id = genetic_counseling_note.id
            genetic_counseling_note_finding.raw_finding = positive_augered_text
            genetic_counseling_note_finding.gene = matched_gene
            genetic_counseling_note_finding.variant_name = nil
            genetic_counseling_note_finding.hgvs_c = nil
            genetic_counseling_note_finding.hgvs_p = nil
            genetic_counseling_note_finding.status = 'positive'
            genetic_counseling_note_finding.save!
          end
        end

        if negative_augered_text.present?
          matched_genes = match_genes(genes, negative_augered_text)
          if matched_genes.any?
            matched_genes.each do |matched_gene|
              genetic_counseling_note_finding = GeneticCounselingNoteFinding.new
              genetic_counseling_note_finding.genetic_counseling_note_id = genetic_counseling_note.id
              genetic_counseling_note_finding.raw_finding = negative_augered_text
              genetic_counseling_note_finding.gene = matched_gene
              genetic_counseling_note_finding.variant_name = nil
              genetic_counseling_note_finding.hgvs_c = nil
              genetic_counseling_note_finding.hgvs_p = nil
              genetic_counseling_note_finding.status = 'negative'
              genetic_counseling_note_finding.save!
            end
          end
        end
      else
        puts 'before the storm'
        matched_genes = match_genes(genes, augered_text)
        if matched_genes.any?
          matched_genes.each do |matched_gene|
            genetic_counseling_note_finding = GeneticCounselingNoteFinding.new
            genetic_counseling_note_finding.genetic_counseling_note_id = genetic_counseling_note.id
            genetic_counseling_note_finding.raw_finding = augered_text
            genetic_counseling_note_finding.gene = matched_gene
            genetic_counseling_note_finding.variant_name = nil
            genetic_counseling_note_finding.hgvs_c = nil
            genetic_counseling_note_finding.hgvs_p = nil
            genetic_counseling_note_finding.status = 'negative'
            genetic_counseling_note_finding.save!
          end
        else
          if augered_text.match?(/\bNo variants identified\b/i) || augered_text.match?(/\bNo mutation found\b/i) || augered_text.match?(/\bNegative\b/i)
            genetic_counseling_note_finding = GeneticCounselingNoteFinding.new
            genetic_counseling_note_finding.genetic_counseling_note_id = genetic_counseling_note.id
            genetic_counseling_note_finding.raw_finding = augered_text
            genetic_counseling_note_finding.gene = nil
            genetic_counseling_note_finding.variant_name = nil
            genetic_counseling_note_finding.hgvs_c = nil
            genetic_counseling_note_finding.hgvs_p = nil
            genetic_counseling_note_finding.status = 'negative'
            genetic_counseling_note_finding.save!
          end
        end
      end
    else
      puts 'here is the source_system_id'
      puts genetic_counseling_note.source_system_id
      # start_marker = Regexp.new('Variants\s*of\s*Uncertain\s*Significance\s*\(VUS\):', Regexp::IGNORECASE)
      start_marker = Regexp.new('\s*Test results\s*')
      end_marker = Regexp.new('\s{3,}')
      augered_text = extract_accross_lines_between_regular_expressions(genetic_counseling_note.note_text, start_marker, end_marker)

      if !augered_text.blank?
        puts 'we caught a new guy!'
        puts 'here is the augered_text'
        puts augered_text

        if augered_text.match?(/(?=^\s*Negative:?\b)/i)
          puts 'hello in the place 6'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=^\s*Negative:?\b)/i, 2)

          if positive_augered_text.present? && negative_augered_text.nil?
            negative_augered_text = positive_augered_text
            positive_augered_text = nil
          end
        elsif augered_text.match?(/(?=\s*No\s*mutations?\s*found:?\b)/i)
          puts 'hello in the place 1'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*No\s*mutations?\s*found:?\b)/i, 2)
          if positive_augered_text.present?  && negative_augered_text.nil?
            negative_augered_text = positive_augered_text
            positive_augered_text = nil
          end
        elsif augered_text.match?(/(?=\s*No\s*variants?\s*identified:?\b)/i)
          puts 'hello in the place 2'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*No\s*variants?\s*identified:?\b)/i, 2)
          if positive_augered_text.present?  && negative_augered_text.nil?
            negative_augered_text = positive_augered_text
            positive_augered_text = nil
          end
        elsif augered_text.match?(/(?=\s*Ambry Genetics:?\b)/i)
          puts 'hello in the place 3'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*Ambry Genetics:?\b)/i, 2)
          if positive_augered_text.present?  && negative_augered_text.nil?
            negative_augered_text = positive_augered_text
            positive_augered_text = nil
          end
        elsif augered_text.match?(/(?=\s*Ambry panel:?\b)/i)
          puts 'hello in the place 4'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*Ambry panel:?\b)/i, 2)
          if positive_augered_text.present?  && negative_augered_text.nil?
            negative_augered_text = positive_augered_text
            positive_augered_text = nil
          end
        elsif augered_text.match?(/(?=\s*Ambry Genetics CustomNext Cancer Panel:?\b)/i)
          puts 'hello in the place 5'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*Ambry Genetics CustomNext Cancer Panel:?\b)/i, 2)
          if positive_augered_text.present?  && negative_augered_text.nil?
            negative_augered_text = positive_augered_text
            positive_augered_text = nil
          end
        elsif augered_text.match?(/(?=\s*Invitae Custom Hereditary Cancer Panel:?\b)/i)
          puts 'hello in the place 5'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*Invitae Custom Hereditary Cancer Panel:?\b)/i, 2)
          if positive_augered_text.present?  && negative_augered_text.nil?
            negative_augered_text = positive_augered_text
            positive_augered_text = nil
          end
        elsif augered_text.match?(/(?=\s*Negative:?\b)/i)
          puts 'hello in the place 6'
          positive_augered_text, negative_augered_text = augered_text.split(/(?=\s*Negative:?\b)/i, 2)

          if positive_augered_text.present? && negative_augered_text.nil?
            negative_augered_text = positive_augered_text
            positive_augered_text = nil
          end
        else
          puts 'ugh'
          positive_augered_text = augered_text
          negative_augered_text = nil
        end
        puts 'ugh more'
        if !positive_augered_text.blank?
          matched_genes = match_genes(genes, positive_augered_text)
          if matched_genes.any?
            matched_genes.each do |matched_gene|
              genetic_counseling_note_finding = GeneticCounselingNoteFinding.new
              genetic_counseling_note_finding.genetic_counseling_note_id = genetic_counseling_note.id
              genetic_counseling_note_finding.raw_finding = positive_augered_text
              genetic_counseling_note_finding.gene = matched_gene
              genetic_counseling_note_finding.variant_name = nil
              genetic_counseling_note_finding.hgvs_c = nil
              genetic_counseling_note_finding.hgvs_p = nil
              genetic_counseling_note_finding.status = 'positive'
              genetic_counseling_note_finding.save!
            end
          end
        end
        if !negative_augered_text.blank?
          matched_genes = match_genes(genes, negative_augered_text)
          if matched_genes.any?
            matched_genes.each do |matched_gene|
              genetic_counseling_note_finding = GeneticCounselingNoteFinding.new
              genetic_counseling_note_finding.genetic_counseling_note_id = genetic_counseling_note.id
              genetic_counseling_note_finding.raw_finding = negative_augered_text
              genetic_counseling_note_finding.gene = matched_gene
              genetic_counseling_note_finding.variant_name = nil
              genetic_counseling_note_finding.hgvs_c = nil
              genetic_counseling_note_finding.hgvs_p = nil
              genetic_counseling_note_finding.status = 'negative'
              genetic_counseling_note_finding.save!
            end
          else
            genetic_counseling_note_finding = GeneticCounselingNoteFinding.new
            genetic_counseling_note_finding.genetic_counseling_note_id = genetic_counseling_note.id
            genetic_counseling_note_finding.raw_finding = negative_augered_text
            genetic_counseling_note_finding.gene = nil
            genetic_counseling_note_finding.variant_name = nil
            genetic_counseling_note_finding.hgvs_c = nil
            genetic_counseling_note_finding.hgvs_p = nil
            genetic_counseling_note_finding.status = 'negative'
            genetic_counseling_note_finding.save!
          end
        end
      else
        puts 'no luck'
      end
    end
    puts '---------------------------------'
  end
end