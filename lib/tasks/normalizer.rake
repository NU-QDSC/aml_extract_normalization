namespace :normalizer do
  # bundle exec rake normalizer:load_vocabulary
  desc "Load abnormalities"
  task(load_vocabulary: :environment) do |t, args|
    Gene.delete_all
    GeneSynonym.delete_all
    hgnc_genes = CSV.new(File.open('lib/setup/vocabulary/gene_with_protein_product.txt'), headers: true, col_sep: "\t", return_headers: false,  quote_char: "\"")
    hgnc_genes.each do |hgnc_gene|
      gene = Gene.new
      gene.hgnc_id = hgnc_gene['hgnc_id']
      gene.hgnc_symbol = hgnc_gene['symbol']
      gene.name = hgnc_gene['name']
      gene.location = hgnc_gene['location']
      gene.alias_symbol = hgnc_gene['alias_symbol']
      gene.alias_name = hgnc_gene['alias_name']
      gene.alias_name = hgnc_gene['prev_symbol']
      gene.alias_name = hgnc_gene['prev_name']
      gene.alias_name = hgnc_gene['gene_group']
      gene.save!

      if hgnc_gene['alias_symbol'].present?
        hgnc_gene['alias_symbol'].split('|').each do |alias_symbol|
          gene.gene_synonyms.build(synonym_name: alias_symbol, synonym_type: 'symbol')
        end
      end

      if hgnc_gene['alias_name'].present?
        hgnc_gene['alias_name'].split('|').each do |alias_name|
          gene.gene_synonyms.build(synonym_name: alias_name, synonym_type: 'name')
        end
      end

      gene.save!
    end
  end

  # bundle exec rake normalizer:load_pathology_cases_and_findings
  desc "Load pathology cases and findings"
  task :load_pathology_cases_and_findings, [:west_mrn] => :environment do |t, args|
    puts 'you need to care'
    puts args[:west_mrn]
    directory_path = 'lib/setup/data/AML Cytogenetic and FISH Pathology Cases/'
    files = Dir.glob(File.join(directory_path, '*.xlsx'))
    files = files.sort_by { |file| File.stat(file).mtime }

    load_pathology_cases_and_findings(files, west_mrn: args[:west_mrn])
  end

  # bundle exec rake normalizer:normalize
  desc "Normalize"
  task :normalize, [:west_mrn] => :environment do |t, args|
    # PathologyCaseFindingNormalization.delete_all
    accession_nbr_formatted = nil
    puts ENV['ACCESSION_NBR_FORMATTED']
    if ENV['ACCESSION_NBR_FORMATTED'].present?
      accession_nbr_formatted = ENV['ACCESSION_NBR_FORMATTED']
    end
    if accession_nbr_formatted
      pathology_cases = PathologyCase.where(accession_nbr_formatted: accession_nbr_formatted).all
      pathology_cases.each do |pathology_case|
        puts 'fuck 1'
        puts pathology_case.pathology_case_findings.size
        pathology_case.pathology_case_findings.each do |pathology_case_finding|
          pathology_case_finding.pathology_case_finding_normalizations.each do |pathology_case_finding_normalization|
            puts 'fuck 3'
            pathology_case_finding_normalization.destroy!
          end
        end
      end
    else
      PathologyCaseFindingNormalization.delete_all
      pathology_cases = PathologyCase.all
    end

    pathology_cases.each do |pathology_case|
      pathology_case.pathology_case_findings.each_with_index do |pathology_case_finding, i|
        genes = gene_list(pathology_case_finding.genetic_abnormality_name, discard_substrings: true)
        puts '------------------------'
        puts 'genetic_abnormality_name'
        puts pathology_case_finding.genetic_abnormality_name
        genes.each do |gene|
          puts '||||||||||||||||||||'
          puts 'gene'
          puts gene
          gene_abnormalities = []
          gene_abnormalities << { gene: gene, normalization_type: 'gene amplification', normalization: "#{gene} amplification", pre_abnormality_tokens: ['amplification of', 'amplifications of', 'gain of'], post_abnormality_tokens: ['amplification','amplifications', 'gain'] }
          gene_abnormalities << { gene: gene, normalization_type: 'gene rearrangement', normalization: "#{gene} rearrangement", pre_abnormality_tokens: ['rearrangement of', 'rearrangements of'], post_abnormality_tokens: ['rearrangement', 'rearrangements'] }
          gene_abnormalities << { gene: gene, normalization_type: 'gene deletion', normalization: "#{gene} deletion", pre_abnormality_tokens: ['deletion of', 'deletions of', 'loss of', 'deletion', 'deletions'], post_abnormality_tokens: ['deletion', 'deletions', 'loss', 'losses'] }
          gene_abnormalities << { gene: gene, normalization_type: 'gene translocation', normalization: "#{gene} translocation", pre_abnormality_tokens: ['translocation of'], post_abnormality_tokens: ['translocation'] }

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

    PathologyCaseFindingNormalization.select('pathology_case_finding_id, count(*) AS normalization_count').where("gene_1 IS NOT NULL AND normalization_type != 'fusion'").group(:pathology_case_finding_id).having('count(*) > 1').map { |pathology_case_finding_normalization| PathologyCaseFinding.find(pathology_case_finding_normalization.pathology_case_finding_id) }.each do |pathology_case_finding|
      pathology_case_finding.pathology_case_finding_normalizations.where("gene_1 IS NOT NULL AND normalization_type !='fusion'").group_by { |pathology_case_finding_normalization| pathology_case_finding_normalization.gene_1 }.each do |gene, pathology_case_finding_normalizations|
        puts 'pathology_case_finding_id'
        puts pathology_case_finding_normalizations.first.pathology_case_finding.id
        puts 'genetic_abnormality_name'
        puts pathology_case_finding_normalizations.first.pathology_case_finding.genetic_abnormality_name

        puts 'gene'
        puts gene
        if pathology_case_finding_normalizations.size > 1
          shortest_match_token = pathology_case_finding_normalizations.map { |pathology_case_finding_normalization| pathology_case_finding_normalization.match_token.length }.min
          pathology_case_finding_normalizations.select { |pathology_case_finding_normalization| pathology_case_finding_normalization.match_token.length != shortest_match_token }.each do |pathology_case_finding_normalization|
            pathology_case_finding_normalization.destroy!
          end
        else
          puts 'only one per gene'
        end
      end
    end

    PathologyCaseFindingNormalization.select('pathology_case_finding_id, count(*) AS normalization_count').where("normalization_type IN('numerical chromosomal', 'structural chromosomal addition')").group(:pathology_case_finding_id).having('count(*) > 1').map { |pathology_case_finding_normalization| PathologyCaseFinding.find(pathology_case_finding_normalization.pathology_case_finding_id) }.each do |pathology_case_finding|
      pathology_case_finding.pathology_case_finding_normalizations.where("normalization_type IN('numerical chromosomal', 'structural chromosomal addition'").group_by { |pathology_case_finding_normalization| pathology_case_finding_normalization.gene_1 }.each do |gene, pathology_case_finding_normalizations|
        if pathology_case_finding_normalizations.size > 1
          longest_match_token = pathology_case_finding_normalizations.map { |pathology_case_finding_normalization| pathology_case_finding_normalization.match_token.length }.max
          pathology_case_finding_normalizations.select { |pathology_case_finding_normalization| pathology_case_finding_normalization.match_token.length < longest_match_token }.each do |pathology_case_finding_normalization|
            pathology_case_finding_normalization.destroy!
          end
        else
          puts 'only one per structural chromosmal'
        end
      end
    end
  end
