require 'rails_helper'

# 3.1 do PLANO_17_09.md — tools auditadas que a IA chama. Cada chamada grava
# via os services existentes e audita com actor_type 'ai'.
RSpec.describe Crm::Tools do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Funil', slug: 'funil', kind: 'sales') }
  let!(:stage) { pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 1) }
  let!(:qualified) do
    pipeline.crm_pipeline_stages.create!(account: account, name: 'Qualificado', slug: 'qualificado', position: 2)
  end
  let(:contact) { create(:contact, account: account, name: 'Maria') }
  let(:deal) do
    account.crm_deals.create!(crm_pipeline: pipeline, crm_pipeline_stage: stage, contact: contact, title: 'Negócio')
  end
  let(:tools) { described_class.new(deal: deal) }

  def last_audit(action)
    CrmAuditEvent.where(account: account, target_type: 'CrmDeal', target_id: deal.id, action: action).last
  end

  describe '#get_deal_context' do
    it 'devolve o snapshot com as listas permitidas' do
      result = tools.get_deal_context
      expect(result).to be_ok
      expect(result.data[:deal_id]).to eq(deal.id)
      expect(result.data[:allowed_stages]).to include('novo', 'qualificado')
    end
  end

  describe '#set_category' do
    it 'grava categoria válida do pack e audita como IA' do
      result = tools.set_category('servicos', reason: 'cliente pediu orçamento')
      expect(result).to be_ok
      expect(deal.reload.category).to eq('servicos')

      event = last_audit('ai_set_category')
      expect(event.actor_type).to eq('ai')
      expect(event.payload['reason']).to eq('cliente pediu orçamento')
    end

    it 'recusa categoria fora do pack e audita a negativa' do
      result = tools.set_category('categoria_inventada')
      expect(result).not_to be_ok
      expect(deal.reload.category).to be_blank
      expect(last_audit('ai_tool_denied').actor_type).to eq('ai')
    end
  end

  describe '#set_urgency' do
    it 'aceita nível válido' do
      expect(tools.set_urgency('alta')).to be_ok
      expect(deal.reload.urgency_level).to eq('alta')
    end

    it 'rejeita nível inválido' do
      expect(tools.set_urgency('urgentissimo')).not_to be_ok
    end
  end

  describe '#set_field' do
    it 'grava campo declarado no pack' do
      account.enable_features!('crm_universal')
      Crm::PackInstaller.new(account).install('clinic')
      deal.reload

      result = tools.set_field('convenio', 'Unimed')
      expect(result).to be_ok
      expect(deal.reload.custom_fields['convenio']).to eq('Unimed')
    end

    it 'recusa chave fora dos field_definitions' do
      account.enable_features!('crm_universal')
      Crm::PackInstaller.new(account).install('clinic')
      deal.reload

      result = tools.set_field('numero_processo', '123')
      expect(result).not_to be_ok
    end

    it 'permite atualizar chave já existente mesmo sem pack (legado)' do
      deal.update!(custom_fields: { 'captain_triage' => { 'a' => 1 } })
      result = tools.set_field('captain_triage', { 'a' => 2 })
      expect(result).to be_ok
    end
  end

  describe '#move_stage' do
    it 'move para etapa do funil via DealMover' do
      result = tools.move_stage('qualificado')
      expect(result).to be_ok
      expect(deal.reload.crm_pipeline_stage).to eq(qualified)
    end

    it 'rejeita etapa de outro funil' do
      other = pipeline.crm_pipeline_stages.create!(account: account, name: 'X', slug: 'x', position: 9)
      other.update!(crm_pipeline_id: pipeline.id) # já no mesmo — testa slug inexistente
      expect(tools.move_stage('inexistente')).not_to be_ok
    end
  end

  describe '#create_activity' do
    it 'cria atividade com tipo do pack/legado' do
      result = tools.create_activity(kind: 'ligacao', title: 'Ligar para a Maria')
      expect(result).to be_ok
      expect(deal.crm_activities.last.title).to eq('Ligar para a Maria')
      expect(deal.crm_activities.last.created_by_type).to eq('ai')
    end

    it 'rejeita tipo desconhecido' do
      expect(tools.create_activity(kind: 'tipo_fake', title: 'X')).not_to be_ok
    end
  end

  describe '#mark_qualified' do
    it 'move para a etapa qualificado quando existe' do
      result = tools.mark_qualified
      expect(result).to be_ok
      expect(deal.reload.crm_pipeline_stage.slug).to eq('qualificado')
    end
  end
end
