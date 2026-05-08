require 'rails_helper'

RSpec.describe 'Contact categories API', type: :request do
  let!(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:category) do
    create(:label, account: account, title: 'df', category: 'location', slug: 'location.df', scope: 'contact', is_system: false)
  end
  let!(:legacy_label) { create(:label, account: account, title: 'legacy_label') }

  describe 'GET /api/v1/accounts/:account_id/contact_categories' do
    it 'returns contact categories only' do
      get "/api/v1/accounts/#{account.id}/contact_categories",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      titles = response.parsed_body['payload'].map { |item| item['title'] }
      expect(titles).to include('df')
      expect(titles).not_to include('legacy_label')
    end
  end

  describe 'POST /api/v1/accounts/:account_id/contact_categories' do
    it 'creates a contact category using a normalized title and slug' do
      post "/api/v1/accounts/#{account.id}/contact_categories",
           headers: admin.create_new_auth_token,
           params: { category: { name: 'Re-marketing', kind: 'campaign', color: '#0891b2' } },
           as: :json

      expect(response).to have_http_status(:success)
      label = account.labels.find_by!(slug: 'campaign.re-marketing')
      expect(label.title).to eq('re-marketing')
      expect(label.category).to eq('campaign')
      expect(label.scope).to eq('contact')
    end
  end

  describe 'POST /api/v1/accounts/:account_id/contact_categories/bulk_assign' do
    let!(:contact) { create(:contact, account: account) }

    it 'adds existing and new categories to contacts' do
      post "/api/v1/accounts/#{account.id}/contact_categories/bulk_assign",
           headers: admin.create_new_auth_token,
           params: {
             contact_ids: [contact.id],
             category_ids: [category.id],
             categories: ['Previdenciario'],
             kind: 'area'
           },
           as: :json

      expect(response).to have_http_status(:success)
      expect(contact.reload.label_list).to include('df', 'previdenciario')
      expect(account.labels.find_by!(title: 'previdenciario').category).to eq('area')
    end
  end

  describe 'POST /api/v1/accounts/:account_id/contact_categories/bulk_remove' do
    let!(:contact) { create(:contact, account: account, label_list: %w[df previdenciario]) }
    let!(:previdenciario) do
      create(:label, account: account, title: 'previdenciario', category: 'area', slug: 'area.previdenciario', scope: 'contact')
    end

    it 'removes selected categories from contacts' do
      post "/api/v1/accounts/#{account.id}/contact_categories/bulk_remove",
           headers: admin.create_new_auth_token,
           params: {
             contact_ids: [contact.id],
             category_ids: [previdenciario.id]
           },
           as: :json

      expect(response).to have_http_status(:success)
      expect(contact.reload.label_list).to include('df')
      expect(contact.label_list).not_to include('previdenciario')
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/contact_categories/:id' do
    let!(:contact) { create(:contact, account: account, label_list: %w[df]) }
    let!(:conversation) { create(:conversation, account: account, label_list: %w[df]) }

    it 'removes the category from linked contacts and conversations before deleting it' do
      delete "/api/v1/accounts/#{account.id}/contact_categories/#{category.id}",
             headers: admin.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:success)
      expect(account.labels.find_by(id: category.id)).to be_nil
      expect(contact.reload.label_list).not_to include('df')
      expect(conversation.reload.label_list).not_to include('df')
    end
  end
end
