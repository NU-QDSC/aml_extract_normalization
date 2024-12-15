class AddNormalizationMethodToPathologyCases < ActiveRecord::Migration[7.1]
  def change
    add_column :pathology_cases, :normalization_method, :string
  end
end
