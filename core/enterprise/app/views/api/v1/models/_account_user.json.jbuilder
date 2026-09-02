json.custom_role_id account_user&.try(:custom_role_id)
json.custom_role account_user&.try(:custom_role)&.as_json(only: [:id, :name, :description, :permissions])
