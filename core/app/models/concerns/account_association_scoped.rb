module AccountAssociationScoped
  extend ActiveSupport::Concern

  class_methods do
    def validates_same_account_for(*association_names)
      association_names.each do |association_name|
        validate do |record|
          association = record.public_send(association_name)
          next if association.nil? || record.account_id.blank?
          next if association.respond_to?(:account_id) && association.account_id == record.account_id

          record.errors.add(association_name, 'must belong to the same account')
        end
      end
    end
  end
end
