# frozen_string_literal: true

class Crm::AccountInitializer
  DEFAULT_STAGES = [
    { name: 'Novo Lead', slug: 'novo-lead', position: 1, probability_pct: 10, color: '#3b82f6' },
    { name: 'Qualificação', slug: 'qualificacao', position: 2, probability_pct: 30, color: '#6366f1' },
    { name: 'Apresentação / Proposta', slug: 'apresentacao-proposta', position: 3, probability_pct: 60, color: '#a855f7' },
    { name: 'Negociação', slug: 'negociacao', position: 4, probability_pct: 80, color: '#ec4899' },
    { name: 'Fechamento', slug: 'fechamento', position: 5, probability_pct: 100, color: '#10b981' },
    { name: 'Perdido / Arquivado', slug: 'perdido-arquivado', position: 6, probability_pct: 0, color: '#ef4444' }
  ].freeze

  DEFAULT_LOSS_REASONS = [
    { name: 'Preço / Orçamento', slug: 'preco-orcamento', position: 1 },
    { name: 'Sem interesse no momento', slug: 'sem-interesse', position: 2 },
    { name: 'Escolheu concorrente', slug: 'escolheu-concorrente', position: 3 },
    { name: 'Sem contato / Não respondeu', slug: 'sem-contato', position: 4 },
    { name: 'Fora do perfil / Escopo', slug: 'fora-do-perfil', position: 5 },
    { name: 'Outros motivos', slug: 'outros', position: 6 }
  ].freeze

  def initialize(account)
    @account = account
  end

  def perform
    return if @account.blank?

    ActiveRecord::Base.transaction do
      ensure_default_pipeline
      ensure_default_loss_reasons
      ensure_default_pack
    end
  end

  private

  attr_reader :account

  def ensure_default_pipeline
    return if account.crm_pipelines.exists?

    pipeline = account.crm_pipelines.create!(
      name: 'Funil Comercial Padrão',
      slug: 'funil-comercial-padrao',
      kind: 'sales',
      is_default: true,
      position: 1,
      scoring_config: {
        'model' => 'standard-v1',
        'weights' => { 'engagement' => 35, 'fit' => 35, 'intent' => 30 }
      }
    )

    DEFAULT_STAGES.each do |stage_attrs|
      pipeline.crm_pipeline_stages.create!(stage_attrs.merge(account: account))
    end
  end

  def ensure_default_loss_reasons
    return if account.crm_loss_reasons.exists?

    DEFAULT_LOSS_REASONS.each do |reason_attrs|
      account.crm_loss_reasons.create!(reason_attrs)
    end
  end

  # Fase 2: conta nova nasce com o pack universal de vendas — nunca assume
  # o vertical jurídico. Contas antigas recebem o pack `legal` pelo rake
  # task crm:packs:install[legal].
  def ensure_default_pack
    return if account.crm_account_packs.exists?

    Crm::PackInstaller.new(account).install_default
  end
end
