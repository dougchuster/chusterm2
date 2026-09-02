# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class Qa::CanonicalFixture
  # Esta classe e um manifesto executavel: concentra deliberadamente todos os
  # registros que formam a fixture para manter a versao atomica e auditavel.
  VERSION = '2026-07-22.1'
  DEFAULT_DEAL_COUNT = 201
  # F0.3 do PLANO-KANBAN-CRM-2026.md mede o board com 2.000 negocios e a meta de
  # escala (F7.2) e 5.000 num unico pipeline. O teto cobre os dois cenarios.
  MAX_DEAL_COUNT = 5_000
  STAGES = [
    ['Novo', 'novo', 0, 10],
    ['Qualificacao', 'qualificacao', 1, 30],
    ['Proposta', 'proposta', 2, 55],
    ['Negociacao', 'negociacao', 3, 75],
    ['Ganho', 'ganho', 4, 100],
    ['Perdido', 'perdido', 5, 0]
  ].freeze
  PERSONAS = {
    admin: ['Administrador QA', 'administrator'],
    operator: ['Operador QA', 'agent'],
    seller: ['Vendedor QA', 'agent'],
    manager: ['Gestor QA', 'administrator'],
    knowledge_manager: ['Gestor de Conhecimento QA', 'agent']
  }.freeze
  CONTACT_SCENARIOS = %w[
    lead customer ex_customer unknown whatsapp_saved duplicated opt_out
  ].freeze

  class UnsafeEnvironmentError < StandardError; end

  def initialize(password:, namespace: 'f0', deal_count: DEFAULT_DEAL_COUNT, now: nil)
    @password = password.to_s
    @namespace = namespace.to_s.parameterize
    @deal_count = Integer(deal_count)
    @now = now.present? ? Time.zone.parse(now.to_s) : Time.zone.parse('2026-07-13 12:00:00')

    validate_inputs!
  end

  def call
    ActiveRecord::Base.transaction do
      accounts = seed_accounts
      users = seed_users(accounts)
      inboxes = seed_inboxes(accounts)
      seed_inbox_members(inboxes.fetch(:a), users)
      assistant = seed_captain(accounts.fetch(:a), inboxes.fetch(:a))
      pipelines = seed_pipelines(accounts, inboxes)
      seed_deals(accounts.fetch(:a), pipelines.fetch(:a), users.fetch(:seller), @deal_count)
      seed_deals(accounts.fetch(:b), pipelines.fetch(:b), users.fetch(:admin_b), 2)
      seed_conversations(accounts.fetch(:a), inboxes.fetch(:a), assistant, users.fetch(:operator))

      build_manifest(accounts, users, inboxes, pipelines)
    end
  end

  private

  def validate_inputs!
    if Rails.env.production? && !local_compose_target?
      raise UnsafeEnvironmentError, 'Em production, a fixture exige alvo local-compose, frontend local e banco local.'
    end
    raise ArgumentError, 'QA_FIXTURE_PASSWORD deve ter ao menos 12 caracteres.' if @password.length < 12
    raise ArgumentError, 'QA_FIXTURE_NAMESPACE nao pode ficar vazio.' if @namespace.blank?
    return if @deal_count.between?(7, MAX_DEAL_COUNT)

    raise ArgumentError, "QA_FIXTURE_DEAL_COUNT deve ficar entre 7 e #{MAX_DEAL_COUNT}."
  end

  def local_compose_target?
    frontend_url = ENV.fetch('FRONTEND_URL', '')
    database_host = ActiveRecord::Base.connection_db_config.configuration_hash[:host].to_s
    local_hosts = %w[localhost 127.0.0.1 ::1 postgres]

    ENV.fetch('QA_FIXTURE_TARGET', '') == 'local-compose' &&
      frontend_url.match?(%r{\Ahttps?://(localhost|127\.0\.0\.1)(:\d+)?(?:/|\z)}) &&
      local_hosts.include?(database_host)
  end

  def seed_accounts
    {
      a: upsert_account('a', 'Conta A QA', :active),
      b: upsert_account('b', 'Conta B QA', :active),
      suspended: upsert_account('suspended', 'Conta Suspensa QA', :suspended)
    }
  end

  def upsert_account(key, name, status)
    account = Account.find_or_initialize_by(domain: "qa-#{@namespace}-#{key}.invalid")
    account.assign_attributes(
      name: name,
      status: status,
      locale: :pt_BR,
      settings: (account.settings || {}).merge('reporting_timezone' => 'America/Sao_Paulo'),
      internal_attributes: (account.internal_attributes || {}).merge(
        'qa_fixture' => {
          'version' => VERSION,
          'namespace' => @namespace,
          'account_key' => key,
          'colliding_display_id' => 101
        }
      )
    )
    persist(account)
    account
  end

  def seed_users(accounts)
    users = PERSONAS.each_with_object({}) do |(persona, (name, role)), result|
      user = upsert_user(persona, name)
      membership = upsert_membership(accounts.fetch(:a), user, role)
      result[persona] = user
      result[:knowledge_membership] = membership if persona == :knowledge_manager
    end

    add_special_users(users, accounts)
    attach_minimal_custom_role(accounts.fetch(:a), users.fetch(:knowledge_membership))
    users.except(:knowledge_membership)
  end

  def add_special_users(users, accounts)
    users[:admin_b] = upsert_user(:admin_b, 'Administrador Conta B QA')
    upsert_membership(accounts.fetch(:b), users.fetch(:admin_b), 'administrator')
    users[:suspended_admin] = upsert_user(:suspended_admin, 'Administrador Suspenso QA')
    upsert_membership(accounts.fetch(:suspended), users.fetch(:suspended_admin), 'administrator')
    users[:no_account] = upsert_user(:no_account, 'Usuario Sem Conta QA')
    users[:super_admin] = upsert_super_admin
  end

  def upsert_user(persona, name)
    email = "qa+#{@namespace}-#{persona.to_s.tr('_', '-')}@chusterm.invalid"
    user = User.find_or_initialize_by(email: email)
    user.assign_attributes(
      name: name,
      password: @password,
      password_confirmation: @password,
      confirmed_at: user.confirmed_at || @now,
      custom_attributes: (user.custom_attributes || {}).merge(
        'qa_fixture_version' => VERSION,
        'qa_persona' => persona.to_s
      )
    )
    user.skip_confirmation_notification! if user.respond_to?(:skip_confirmation_notification!)
    user.save!
    user
  end

  def upsert_super_admin
    email = "qa+#{@namespace}-super-admin@chusterm.invalid"
    user = SuperAdmin.find_or_initialize_by(email: email)
    user.assign_attributes(
      name: 'Super Admin QA',
      password: @password,
      password_confirmation: @password,
      confirmed_at: user.confirmed_at || @now,
      custom_attributes: (user.custom_attributes || {}).merge('qa_fixture_version' => VERSION, 'qa_persona' => 'super_admin')
    )
    user.skip_confirmation_notification! if user.respond_to?(:skip_confirmation_notification!)
    user.save!
    user
  end

  def upsert_membership(account, user, role)
    membership = AccountUser.find_or_initialize_by(account: account, user: user)
    membership.assign_attributes(role: role, availability: :online)
    persist(membership)
    membership
  end

  def attach_minimal_custom_role(account, membership)
    custom_role = CustomRole.find_or_initialize_by(account: account, name: 'Conhecimento QA')
    custom_role.assign_attributes(
      description: 'Role minima da fixture canonica',
      permissions: ['knowledge_base_manage']
    )
    persist(custom_role)
    membership.update!(custom_role: custom_role)
  end

  def seed_inboxes(accounts)
    { a: upsert_api_inbox(accounts.fetch(:a), 'a'), b: upsert_api_inbox(accounts.fetch(:b), 'b') }
  end

  def seed_inbox_members(inbox, users)
    PERSONAS.each_key do |persona|
      member = InboxMember.find_or_initialize_by(inbox: inbox, user: users.fetch(persona))
      persist(member)
    end
  end

  def upsert_api_inbox(account, key)
    channel = Channel::Api.find_or_initialize_by(identifier: "qa-#{@namespace}-#{key}-api")
    channel.assign_attributes(
      account: account,
      webhook_url: nil,
      hmac_mandatory: false,
      additional_attributes: { 'qa_fixture_version' => VERSION }
    )
    persist(channel)

    inbox = Inbox.find_or_initialize_by(account: account, channel: channel)
    inbox.assign_attributes(
      name: "Inbox API QA #{key.upcase}",
      timezone: 'America/Sao_Paulo',
      enable_auto_assignment: false
    )
    persist(inbox)
    inbox
  end

  def seed_captain(account, inbox)
    account.enable_features!('captain_integration_v2', 'captain_tasks')
    assistant = Captain::Assistant.find_or_initialize_by(account: account, name: "CAPITAO QA #{@namespace.upcase}")
    assistant.assign_attributes(captain_attributes)
    persist(assistant)

    captain_inbox = CaptainInbox.find_or_initialize_by(inbox: inbox)
    captain_inbox.assign_attributes(captain_inbox_attributes(assistant))
    persist(captain_inbox)
    assistant
  end

  def captain_attributes
    {
      description: 'Assistente isolado da fixture canonica de QA',
      config: {
        'feature_faq' => true,
        'feature_memory' => true,
        'product_name' => 'ChusteRM QA',
        'llm_timeout_seconds' => 15,
        'llm_max_tokens' => 1_024
      },
      response_guidelines: ['Responder de forma humana e objetiva.', 'Nunca inventar dados do cliente.'],
      guardrails: ['Nao acessar dados de outra conta.', 'Transferir quando houver pedido humano.']
    }
  end

  def captain_inbox_attributes(assistant)
    {
      captain_assistant: assistant,
      enabled: true,
      auto_reply_enabled: true,
      ai_mode: 'auto',
      handoff_strategy: 'human_request',
      routing_config: { 'debounce_seconds' => 2 }
    }
  end

  def seed_pipelines(accounts, inboxes)
    accounts.slice(:a, :b).transform_values.with_index do |account, index|
      pipeline = upsert_pipeline(account, inboxes.fetch(index.zero? ? :a : :b))
      { pipeline: pipeline, stages: upsert_stages(account, pipeline), loss_reason: upsert_loss_reason(account) }
    end
  end

  def upsert_pipeline(account, inbox)
    pipeline = CrmPipeline.find_or_initialize_by(account: account, slug: "qa-#{@namespace}-vendas")
    pipeline.assign_attributes(
      inbox: inbox,
      name: 'Pipeline Comercial QA',
      kind: 'sales',
      is_default: true,
      position: 0,
      scoring_config: { 'fixture_version' => VERSION, 'thresholds' => [60, 75, 80, 90] }
    )
    persist(pipeline)
    pipeline
  end

  def upsert_stages(account, pipeline)
    STAGES.to_h do |name, slug, position, probability|
      stage = CrmPipelineStage.find_or_initialize_by(crm_pipeline: pipeline, slug: slug)
      stage.assign_attributes(account: account, name: name, position: position, probability_pct: probability,
                              color: stage_color(position))
      persist(stage)
      [slug, stage]
    end
  end

  def upsert_loss_reason(account)
    loss_reason = CrmLossReason.find_or_initialize_by(account: account, slug: 'sem-retorno')
    loss_reason.assign_attributes(name: 'Sem retorno', position: 0)
    persist(loss_reason)
    loss_reason
  end

  def seed_deals(account, pipeline_data, owner, count)
    count.times do |offset|
      ordinal = offset + 1
      scenario = CONTACT_SCENARIOS[offset] || 'lead'
      contact = upsert_contact(account, ordinal, scenario)
      upsert_deal(pipeline_data, owner, contact, ordinal, scenario)
    end
  end

  def upsert_contact(account, ordinal, scenario)
    identifier = format('qa-%<namespace>s-contact-%<ordinal>04d', namespace: @namespace, ordinal: ordinal)
    contact = Contact.find_or_initialize_by(account: account, identifier: identifier)
    relationship_status, lifecycle_stage = contact_lifecycle(scenario)
    contact.assign_attributes(
      name: format('Contato QA %<ordinal>04d', ordinal: ordinal),
      email: format('qa+%<namespace>s-contact-%<ordinal>04d@chusterm.invalid', namespace: @namespace, ordinal: ordinal),
      phone_number: format('+55119%08d', ordinal),
      contact_type: relationship_status == 'customer' ? :customer : :lead,
      relationship_status: relationship_status,
      lifecycle_stage: lifecycle_stage,
      additional_attributes: (contact.additional_attributes || {}).merge(
        'qa_fixture_version' => VERSION,
        'qa_scenario' => scenario,
        'campaign_opt_out' => scenario == 'opt_out',
        'whatsapp_saved_only' => scenario == 'whatsapp_saved'
      )
    )
    persist(contact)
    contact
  end

  def upsert_deal(pipeline_data, owner, contact, ordinal, scenario)
    pipeline = pipeline_data.fetch(:pipeline)
    status, stage_slug = deal_status_and_stage(scenario)
    deal = CrmDeal.find_or_initialize_by(
      account: contact.account,
      crm_pipeline: pipeline,
      title: format('Negocio QA %<ordinal>04d', ordinal: ordinal)
    )
    deal.assign_attributes(deal_attributes(pipeline_data, owner, contact, ordinal, scenario, status, stage_slug))
    persist(deal)
  end

  # rubocop:disable Metrics/ParameterLists
  def deal_attributes(pipeline_data, owner, contact, ordinal, scenario, status, stage_slug)
    stage = pipeline_data.fetch(:stages).fetch(stage_slug)
    {
      crm_pipeline_stage: stage, contact: contact, inbox: pipeline_data.fetch(:pipeline).inbox,
      owner_id: owner.id, assignee_id: owner.id, status: status,
      value_estimate_cents: 10_000 + (ordinal * 100),
      probability_pct: stage.probability_pct,
      score_total: (ordinal * 7) % 101,
      score_classification: CrmScoreClassification.classify((ordinal * 7) % 101),
      source: 'qa_fixture',
      summary: "Registro deterministico da fixture #{VERSION}",
      custom_fields: { 'qa_fixture_version' => VERSION, 'qa_ordinal' => ordinal, 'qa_scenario' => scenario }
    }.merge(deal_closure_attributes(status, pipeline_data.fetch(:loss_reason)))
  end

  # These methods intentionally keep the complete canonical QA scenarios
  # together so the fixture remains auditable and deterministic.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Rails/SkipsModelValidations
  def seed_conversations(account, inbox, assistant, operator)
    scenarios = [
      {
        key: 'lead_active', contact_ordinal: 1, ai_mode: 'auto', score: 64,
        classification: 'qualificado', assignee: nil,
        summary: 'Lead em triagem. Informou trabalho como autônomo e quer organizar o CNIS antes do pedido.',
        messages: [
          ['incoming', 'Olá, quero saber quando posso me aposentar. Tenho 55 anos e trabalho como autônomo.'],
          ['assistant', 'Entendi. Para organizar seu caso com segurança, você já tem um CNIS atualizado?'],
          ['incoming', 'Tenho o CNIS e alguns comprovantes de GPS.']
        ]
      },
      {
        key: 'customer_active', contact_ordinal: 2, ai_mode: 'auto', score: 76,
        classification: 'qualificado', assignee: nil,
        summary: 'Cliente já confirmado no CRM. A IA continua ativa para acolher e organizar a nova solicitação.',
        messages: [
          ['incoming', 'Já sou cliente do escritório e recebi uma exigência nova do INSS.'],
          ['assistant', 'Vou organizar isso com você. Qual é a data limite indicada na exigência?']
        ]
      },
      {
        key: 'human_takeover', contact_ordinal: 3, ai_mode: 'human_only', score: 88,
        classification: 'prioridade_alta', assignee: operator,
        handoff_reason: 'Cliente solicitou atendimento humano.', handoff_reason_code: 'customer_request',
        summary: 'Pedido negado com prazo informado. Atendimento assumido pela equipe para revisão documental.',
        messages: [
          ['incoming', 'Meu pedido foi negado e o prazo do recurso termina esta semana.'],
          ['assistant', 'Entendi a urgência. Vou registrar os pontos essenciais para a equipe responsável.'],
          ['incoming', 'Quero falar com uma pessoa agora.'],
          ['human', 'Olá, sou do time jurídico e vou continuar seu atendimento por aqui.']
        ]
      },
      {
        key: 'ai_resumed', contact_ordinal: 4, ai_mode: 'auto', score: 42,
        classification: 'nutrir', assignee: nil,
        summary: 'Atendimento humano concluído e IA retomada manualmente com o contexto preservado.',
        resumed: true,
        messages: [
          ['human', 'Conferi seus dados iniciais. Podemos continuar a coleta por aqui.'],
          ['incoming', 'Sim, posso enviar as informações que faltam.'],
          ['assistant', 'Perfeito. Você contribui atualmente como CLT, MEI, autônomo ou facultativo?']
        ]
      }
    ]

    scenarios.each_with_index do |scenario, index|
      seed_conversation_scenario(account, inbox, assistant, operator, scenario, index)
    end
  end

  def seed_conversation_scenario(account, inbox, assistant, operator, scenario, index)
    contact = account.contacts.find_by!(identifier: format('qa-%<namespace>s-contact-%<ordinal>04d',
                                                           namespace: @namespace, ordinal: scenario.fetch(:contact_ordinal)))
    contact_inbox = ContactInbox.find_or_initialize_by(contact: contact, inbox: inbox)
    contact_inbox.source_id ||= "qa-#{@namespace}-#{scenario.fetch(:key)}"
    persist(contact_inbox)

    conversation = Conversation.find_or_initialize_by(account: account, identifier: "qa-#{@namespace}-#{scenario.fetch(:key)}")
    conversation.assign_attributes(
      inbox: inbox,
      contact: contact,
      contact_inbox: contact_inbox,
      status: :pending,
      assignee: scenario[:assignee],
      priority: scenario.fetch(:score) >= 80 ? :urgent : :medium,
      waiting_since: @now - (index + 1).hours,
      last_activity_at: @now - index.minutes,
      additional_attributes: conversation.additional_attributes.to_h.merge(
        'qa_fixture_version' => VERSION,
        'qa_fixture_conversation' => scenario.fetch(:key)
      )
    )
    persist(conversation)
    conversation.messages.where(private: true).where('content LIKE ?', 'Auto-handoff:%').delete_all
    conversation.messages.where(message_type: :activity).where('content LIKE ?', '%pending clarification%').delete_all

    upsert_scenario_messages(account, inbox, conversation, assistant, operator, scenario)
    upsert_scenario_state(account, conversation, assistant, operator, scenario)
  end

  def upsert_scenario_messages(account, inbox, conversation, assistant, operator, scenario)
    rows = scenario.fetch(:messages).each_with_index.map do |(kind, content), index|
      sender = case kind
               when 'incoming' then conversation.contact
               when 'assistant' then assistant
               else operator
               end
      {
        account_id: account.id,
        inbox_id: inbox.id,
        conversation_id: conversation.id,
        message_type: kind == 'incoming' ? Message.message_types.fetch('incoming') : Message.message_types.fetch('outgoing'),
        content_type: Message.content_types.fetch('text'),
        status: Message.statuses.fetch('sent'),
        content: content,
        private: false,
        source_id: "qa-#{@namespace}-#{scenario.fetch(:key)}-#{index}",
        sender_type: sender.class.base_class.name,
        sender_id: sender.id,
        content_attributes: kind == 'assistant' ? { 'generated_by' => 'qa_fixture', 'chusterm_agent' => 'captain-qa' } : {},
        additional_attributes: { 'qa_fixture_version' => VERSION },
        created_at: @now - (scenario.fetch(:messages).length - index).minutes,
        updated_at: @now - (scenario.fetch(:messages).length - index).minutes
      }
    end
    Message.upsert_all(rows, unique_by: :index_messages_on_account_id_and_source_id_unique)

    return unless scenario.fetch(:key) == 'lead_active'

    audio_message = Message.find_by!(account_id: account.id, source_id: "qa-#{@namespace}-lead_active-2")
    attachment = Attachment.find_or_initialize_by(message: audio_message, external_url: 'https://qa.invalid/cnis-audio.ogg')
    attachment.assign_attributes(
      account: account,
      file_type: :audio,
      fallback_title: 'Áudio com contexto previdenciário',
      extension: 'ogg',
      meta: {
        'media_understanding_status' => 'completed',
        'transcribed_text' => 'Tenho o CNIS e alguns comprovantes de GPS.'
      }
    )
    persist(attachment)
  end

  def upsert_scenario_state(account, conversation, assistant, operator, scenario)
    deal = account.crm_deals.find_by(contact_id: conversation.contact_id)
    state = CaptainConversationState.find_or_initialize_by(conversation: conversation)
    score = scenario.fetch(:score)
    state.assign_attributes(
      account: account,
      contact: conversation.contact,
      captain_assistant: assistant,
      crm_deal: deal,
      ai_mode: scenario.fetch(:ai_mode),
      score_total: score,
      score_classification: scenario.fetch(:classification),
      score_payload: {
        'model' => 'qa-explainable-v2',
        'components' => {
          'fit' => { 'score' => [score / 3, 30].min, 'evidence' => 'Objetivo e área de interesse identificados.' },
          'urgency' => { 'score' => score >= 80 ? 25 : 8, 'evidence' => score >= 80 ? 'Prazo ou risco informado.' : 'Sem prazo crítico confirmado.' },
          'engagement' => { 'score' => 10, 'evidence' => 'Cliente respondeu às perguntas de triagem.' }
        },
        'automatic_handoff' => false
      },
      context_summary: scenario.fetch(:summary),
      handoff_reason: scenario[:handoff_reason],
      handoff_reason_code: scenario[:handoff_reason_code],
      handoff_at: scenario[:handoff_reason] ? @now : nil,
      handoff_by: scenario[:handoff_reason] ? operator : nil,
      last_ai_message_at: @now - 1.minute
    )
    if scenario[:resumed]
      state.resume_source = CaptainConversationState::RESUME_SOURCE_MANUAL
      state.resumed_at = @now - 2.minutes
      state.resumed_by = operator
    end
    persist(state)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Rails/SkipsModelValidations
  # rubocop:enable Metrics/ParameterLists

  def deal_closure_attributes(status, loss_reason)
    defaults = {
      operational_status: 'active', crm_loss_reason: nil, lost_reason_note: nil,
      closed_at: nil, archived_at: nil, disposed_at: nil, disposition_reason: nil
    }
    return defaults.merge(closed_at: @now) if status == 'won'
    return defaults.merge(crm_loss_reason: loss_reason, lost_reason_note: 'Sem retorno no cenario controlado', closed_at: @now) if status == 'lost'
    return defaults unless status == 'archived'

    defaults.merge(operational_status: 'archived', closed_at: @now, archived_at: @now, disposed_at: @now,
                   disposition_reason: 'duplicated')
  end

  def contact_lifecycle(scenario)
    case scenario
    when 'customer' then %w[customer customer]
    when 'ex_customer' then %w[customer ex_customer]
    else %w[lead lead]
    end
  end

  def persist(record)
    record.save! if record.new_record? || record.has_changes_to_save?
    record
  end

  def deal_status_and_stage(scenario)
    case scenario
    when 'customer' then %w[won ganho]
    when 'ex_customer' then %w[lost perdido]
    when 'duplicated' then %w[archived perdido]
    else %w[open novo]
    end
  end

  def stage_color(position)
    %w[#3B82F6 #8B5CF6 #F59E0B #EC4899 #10B981 #EF4444].fetch(position)
  end

  def build_manifest(accounts, users, inboxes, pipelines)
    {
      version: VERSION,
      namespace: @namespace,
      reference_time: @now.iso8601,
      credentials: users.transform_values(&:email),
      account_ids: accounts.transform_values(&:id),
      inbox_ids: inboxes.transform_values(&:id),
      pipeline_ids: pipelines.transform_values { |data| data.fetch(:pipeline).id },
      deal_counts: {
        account_a: accounts.fetch(:a).crm_deals.where(source: 'qa_fixture').count,
        account_b: accounts.fetch(:b).crm_deals.where(source: 'qa_fixture').count
      },
      account_a_value_cents: accounts.fetch(:a).crm_deals.where(source: 'qa_fixture').sum(:value_estimate_cents)
    }
  end
end
# rubocop:enable Metrics/ClassLength
