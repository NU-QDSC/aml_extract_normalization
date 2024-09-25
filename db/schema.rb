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

ActiveRecord::Schema[7.1].define(version: 2024_09_23_093742) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "api_logs", force: :cascade do |t|
    t.string "system", null: false
    t.text "url"
    t.text "payload"
    t.text "response"
    t.text "error"
    t.integer "batch_entity_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["system"], name: "index_api_logs_on_system"
  end

  create_table "batch_entities", force: :cascade do |t|
    t.integer "batch_id", null: false
    t.integer "entity_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "batches", force: :cascade do |t|
    t.integer "project_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "cap_ecc_morph_maps", force: :cascade do |t|
    t.string "template_name"
    t.string "item_ckey"
    t.string "item_title"
    t.string "icdo3morph"
    t.string "icdo3fullterm"
    t.string "icdo3_match"
    t.string "fsn"
    t.string "conceptid"
    t.string "snomed_match"
    t.string "cap_ecc_changes"
    t.string "cap_ecc_version"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "cap_ecc_topo_maps", force: :cascade do |t|
    t.string "template_name"
    t.string "item_ckey"
    t.string "item_title"
    t.string "icdo3topo"
    t.string "icdo3fullterm"
    t.string "icdo3_match"
    t.string "snomed_term"
    t.string "conceptid"
    t.string "snomed_match"
    t.string "cap_ecc_changes"
    t.string "cap_ecc_version"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

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
    t.bigint "chromosomal_abnormality_id"
    t.bigint "gene_abnormality_id"
    t.string "gene"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chromosomal_abnormality_id"], name: "idx_on_chromosomal_abnormality_id_efadfd43bc"
    t.index ["gene_abnormality_id"], name: "index_chromosomal_abnormality_genes_on_gene_abnormality_id"
  end

  create_table "chromosomal_abnormality_synonyms", force: :cascade do |t|
    t.bigint "chromosomal_abnormality_id"
    t.string "chromosomal_abnormality_synonym"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chromosomal_abnormality_id"], name: "idx_on_chromosomal_abnormality_id_0df87e2272"
  end

  create_table "dna_methylation_array_pathology_case_findings", force: :cascade do |t|
    t.bigint "dna_methylation_array_pathology_case_id"
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

  create_table "drug_exposures", force: :cascade do |t|
    t.string "west_mrn", null: false
    t.string "ingredient_concept_name", null: false
    t.string "ingredient_concept_code", null: false
    t.datetime "order_start_date_key", precision: nil, null: false
    t.datetime "order_end_date_key", precision: nil, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "drug_modalities", id: false, force: :cascade do |t|
    t.string "drug_concept_code", limit: 50
    t.string "drug_concept_name", limit: 255
    t.string "treatment_modality", limit: 20
  end

  create_table "entities", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "entity_attribute_values", force: :cascade do |t|
    t.integer "entity_attribute_id", null: false
    t.string "name", null: false
    t.string "code", null: false
  end

  create_table "entity_attributes", force: :cascade do |t|
    t.integer "entity_id", null: false
    t.string "name", null: false
    t.string "code", null: false
    t.string "redcap_code"
    t.string "data_type"
  end

  create_table "gene_abnormalities", force: :cascade do |t|
    t.string "gene_abnormality"
    t.string "gene_abnormality_type"
    t.string "source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "gene_abnormality_synonyms", force: :cascade do |t|
    t.bigint "gene_abnormality_id"
    t.string "gene_abnormality_synonym"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gene_abnormality_id"], name: "index_gene_abnormality_synonyms_on_gene_abnormality_id"
  end

  create_table "gene_synonyms", force: :cascade do |t|
    t.bigint "gene_id"
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

  create_table "hemonc_concept", primary_key: "concept_id", id: :bigint, default: nil, force: :cascade do |t|
    t.string "concept_name", limit: 255, null: false
    t.string "domain_id", limit: 20, null: false
    t.string "vocabulary_id", limit: 20, null: false
    t.string "concept_class_id", limit: 20, null: false
    t.string "standard_concept", limit: 1
    t.string "concept_code", limit: 50, null: false
    t.date "valid_start_date", null: false
    t.date "valid_end_date", null: false
    t.string "invalid_reason", limit: 1
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["concept_class_id"], name: "idx_hemonc_concept_class_id"
    t.index ["concept_code"], name: "idx_hemonc_concept_code"
    t.index ["concept_id"], name: "idx_hemonc_concept_concept_id", unique: true
    t.index ["domain_id"], name: "idx_hemonc_concept_domain_id"
    t.index ["vocabulary_id"], name: "idx_hemonc_concept_vocabluary_id"
  end

  create_table "hemonc_concept_ancestor", force: :cascade do |t|
    t.string "ancestor_vocabulary_code", limit: 20, null: false
    t.string "ancestor_concept_code", limit: 50, null: false
    t.string "descendant_vocabulary_id", limit: 20, null: false
    t.string "descendant_concept_code", limit: 50, null: false
    t.bigint "min_levels_of_separation"
    t.bigint "max_levels_of_separation"
  end

  create_table "hemonc_concept_ancestor_full", force: :cascade do |t|
    t.string "ancestor_vocabulary_id", limit: 20, null: false
    t.string "ancestor_concept_code", limit: 50, null: false
    t.string "descendant_vocabulary_id", limit: 20, null: false
    t.string "descendant_concept_code", limit: 50, null: false
    t.bigint "min_levels_of_separation"
    t.bigint "max_levels_of_separation"
  end

  create_table "hemonc_concept_relationship", force: :cascade do |t|
    t.bigint "concept_id_1"
    t.bigint "concept_id_2"
    t.string "concept_code_1", limit: 50, null: false
    t.string "concept_code_2", limit: 50, null: false
    t.string "vocabulary_id_1", limit: 50, null: false
    t.string "vocabulary_id_2", limit: 50, null: false
    t.string "relationship_id", limit: 20, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.date "valid_start_date"
    t.date "valid_end_date"
    t.string "invalid_reason"
    t.index ["concept_id_1"], name: "idx_hemonc_concept_relationship_id_1"
    t.index ["concept_id_2"], name: "idx_hemonc_concept_relationship_id_2"
    t.index ["relationship_id"], name: "idx_hemonc_concept_relationship_id_3"
  end

  create_table "icdo3_categories", force: :cascade do |t|
    t.string "version", null: false
    t.string "category", null: false
    t.string "categorizable_type", null: false
    t.integer "parent_icdo3_category_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "icdo3_categorizations", force: :cascade do |t|
    t.integer "icdo3_category_id", null: false
    t.integer "categorizable_id", null: false
    t.string "categorizable_type", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "icdo3_histologies", force: :cascade do |t|
    t.string "version", null: false
    t.string "minor_version", null: false
    t.string "icdo3_code", null: false
    t.string "icdo3_name", null: false
    t.string "icdo3_description", null: false
    t.string "level"
    t.string "code_reference"
    t.string "obs"
    t.string "see_also"
    t.string "includes"
    t.string "excludes"
    t.string "other_text"
    t.string "category"
    t.string "subcategory"
    t.integer "grade"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "icdo3_histology_synonyms", force: :cascade do |t|
    t.integer "icdo3_histology_id", null: false
    t.string "icdo3_synonym_description", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "icdo3_site_synonyms", force: :cascade do |t|
    t.integer "icdo3_site_id", null: false
    t.string "icdo3_synonym_description", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "icdo3_sites", force: :cascade do |t|
    t.string "version", null: false
    t.string "minor_version", null: false
    t.string "icdo3_code", null: false
    t.string "icdo3_name", null: false
    t.string "icdo3_description", null: false
    t.string "category"
    t.string "subcategory"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "ngs_pathology_case_findings", force: :cascade do |t|
    t.bigint "ngs_pathology_case_id"
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
    t.index ["ngs_pathology_case_id"], name: "index_ngs_pathology_case_findings_on_ngs_pathology_case_id"
  end

  create_table "ngs_pathology_cases", force: :cascade do |t|
    t.integer "patient_ir_id"
    t.string "west_mrn"
    t.string "source_system_name"
    t.integer "source_system_id"
    t.string "accession_nbr_formatted"
    t.date "accessioned_datetime"
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
    t.bigint "pathology_case_finding_id"
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
    t.bigint "pathology_case_id"
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

  create_table "project_entities", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "entity_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.string "irb_number", null: false
    t.string "redcap_api_token"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "patient_instrument"
    t.string "patient_identifier", default: "f"
  end

  create_table "regimen_ingredients", force: :cascade do |t|
    t.integer "regimen_id", null: false
    t.string "ingredient_concept_name", null: false
    t.string "ingredient_concept_code", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "regimens", force: :cascade do |t|
    t.string "west_mrn", null: false
    t.string "ingredient_concept_name"
    t.string "ingredient_concept_code"
    t.datetime "regimen_start_date", precision: nil, null: false
    t.datetime "regimen_end_date", precision: nil, null: false
    t.string "regimen_type", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "seer_site_recode_definition_icdo3_sites", force: :cascade do |t|
    t.integer "seer_site_recode_definition_id", null: false
    t.string "icdo3_code", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "seer_site_recode_definitions", force: :cascade do |t|
    t.integer "seer_site_recode_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "seer_site_recodes", force: :cascade do |t|
    t.integer "seer_site_recode_parent_id"
    t.string "name", null: false
    t.text "icdo3_sites_raw"
    t.text "icdo3_histologies_raw"
    t.string "recode"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "systemic_treatments", force: :cascade do |t|
    t.string "west_mrn"
    t.string "systemic_treatment_provenance"
    t.date "systemic_treatment_begin_date"
    t.date "systemic_treatment_end_date"
    t.text "systemic_treatment_drugs"
    t.string "systemic_treatment_treatment_goal"
    t.integer "systemic_treatment_cycles"
  end

end