end

def load_pathology_cases_and_findings(files, options= {})
  options = { west_mrn: nil }.merge(options)
  PathologyCase.delete_all
  PathologyCaseFinding.delete_all
  PathologyCaseFindingNormalization.delete_all
  files.each do |file|
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
      pathology_case.save!
    end
  end

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

      pathology_case = PathologyCase.where(snomed_name: identiifers[0], source_system: identiifers[1], pathology_case_source_system_id: identiifers[2])

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
  regular_expressions.each do |regular_expression|
    m = pathology_case_finding.genetic_abnormality_name.match(regular_expression)
    if m
      pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: gene_abnormality[:normalization], normalization_type: gene_abnormality[:normalization_type], gene_1: gene_abnormality[:gene], match_token: m.to_s)
      pathology_case_finding.save!
      puts 'got you gene abnormality!'
      break
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
          other_normalization = "#{other_chromosome} monosomy"
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
  expression = '\der\((?:[0-9]|1[0-9]|2[0-2]|X|Y)[\.w]*\)'
  regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
  matches = pathology_case_finding.genetic_abnormality_name.scan(regular_expression)
  matches.each do |match|
    pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: match.to_s, normalization_type: 'structural chromosomal derivation', match_token: match.to_s)
    pathology_case_finding.save!
    puts 'got you normalize_structural_chromosomal_abnormality derivation!'
  end

  #translocation
  expression = 't\s*\((2[0-2]|[01]?[0-9]|X|Y)\;(2[0-2]|[01]?[0-9]|X|Y)\)'
  regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
  matches = pathology_case_finding.genetic_abnormality_name.scan(regular_expression)
  matches.each do |match|
    pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: "t(#{match.first};#{match.last})", normalization_type: 'structural chromosomal translocation', match_token: "t(#{match.first};#{match.last})")
    pathology_case_finding.save!
    puts 'got you normalize_structural_chromosomal_abnormality translocation!'
  end

  #inversion
  expression = '\binv\((?:[0-9]|1[0-9]|2[0-2]|X|Y)[\.w]*\)'
  regular_expression = Regexp.new(expression, Regexp::IGNORECASE)
  matches = pathology_case_finding.genetic_abnormality_name.scan(regular_expression)
  matches.each do |match|
    pathology_case_finding.pathology_case_finding_normalizations.build(normalization_name: match.to_s, normalization_type: 'structural chromosomal inversion', match_token: match.to_s)
    pathology_case_finding.save!
    puts 'got you normalize_structural_chromosomal_abnormality inversion!'
  end
