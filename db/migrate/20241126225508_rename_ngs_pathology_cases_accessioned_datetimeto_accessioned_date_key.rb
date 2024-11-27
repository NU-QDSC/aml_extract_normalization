class RenameNgsPathologyCasesAccessionedDatetimetoAccessionedDateKey < ActiveRecord::Migration[7.1]
  def change
    rename_column :ngs_pathology_cases, :accessioned_datetime, :accessioned_date_key
  end
end
