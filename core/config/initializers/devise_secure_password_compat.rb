require Rails.root.join('lib/devise/models/password_has_required_content')

module Devise
  mattr_accessor :password_required_uppercase_count, default: 1
  mattr_accessor :password_required_lowercase_count, default: 1
  mattr_accessor :password_required_number_count, default: 1
  mattr_accessor :password_required_special_character_count, default: 1
end

Devise.add_module(
  :password_has_required_content,
  model: 'devise/models/password_has_required_content'
)
