module Devise
  module Models
    module PasswordHasRequiredContent
      extend ActiveSupport::Concern

      SPECIAL_CHARACTERS = " !@#$%^&*()_+-=[]{}|\"/\\.,`<>:;?~'".freeze

      included do
        validate :validate_password_required_content, if: :password_required?
      end

      private

      def validate_password_required_content
        validate_password_value(:password, password)
        validate_password_value(:password_confirmation, password_confirmation) if password_confirmation.present?
      end

      def validate_password_value(attribute, value)
        return if value.blank?

        requirements.each do |type, required_count|
          next if value.scan(pattern_for(type)).length >= required_count

          errors.add(
            attribute,
            I18n.t(
              'secure_password.password_has_required_content.errors.messages.minimum_characters',
              count: required_count,
              type: I18n.t("secure_password.types.#{type}"),
              subject: I18n.t('secure_password.character', count: required_count)
            )
          )
        end

        unknown_count = value.each_char.count { |character| character !~ /[A-Za-z0-9]/ && !SPECIAL_CHARACTERS.include?(character) }
        return if unknown_count.zero?

        errors.add(
          attribute,
          I18n.t(
            'secure_password.password_has_required_content.errors.messages.unknown_characters',
            count: unknown_count,
            subject: I18n.t('secure_password.character', count: unknown_count)
          )
        )
      end

      def requirements
        {
          uppercase: Devise.password_required_uppercase_count,
          lowercase: Devise.password_required_lowercase_count,
          number: Devise.password_required_number_count,
          special: Devise.password_required_special_character_count
        }
      end

      def pattern_for(type)
        {
          uppercase: /[A-Z]/,
          lowercase: /[a-z]/,
          number: /[0-9]/,
          special: /[#{Regexp.escape(SPECIAL_CHARACTERS)}]/
        }.fetch(type)
      end
    end
  end
end
