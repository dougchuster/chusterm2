require 'rails_helper'

# F1.4 do PLANO-KANBAN-CRM-2026.md — filtrar deixa de ser trabalho do navegador.
# Hoje o board busca todos os negocios do pipeline e filtra em JavaScript
# (lacuna K-01); estes filtros existem para que o front nunca receba mais do que
# a coluna precisa mostrar.
RSpec.describe Crm::DealFilterService do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Kanban', slug: 'kanban', kind: 'legal_intake') }
  let(:novo) { pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 0) }
  let(:qualificado) do
    pipeline.crm_pipeline_stages.create!(account: account, name: 'Qualificado', slug: 'qualificado', position: 1)
  end
  let(:proposta) do
    pipeline.crm_pipeline_stages.create!(account: account, name: 'Proposta', slug: 'proposta', position: 2)
  end

  def build_deal(title, stage: novo, **attrs)
    account.crm_deals.create!(
      { crm_pipeline: pipeline, crm_pipeline_stage: stage, title: title }.merge(attrs)
    )
  end

  def titles(filters)
    described_class.new(scope: account.crm_deals, filters: filters).perform.pluck(:title).sort
  end

  describe 'stage_id as a list' do
    it 'keeps the single-value form working' do
      build_deal('No novo')
      build_deal('No qualificado', stage: qualificado)

      expect(titles(stage_id: novo.id)).to eq(['No novo'])
    end

    it 'accepts several stages at once' do
      build_deal('No novo')
      build_deal('No qualificado', stage: qualificado)
      build_deal('Na proposta', stage: proposta)

      expect(titles(stage_id: [novo.id, proposta.id])).to eq(['Na proposta', 'No novo'])
    end
  end

  describe 'owner_id as a list' do
    let(:ana) { create(:user, account: account) }
    let(:bruno) { create(:user, account: account) }

    it 'accepts several owners at once' do
      build_deal('Da Ana', owner_id: ana.id)
      build_deal('Do Bruno', owner_id: bruno.id)
      build_deal('Sem dono')

      expect(titles(owner_id: [ana.id, bruno.id])).to eq(['Da Ana', 'Do Bruno'])
    end

    it 'still understands __unassigned' do
      build_deal('Da Ana', owner_id: ana.id)
      build_deal('Sem dono')

      expect(titles(owner_id: '__unassigned')).to eq(['Sem dono'])
    end

    it 'mixes __unassigned with real owners' do
      build_deal('Da Ana', owner_id: ana.id)
      build_deal('Do Bruno', owner_id: bruno.id)
      build_deal('Sem dono')

      expect(titles(owner_id: [ana.id, '__unassigned'])).to eq(['Da Ana', 'Sem dono'])
    end
  end

  describe 'operational_status as a list' do
    it 'accepts several statuses at once' do
      build_deal('Ativo', operational_status: 'active')
      build_deal('Cliente base', operational_status: 'base_client')
      build_deal('Spam', operational_status: 'spam')

      expect(titles(operational_status: %w[active base_client])).to eq(['Ativo', 'Cliente base'])
    end
  end

  describe 'value range' do
    it 'filters by minimum value' do
      build_deal('Barato', value_estimate_cents: 100_000)
      build_deal('Caro', value_estimate_cents: 5_000_000)

      expect(titles(value_min: 1_000_000)).to eq(['Caro'])
    end

    it 'filters by maximum value' do
      build_deal('Barato', value_estimate_cents: 100_000)
      build_deal('Caro', value_estimate_cents: 5_000_000)

      expect(titles(value_max: 1_000_000)).to eq(['Barato'])
    end

    it 'filters by a closed range' do
      build_deal('Barato', value_estimate_cents: 100_000)
      build_deal('Medio', value_estimate_cents: 2_000_000)
      build_deal('Caro', value_estimate_cents: 9_000_000)

      expect(titles(value_min: 1_000_000, value_max: 5_000_000)).to eq(['Medio'])
    end
  end

  describe 'creation window' do
    it 'filters by created_after' do
      build_deal('Antigo', created_at: 10.days.ago)
      build_deal('Recente', created_at: 1.day.ago)

      expect(titles(created_after: 5.days.ago.iso8601)).to eq(['Recente'])
    end

    it 'filters by created_before' do
      build_deal('Antigo', created_at: 10.days.ago)
      build_deal('Recente', created_at: 1.day.ago)

      expect(titles(created_before: 5.days.ago.iso8601)).to eq(['Antigo'])
    end

    it 'ignores a date it cannot parse instead of returning nothing' do
      build_deal('Qualquer um')

      expect(titles(created_after: 'ontem de tarde')).to eq(['Qualquer um'])
    end
  end

  describe 'pending activity' do
    def add_activity(deal, completed: false, system: false)
      deal.crm_activities.create!(
        account: account,
        kind: 'follow_up',
        title: 'Ligar',
        completed_at: completed ? Time.current : nil,
        created_by_type: system ? 'system' : 'user'
      )
    end

    it 'keeps only deals with something still open' do
      com = build_deal('Com pendencia')
      add_activity(com)
      sem = build_deal('Sem pendencia')
      add_activity(sem, completed: true)

      expect(titles(has_pending_activity: true)).to eq(['Com pendencia'])
    end

    # O bloco vermelho "sem proxima acao" do card, e a meta de menos de 10% do
    # plano, dependem exatamente do inverso.
    it 'can ask for the deals with no next action at all' do
      com = build_deal('Com pendencia')
      add_activity(com)
      build_deal('Sem proxima acao')

      expect(titles(has_pending_activity: false)).to eq(['Sem proxima acao'])
    end

    # `crm_activities.crm_deal_id` e anulavel — agenda avulsa nao tem negocio. O
    # banco local ja tinha 7 dessas em 243 atividades. Com `NOT IN`, uma unica
    # linha assim fazia a subconsulta devolver NULL e o board inteiro sumia ao
    # pedir "sem proxima acao". Sem erro, sem log, board vazio.
    it 'survives activities that belong to no deal at all' do
      account.crm_activities.create!(kind: 'reuniao', title: 'Agenda avulsa', crm_deal_id: nil)
      com = build_deal('Com pendencia')
      add_activity(com)
      build_deal('Sem proxima acao')

      expect(titles(has_pending_activity: false)).to eq(['Sem proxima acao'])
      expect(titles(stale: false)).to eq(['Com pendencia', 'Sem proxima acao'])
    end

    it 'finds the rotting deals the StaleDetectorJob marked' do
      parado = build_deal('Parado')
      add_activity(parado, system: true)
      ativo = build_deal('Ativo')
      add_activity(ativo)

      expect(titles(stale: true)).to eq(['Parado'])
    end

    it 'can ask for the deals that are not rotting' do
      parado = build_deal('Parado')
      add_activity(parado, system: true)
      build_deal('Ativo')

      expect(titles(stale: false)).to eq(['Ativo'])
    end
  end

  describe 'ai_mode' do
    let(:inbox) { create(:inbox, account: account) }

    # Um contato por negocio: o CrmDeal so aceita um lead aberto por contato em
    # cada pipeline.
    def conversation_with_mode(mode)
      contact = create(:contact, account: account)
      conversation = create(:conversation, account: account, inbox: inbox)
      account.captain_conversation_states.create!(conversation: conversation, contact: contact, ai_mode: mode)
      conversation
    end

    it 'filters by the state of the AI on the conversation' do
      build_deal('IA conduzindo', conversation: conversation_with_mode('auto'))
      build_deal('Humano assumiu', conversation: conversation_with_mode('human_only'))

      expect(titles(ai_mode: 'auto')).to eq(['IA conduzindo'])
    end

    it 'accepts several modes at once' do
      build_deal('IA conduzindo', conversation: conversation_with_mode('auto'))
      build_deal('IA pausada', conversation: conversation_with_mode('paused'))
      build_deal('Humano assumiu', conversation: conversation_with_mode('human_only'))

      expect(titles(ai_mode: %w[auto paused])).to eq(['IA conduzindo', 'IA pausada'])
    end

    it 'leaves out deals with no conversation at all' do
      build_deal('Sem conversa')
      build_deal('IA conduzindo', conversation: conversation_with_mode('auto'))

      expect(titles(ai_mode: 'auto')).to eq(['IA conduzindo'])
    end
  end

  # Etiqueta nao vive no negocio: o LegalLabelSync escreve na conversa e no
  # contato. Filtrar pelo negocio e, entao, filtrar pelos dois.
  describe 'label' do
    let(:inbox) { create(:inbox, account: account) }

    it 'finds the deal through the label on its conversation' do
      etiquetada = create(:conversation, account: account, inbox: inbox)
      etiquetada.update!(label_list: ['area_trabalhista'])
      build_deal('Com etiqueta', conversation: etiquetada)
      build_deal('Sem etiqueta', conversation: create(:conversation, account: account, inbox: inbox))

      expect(titles(label: 'area_trabalhista')).to eq(['Com etiqueta'])
    end

    it 'finds the deal through the label on its contact' do
      contato = create(:contact, account: account)
      contato.update!(label_list: ['rel_cliente'])
      build_deal('Contato etiquetado', contact: contato)
      build_deal('Contato sem etiqueta', contact: create(:contact, account: account))

      expect(titles(label: 'rel_cliente')).to eq(['Contato etiquetado'])
    end

    it 'accepts several labels at once' do
      um = create(:contact, account: account)
      um.update!(label_list: ['rel_cliente'])
      outro = create(:contact, account: account)
      outro.update!(label_list: ['temp_quente'])
      build_deal('Cliente', contact: um)
      build_deal('Quente', contact: outro)
      build_deal('Nenhuma', contact: create(:contact, account: account))

      expect(titles(label: %w[rel_cliente temp_quente])).to eq(%w[Cliente Quente])
    end
  end

  describe 'search' do
    it 'accepts q as an alias of search' do
      build_deal('Revisao de beneficio')
      build_deal('Outro assunto')

      expect(titles(q: 'revisao')).to eq(['Revisao de beneficio'])
    end

    it 'searches the legal area' do
      build_deal('Sem area')
      build_deal('Com area', legal_area: 'trabalhista')

      expect(titles(q: 'trabalhista')).to eq(['Com area'])
    end

    it 'searches the case type' do
      build_deal('Sem tipo')
      build_deal('Com tipo', case_type: 'rescisao indireta')

      expect(titles(q: 'rescisao')).to eq(['Com tipo'])
    end
  end

  describe 'combining filters' do
    it 'applies every criterion together' do
      alvo = build_deal('Alvo', stage: qualificado, operational_status: 'active',
                                value_estimate_cents: 2_000_000, score_total: 70)
      alvo.crm_activities.create!(account: account, kind: 'follow_up', title: 'Ligar')
      build_deal('Etapa errada', operational_status: 'active', value_estimate_cents: 2_000_000, score_total: 70)
      build_deal('Valor baixo', stage: qualificado, operational_status: 'active',
                                value_estimate_cents: 10_000, score_total: 70)
      build_deal('Sem pendencia', stage: qualificado, operational_status: 'active',
                                  value_estimate_cents: 2_000_000, score_total: 70)

      result = titles(
        stage_id: [qualificado.id, proposta.id],
        operational_status: %w[active base_client],
        value_min: 1_000_000,
        score_min: 50,
        has_pending_activity: true
      )

      expect(result).to eq(['Alvo'])
    end

    # `filter_by_owner` usa `.or`, que exige os dois lados com a mesma estrutura
    # de joins. A busca e a unica etapa que adiciona `left_joins(:contact)`, e por
    # isso ela roda por ultimo. Este teste existe para quebrar se alguem reordenar
    # o pipeline de filtros e o `.or` passar a ver um join de um lado so.
    it 'combines the unassigned owner alternative with a search term' do
      ana = create(:user, account: account)
      build_deal('Alvo sem dono', legal_area: 'trabalhista')
      build_deal('Alvo da Ana', owner_id: ana.id, legal_area: 'trabalhista')
      build_deal('Outra area sem dono', legal_area: 'civel')

      expect(titles(owner_id: [ana.id, '__unassigned'], q: 'trabalhista'))
        .to eq(['Alvo da Ana', 'Alvo sem dono'])
    end

    it 'returns everything when no filter is given' do
      build_deal('Um')
      build_deal('Dois')

      expect(titles({})).to eq(%w[Dois Um])
    end
  end

  # As subconsultas novas (atividade, estado da IA, etiqueta) nao carregam
  # `account_id`: o escopo de conta vem do `scope` recebido. Isso e seguro porque
  # os ids sao globais e um negocio da conta A so casa com linhas que apontam
  # para ele. Estes testes existem para que continue verdade — sao o embriao dos
  # invariantes de isolamento que a F6.2 vai levar para o CI.
  describe 'tenant isolation of the new subqueries' do
    let(:vizinha) { create(:account) }
    let(:vizinha_pipeline) do
      vizinha.crm_pipelines.create!(name: 'Vizinha', slug: 'vizinha', kind: 'legal_intake')
    end
    let(:vizinha_stage) do
      vizinha_pipeline.crm_pipeline_stages.create!(account: vizinha, name: 'Novo', slug: 'novo-viz', position: 0)
    end
    let(:vizinha_inbox) { create(:inbox, account: vizinha) }

    def vizinha_deal(title, **attrs)
      vizinha.crm_deals.create!(
        { crm_pipeline: vizinha_pipeline, crm_pipeline_stage: vizinha_stage, title: title }.merge(attrs)
      )
    end

    it 'never returns a deal from another account through the activity filter' do
      alheio = vizinha_deal('Da vizinha')
      alheio.crm_activities.create!(account: vizinha, kind: 'follow_up', title: 'Ligar')
      meu = build_deal('Meu')
      meu.crm_activities.create!(account: account, kind: 'follow_up', title: 'Ligar')

      expect(titles(has_pending_activity: true)).to eq(['Meu'])
    end

    it 'never returns a deal from another account through the ai_mode filter' do
      contato_alheio = create(:contact, account: vizinha)
      conversa_alheia = create(:conversation, account: vizinha, inbox: vizinha_inbox, contact: contato_alheio)
      vizinha.captain_conversation_states.create!(
        conversation: conversa_alheia, contact: contato_alheio, ai_mode: 'auto'
      )
      vizinha_deal('Da vizinha', conversation: conversa_alheia, contact: contato_alheio)

      expect(titles(ai_mode: 'auto')).to eq([])
    end

    it 'never returns a deal from another account through the label filter' do
      contato_alheio = create(:contact, account: vizinha)
      contato_alheio.update!(label_list: ['rel_cliente'])
      vizinha_deal('Da vizinha', contact: contato_alheio)

      expect(titles(label: 'rel_cliente')).to eq([])
    end

    it 'does not let another account activity hide my deal from the no-next-action filter' do
      alheio = vizinha_deal('Da vizinha')
      alheio.crm_activities.create!(account: vizinha, kind: 'follow_up', title: 'Ligar')
      build_deal('Sem proxima acao')

      expect(titles(has_pending_activity: false)).to eq(['Sem proxima acao'])
    end
  end

  # 2.4: filtro por campos do pack — só chaves declaradas em
  # crm_field_definitions da conta entram na query.
  describe 'custom_fields filter' do
    def titles_with_account(filters)
      described_class.new(scope: account.crm_deals, filters: filters, account: account).perform.pluck(:title).sort
    end

    before do
      account.crm_field_definitions.create!(
        key: 'cor_preferida', label: 'Cor preferida', field_type: 'select',
        options: [{ 'value' => 'azul' }, { 'value' => 'verde' }], applies_to: 'deal'
      )
    end

    it 'filters deals by a declared pack field' do
      build_deal('Azul', custom_fields: { 'cor_preferida' => 'azul' })
      build_deal('Verde', custom_fields: { 'cor_preferida' => 'verde' })
      build_deal('Sem cor')

      expect(titles_with_account(custom_fields: { cor_preferida: 'azul' })).to eq(['Azul'])
    end

    it 'accepts a list of values for the same key' do
      build_deal('Azul', custom_fields: { 'cor_preferida' => 'azul' })
      build_deal('Verde', custom_fields: { 'cor_preferida' => 'verde' })
      build_deal('Sem cor')

      expect(titles_with_account(custom_fields: { cor_preferida: %w[azul verde] }))
        .to eq(%w[Azul Verde])
    end

    it 'ignores keys not declared in the account field definitions' do
      build_deal('Azul', custom_fields: { 'cor_preferida' => 'azul', 'chave_livre' => 'x' })

      expect(titles_with_account(custom_fields: { chave_livre: 'x' })).to eq(['Azul'])
    end
  end
end