end

def normalize_structural_chromosomal_abnormality_addition(pathology_case_finding, genetic_abnormality_name)
  #prefix abnormality with structure in parentheses
  addition_synonyms = ['addition', 'additions', 'addition of', 'gain', 'gains', 'gain of', 'add'].each do |addition_synonym|
    expression = '(\b|\()' + addition_synonym + '\s*\((2[0-2]|[01]?[0-9]|X|Y)(?![0-9])[\w.]*\)' + '(\b|\))'
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
    expression = '(\b|\()' + addition_synonym +'\s*(2[0-2]|[01]?[0-9]|X|Y)(?![0-9])[\w.]*\s*' + '(\b|\))'
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
    expression = '(\b|\()\s*(2[0-2]|[01]?[0-9]|X|Y)(?![0-9])[\w.]*\s*' + addition_synonym + '(\b|\))'
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
    expression = '\b' + deletion_synonym + '\s*\((2[0-2]|[01]?[0-9]|X|Y)(?![0-9])[\w.]*\)'
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
    expression = '\b' + deletion_synonym +'\s*(2[0-2]|[01]?[0-9]|X|Y)(?![0-9])[\w.]*\s*'
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
    expression = '\b\s*(2[0-2]|[01]?[0-9]|X|Y)(?![0-9])[\w.]*\s*' + deletion_synonym + '\b'
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

  ['MLL', 'D20S108', 'D7S486', 'D13S319', 'S7S486'].each do |dna_marker|
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
