# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2024_12_12_220614) do
  create_table "chromosomal_abnormalities", force: :cascade do |t|
    t.string "abnormality"
    t.string "abnormality_type"
    t.string "abnormality_class"
    t.string "source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "chromosomal_abnormality_associations", force: :cascade do |t|
    t.string "abnormality"
    t.string "chromosome"
    t.string "arm"
    t.string "band"
    t.string "gene"
    t.string "abnormality_type"
    t.string "abnormality_class"
    t.string "morph_name"
    t.string "morph"
    t.string "topo_name"
    t.string "topo"
    t.string "case_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "chromosomal_abnormality_genes", force: :cascade do |t|
    t.integer "chromosomal_abnormality_id"
    t.integer "gene_abnormality_id"
    t.string "gene"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chromosomal_abnormality_id"], name: "idx_on_chromosomal_abnormality_id_efadfd43bc"
    t.index ["gene_abnormality_id"], name: "index_chromosomal_abnormality_genes_on_gene_abnormality_id"
  end

  create_table "chromosomal_abnormality_synonyms", force: :cascade do |t|
    t.integer "chromosomal_abnormality_id"
    t.string "chromosomal_abnormality_synonym"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chromosomal_abnormality_id"], name: "idx_on_chromosomal_abnormality_id_0df87e2272"
  end

  create_table "dna_methylation_array_pathology_case_findings", force: :cascade do |t|
    t.integer "dna_methylation_array_pathology_case_id"
    t.string "methylation_class"
    t.string "methylation_subclass"
    t.string "score"
    t.string "interpretation"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dna_methylation_array_pathology_case_id"], name: "idx_on_dna_methylation_array_pathology_case_id_78b0a70885"
  end

  create_table "dna_methylation_array_pathology_cases", force: :cascade do |t|
    t.string "west_mrn"
    t.integer "pathology_case_key"
    t.string "source_system"
    t.integer "pathology_case_source_system_id"
    t.string "accession_nbr_formatted"
    t.string "group_desc"
    t.string "snomed_code"
    t.string "snomed_name"
    t.date "accessioned_date_key"
    t.date "case_collect_date_key"
    t.string "section_description"
    t.text "note_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "associated_accession_nbr_formatted"
    t.string "associated_accession_nbr_formatted_block"
    t.string "associated_accession_nbr_formatted_block_tumor_percentage"
  end

  create_table "gene_abnormalities", force: :cascade do |t|
    t.string "gene_abnormality"
    t.string "gene_abnormality_type"
    t.string "source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "gene_abnormality_synonyms", force: :cascade do |t|
    t.integer "gene_abnormality_id"
    t.string "gene_abnormality_synonym"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gene_abnormality_id"], name: "index_gene_abnormality_synonyms_on_gene_abnormality_id"
  end

  create_table "gene_synonyms", force: :cascade do |t|
    t.integer "gene_id"
    t.string "synonym_name"
    t.string "synonym_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gene_id"], name: "index_gene_synonyms_on_gene_id"
  end

  create_table "genes", force: :cascade do |t|
    t.string "hgnc_id"
    t.string "hgnc_symbol"
    t.string "name"
    t.string "location"
    t.string "alias_symbol"
    t.string "alias_name"
    t.string "prev_symbol"
    t.string "prev_name"
    t.string "gene_group"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "genetic_counseling_note_findings", force: :cascade do |t|
    t.integer "genetic_counseling_note_id"
    t.string "raw_finding"
    t.string "gene"
    t.string "variant_name"
    t.string "hgvs_c"
    t.string "hgvs_p"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["genetic_counseling_note_id"], name: "idx_on_genetic_counseling_note_id_e54aba7ab0"
  end

  create_table "genetic_counseling_notes", force: :cascade do |t|
    t.integer "patient_ir_id"
    t.string "west_mrn"
    t.string "source_system_name"
    t.integer "source_system_id"
    t.date "encounter_start_date_key"
    t.text "note_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ngs_pathology_case_findings", force: :cascade do |t|
    t.integer "ngs_pathology_case_id"
    t.string "raw_finding"
    t.string "gene"
    t.string "variant_name"
    t.string "variant_type"
    t.string "allelic_frequency"
    t.string "transcript"
    t.string "significance"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "copy_number"
    t.string "genomic_signature_result"
    t.string "gene_position"
    t.string "fusion_gene"
    t.string "fusion_gene_position"
    t.string "gene_exon"
    t.string "fusion_gene_exon"
    t.index ["ngs_pathology_case_id"], name: "index_ngs_pathology_case_findings_on_ngs_pathology_case_id"
  end

  create_table "ngs_pathology_cases", force: :cascade do |t|
    t.integer "patient_ir_id"
    t.string "west_mrn"
    t.string "source_system_name"
    t.integer "source_system_id"
    t.string "accession_nbr_formatted"
    t.date "accessioned_date_key"
    t.date "case_collect_date_key"
    t.string "group_name"
    t.string "group_desc"
    t.string "report_description"
    t.string "section_description"
    t.text "note_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pathology_case_finding_normalizations", force: :cascade do |t|
    t.integer "pathology_case_finding_id"
    t.string "normalization_name"
    t.string "normalization_type"
    t.string "gene_1"
    t.string "gene_2"
    t.string "match_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pathology_case_finding_id"], name: "idx_on_pathology_case_finding_id_5f13caebf3"
  end

  create_table "pathology_case_findings", force: :cascade do |t|
    t.integer "pathology_case_id"
    t.string "genetic_abnormality_name"
    t.string "status"
    t.string "percentage"
    t.text "matched_og_phrase"
    t.float "score"
    t.string "extraction_status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "clone_name"
    t.boolean "subclone"
    t.string "cell_count"
    t.string "chromosome_count"
    t.string "sex"
    t.index ["pathology_case_id"], name: "index_pathology_case_findings_on_pathology_case_id"
  end

  create_table "pathology_cases", force: :cascade do |t|
    t.string "west_mrn"
    t.string "source_system"
    t.integer "pathology_case_key"
    t.integer "pathology_case_source_system_id"
    t.string "accession_nbr_formatted"
    t.string "group_desc"
    t.string "snomed_code"
    t.string "snomed_name"
    t.date "accessioned_date_key"
    t.string "section_description"
    t.text "note_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "normalization_method"
    t.date "case_collect_date_key"
  end

end
