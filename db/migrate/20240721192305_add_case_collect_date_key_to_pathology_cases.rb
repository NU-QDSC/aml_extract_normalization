class AddCaseCollectDateKeyToPathologyCases < ActiveRecord::Migration[7.1]
  def change
   add_column :pathology_cases, :case_collect_date_key, :date
  end
end
