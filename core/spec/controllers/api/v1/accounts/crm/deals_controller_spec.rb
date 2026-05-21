require 'rails_helper'

RSpec.describe 'CRM Deals API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }
  let(:pipeline) { CrmPipeline.create!(account: account, name: 'Pipeline Jurídico', position: 1, is_default: true) }
  let(:stage) { CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Novo atendimento', position: 1) }
  let(:qualified_stage) { CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Qualificado', position: 2) }

  def create_deal!(title:, stage: self.stage, **attrs)
    CrmDeal.create!(
      {
        account: account,
        crm_pipeline: pipeline,
        crm_pipeline_stage: stage,
        title: title
      }.merge(attrs)
    )
  end

  describe 'POST /api/v1/accounts/:account_id/crm/deals' do
    it 'creates a lead with a simple contact payload' do
      post "/api/v1/accounts/#{account.id}/crm/deals",
           params: {
             title: 'Revisão de benefício',
             crm_pipeline_id: pipeline.id,
             crm_pipeline_stage_id: stage.id,
             contact_name: 'Maria Silva',
             contact_phone_number: '61999999999',
             contact_email: 'maria@example.com',
             source: 'indicacao',
             source_detail: 'Cliente antigo'
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      deal = account.crm_deals.last
      expect(deal.title).to eq('Revisão de benefício')
      expect(deal.source_detail).to eq('Cliente antigo')
      expect(deal.contact.name).to eq('Maria Silva')
      expect(deal.contact.phone_number).to eq('+5561999999999')
      expect(deal.contact.email).to eq('maria@example.com')
      expect(deal.contact).to be_lead
    end
  end

  describe 'POST /api/v1/accounts/:account_id/crm/deals/bulk_action' do
    it 'permanently deletes selected leads' do
      first_deal = create_deal!(title: 'Lead 1')
      second_deal = create_deal!(title: 'Lead 2')
      kept_deal = create_deal!(title: 'Lead mantido')

      post "/api/v1/accounts/#{account.id}/crm/deals/bulk_action",
           params: {
             bulk_action: 'destroy',
             deal_ids: [first_deal.id, second_deal.id]
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('requested' => 2, 'processed' => 2)
      expect(account.crm_deals.where(id: [first_deal.id, second_deal.id])).to be_empty
      expect(account.crm_deals.exists?(kept_deal.id)).to be(true)
    end

    it 'deletes every lead matching the submitted filters' do
      matching_deal = create_deal!(title: 'Lead previdenciário', legal_area: 'previdenciario', urgency_level: 'alta')
      other_area_deal = create_deal!(title: 'Lead trabalhista', legal_area: 'trabalhista', urgency_level: 'alta')
      other_stage_deal = create_deal!(
        title: 'Lead qualificado',
        stage: qualified_stage,
        legal_area: 'previdenciario',
        urgency_level: 'alta'
      )

      post "/api/v1/accounts/#{account.id}/crm/deals/bulk_action",
           params: {
             bulk_action: 'destroy',
             select_all: true,
             filters: {
               pipeline_id: pipeline.id,
               stage_id: stage.id,
               legal_area: 'previdenciario',
               urgency: 'alta'
             }
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('requested' => 1, 'processed' => 1)
      expect(account.crm_deals.exists?(matching_deal.id)).to be(false)
      expect(account.crm_deals.exists?(other_area_deal.id)).to be(true)
      expect(account.crm_deals.exists?(other_stage_deal.id)).to be(true)
    end
  end
end
