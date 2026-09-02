# frozen_string_literal: true

# Read-only runtime verification for the Dra. Letícia intake profile.
# The legacy filename is kept so existing deployment commands continue to work.
#
# Usage:
#   ACCOUNT_ID=1 INBOX_ID=3 bundle exec rails runner \
#     /app/scripts/captain/verify_dr_paula_runtime.rb

require 'json'
require 'securerandom'

PROFILE_KEY = 'dra_leticia_intake'
ASSISTANT_NAME = 'Dra. Letícia'
LEGACY_ASSISTANT_NAME = 'Dra. Paula Matos'
PUBLIC_IDENTITY = 'Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos'
WELCOME_MESSAGE =
  'Olá! Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos. Como posso ajudar você hoje?'
NEW_LEAD_NOTICE =
  'Depois deste atendimento inicial, a equipe analisará seu caso com atenção e entrará em contato em breve por aqui.'

def assert_check!(condition, message)
  raise "VERIFY_FAILED: #{message}" unless condition
end

def normalized(text)
  I18n.transliterate(text.to_s).downcase
end

def negative_runtime_id
  -(SecureRandom.random_number(1_000_000_000) + 1)
end

# Exercises the real persisted-policy code path without leaving records or
# advancing application sequences. All temporary rows use negative ids and the
# transaction is always rolled back before this method returns.
# rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/BlockLength, Rails/SkipsModelValidations
def with_isolated_policy_conversation(account:, assistant:, inbox:, message:)
  result = nil
  ActiveRecord::Base.transaction(requires_new: true) do
    now = Time.current
    contact_id = negative_runtime_id
    conversation_id = negative_runtime_id
    message_id = -(SecureRandom.random_number(500_000_000) + 1_500_000_000)
    state_id = negative_runtime_id

    Contact.insert_all!([{
                          id: contact_id,
                          account_id: account.id,
                          name: 'Lead de verificação isolada',
                          identifier: "dra-leticia-runtime-verifier-#{SecureRandom.uuid}",
                          contact_type: Contact.contact_types.fetch('lead'),
                          lifecycle_stage: 'lead',
                          relationship_status: 'lead',
                          created_at: now,
                          updated_at: now
                        }])
    Conversation.insert_all!([{
                               id: conversation_id,
                               account_id: account.id,
                               inbox_id: inbox.id,
                               contact_id: contact_id,
                               display_id: negative_runtime_id,
                               created_at: now,
                               updated_at: now
                             }])
    Message.insert_all!([{
                          id: message_id,
                          account_id: account.id,
                          inbox_id: inbox.id,
                          conversation_id: conversation_id,
                          message_type: Message.message_types.fetch('incoming'),
                          content_type: Message.content_types.fetch('text'),
                          status: Message.statuses.fetch('sent'),
                          content: message,
                          private: false,
                          sender_type: 'Contact',
                          sender_id: contact_id,
                          created_at: now,
                          updated_at: now
                        }])
    CaptainConversationState.insert_all!([{
                                           id: state_id,
                                           account_id: account.id,
                                           conversation_id: conversation_id,
                                           contact_id: contact_id,
                                           captain_assistant_id: assistant.id,
                                           created_at: now,
                                           updated_at: now
                                         }])

    result = yield Conversation.find(conversation_id), message_id
    raise ActiveRecord::Rollback
  end
  result
end

def insert_isolated_message!(conversation:, id:, type:, sender:, content:)
  now = Time.current
  Message.insert_all!([{
                        id: id,
                        account_id: conversation.account_id,
                        inbox_id: conversation.inbox_id,
                        conversation_id: conversation.id,
                        message_type: Message.message_types.fetch(type),
                        content_type: Message.content_types.fetch('text'),
                        status: Message.statuses.fetch('sent'),
                        content: content,
                        private: false,
                        sender_type: sender.class.base_class.name,
                        sender_id: sender.id,
                        created_at: now,
                        updated_at: now
                      }])
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/BlockLength, Rails/SkipsModelValidations

account = Account.find(ENV.fetch('ACCOUNT_ID', 1))
assistant_scope = Captain::Assistant.where(account: account)
assistant = assistant_scope.find { |candidate| candidate.config.to_h['profile_key'] == PROFILE_KEY } ||
            assistant_scope.find_by!(name: ASSISTANT_NAME)
inbox_id = Integer(ENV['INBOX_ID'], 10) if ENV['INBOX_ID'].present?
linked_captain_inboxes = CaptainInbox.includes(:inbox).where(captain_assistant: assistant).to_a
linked_inbox_ids = linked_captain_inboxes.map(&:inbox_id).sort
assert_check!(linked_captain_inboxes.any?, 'at least one Captain inbox link is required')
assert_check!(
  linked_captain_inboxes.all? { |link| link.inbox.account_id == account.id },
  'every linked inbox must belong to the assistant account'
)

managed_inbox_ids = Array(assistant.config.to_h['managed_inbox_ids']).map { |id| Integer(id.to_s, 10) }.uniq.sort
campaign_inbox_ids = Campaign.where(account: account, captain_assistant: assistant).where.not(inbox_id: nil).distinct.pluck(:inbox_id).sort
expected_inbox_ids = (linked_inbox_ids + managed_inbox_ids + campaign_inbox_ids + [inbox_id]).compact.uniq.sort
relevant_captain_inboxes = CaptainInbox.includes(:inbox).where(inbox_id: expected_inbox_ids).index_by(&:inbox_id)
verification_inbox_id = inbox_id || linked_inbox_ids.min
verification_inbox = account.inboxes.find_by(id: verification_inbox_id)
assert_check!(verification_inbox.present?, "inbox #{verification_inbox_id} must belong to account #{account.id}")

policy_results = with_isolated_policy_conversation(
  account: account,
  assistant: assistant,
  inbox: verification_inbox,
  message: 'Preciso de orientação sobre meu processo previdenciário.'
) do |isolated_conversation|
  policy = Captain::Conversation::ResponsePolicyService.new(
    conversation: isolated_conversation,
    assistant: assistant
  )
  {
    malformed_output: policy.apply('{"response":"."} 오류 correct format needed.'),
    accepts_documents: policy.apply('Recebi seu CNIS. Por seguranca, nao envie CPF e apague essa mensagem.'),
    suppresses_credentials: policy.apply('Sua senha do Meu INSS e exemplo123. Recebi a carta do beneficio.'),
    keeps_next_question: policy.apply(
      'Recebi seus documentos. Vou organizar o atendimento. Qual e a data da decisao?'
    )
  }
end

notice_policy_results = with_isolated_policy_conversation(
  account: account,
  assistant: assistant,
  inbox: verification_inbox,
  message: 'Quero saber se já posso me aposentar e como funciona a análise do meu caso.'
) do |isolated_conversation, initial_message_id|
  first_response = Captain::Conversation::ResponsePolicyService.new(
    conversation: isolated_conversation,
    assistant: assistant
  ).apply('Para começar, vou organizar as informações essenciais do seu caso.')
  insert_isolated_message!(
    conversation: isolated_conversation,
    id: initial_message_id + 1,
    type: 'outgoing',
    sender: assistant,
    content: first_response
  )
  insert_isolated_message!(
    conversation: isolated_conversation,
    id: initial_message_id + 2,
    type: 'incoming',
    sender: isolated_conversation.contact,
    content: 'Também tenho uma carta do INSS para incluir na análise.'
  )
  second_response = Captain::Conversation::ResponsePolicyService.new(
    conversation: isolated_conversation,
    assistant: assistant
  ).apply('Seguirei pelo histórico para concluir o atendimento inicial.')
  {
    first_response: first_response,
    second_response: second_response,
    marker_unchanged_before_delivery_job: isolated_conversation.captain_conversation_state.reload.analysis_notice_sent_at.blank?
  }
end
required_scenario_titles = [
  'Triagem previdenciária inicial',
  'Handoff de risco previdenciário'
]
required_scenarios = assistant.scenarios.enabled.where(title: required_scenario_titles)
normalized_scenario_instructions = required_scenarios.map { |scenario| normalized(scenario.instruction) }
initial_planning_response = Captain::Assistant::InitialMessageResponseService.new(
  message: 'Quero saber se já posso me aposentar e como funciona o planejamento previdenciário.',
  new_lead: true
).perform
existing_client_response = Captain::Assistant::InitialMessageResponseService.new(
  message: 'Quero saber se já posso me aposentar e como funciona o planejamento previdenciário.',
  new_lead: false
).perform
cnis_response = Captain::Assistant::InitialMessageResponseService.new(
  message: 'Preciso saber como conseguir o meu CNIS.',
  new_lead: false
).perform
other_lawyer_cnis_response = Captain::Assistant::InitialMessageResponseService.new(
  message: 'Uma advogada me pediu meu CNIS. Como consigo esse documento?',
  new_lead: false
).perform

profile_matches = assistant_scope.select do |candidate|
  candidate.config.to_h['profile_key'] == PROFILE_KEY ||
    candidate.name.in?([ASSISTANT_NAME, LEGACY_ASSISTANT_NAME])
end
normalized_cnis_response = normalized(cnis_response)
normalized_lawyer_response = normalized(other_lawyer_cnis_response)
profile_instructions = assistant.config['instructions'].to_s
normalized_profile_instructions = normalized(profile_instructions)
forbidden_cpf_request = /\b(?:envi\w*|inform\w*|pass\w*|fornec\w*|digit\w*)\b.{0,50}\bcpf\b/
configured_model = ENV['CAPTAIN_DRA_LETICIA_LLM_MODEL'].presence ||
                   ENV['CAPTAIN_DR_PAULA_LLM_MODEL'].presence ||
                   'anthropic/claude-sonnet-5'
configured_summarizer_model = ENV['CAPTAIN_DRA_LETICIA_SUMMARIZER_MODEL'].presence ||
                              ENV['CAPTAIN_DR_PAULA_SUMMARIZER_MODEL'].presence ||
                              'google/gemini-3.7-flash'

checks = {
  malformed_output: policy_results.fetch(:malformed_output) ==
                    Captain::Conversation::ResponsePolicyService::FALLBACK_RESPONSE,
  accepts_documents: !normalized(
    policy_results.fetch(:accepts_documents)
  ).match?(/nao envie|apag|exclu|canal inseguro/),
  suppresses_credentials: !normalized(
    policy_results.fetch(:suppresses_credentials)
  ).match?(/senha|exemplo123/),
  keeps_next_question: policy_results.fetch(:keeps_next_question).include?('Qual e a data da decisao?'),
  one_in_place_assistant: profile_matches.one? && profile_matches.first.id == assistant.id,
  migrated_name: assistant.name == ASSISTANT_NAME,
  legacy_assistant_absent: !assistant_scope.exists?(name: LEGACY_ASSISTANT_NAME),
  stable_profile_key: assistant.config['profile_key'] == PROFILE_KEY,
  feature_faq: ActiveModel::Type::Boolean.new.cast(assistant.config['feature_faq']),
  scoped_initial_responses: ActiveModel::Type::Boolean.new.cast(
    assistant.config['feature_previdenciario_initial_responses']
  ),
  scoped_data_collection_policy: ActiveModel::Type::Boolean.new.cast(
    assistant.config['feature_dra_paula_data_collection_policy']
  ),
  explicit_handoff_only: ActiveModel::Type::Boolean.new.cast(
    assistant.config['handoff_on_explicit_request_only']
  ),
  public_identity: assistant.config['public_identity'] == PUBLIC_IDENTITY,
  professional_identity: ActiveModel::Type::Boolean.new.cast(assistant.config['professional_identity']),
  welcome_identity: assistant.config['welcome_message'] == WELCOME_MESSAGE,
  no_captain_public_identity: normalized(assistant.config['public_identity']).exclude?('capitao'),
  not_impersonating_dra_paula: normalized_profile_instructions.include?('nunca se passe pela dra. paula'),
  reads_history_before_collecting: normalized_profile_instructions.include?('leia toda a conversa'),
  analyzes_attachments_and_ocr: (
    profile_instructions.include?('OCR') && normalized_profile_instructions.include?('quando houver anexo')
  ),
  single_faq_lookup_per_turn: (
    normalized_profile_instructions.include?('no maximo uma chamada faq_lookup por resposta ou turno') &&
      normalized_profile_instructions.include?('uma unica consulta curta e objetiva') &&
      normalized_profile_instructions.include?('nunca repita a busca no mesmo turno com sinonimos')
  ),
  document_mentions_are_not_receipts: normalized_profile_instructions.include?(
    'uma simples mencao a cnis'
  ),
  answers_direct_questions_first: normalized_profile_instructions.include?('responda primeiro'),
  cnis_explains_meu_inss: normalized_cnis_response.include?('meu inss') && normalized_cnis_response.include?('extrato de contribuicao'),
  cnis_never_requests_cpf: !normalized_cnis_response.match?(forbidden_cpf_request),
  lawyer_identifies_as_lawyer: normalized_lawyer_response.include?('tambem sou advogada') &&
                               normalized_lawyer_response.include?('posso resolver isso para voce'),
  lawyer_cnis_answers_question: normalized_lawyer_response.include?('meu inss') &&
                                normalized_lawyer_response.include?('extrato de contribuicao') &&
                                !normalized_lawyer_response.match?(forbidden_cpf_request),
  new_lead_notice_once: initial_planning_response.scan(NEW_LEAD_NOTICE).one?,
  response_policy_notice_exactly_once: [
    notice_policy_results.fetch(:first_response),
    notice_policy_results.fetch(:second_response)
  ].join(' ').scan(NEW_LEAD_NOTICE).one?,
  response_policy_read_only: notice_policy_results.fetch(:marker_unchanged_before_delivery_job),
  existing_client_without_notice: existing_client_response.exclude?(NEW_LEAD_NOTICE),
  concise_tokens: assistant.llm_config_with_defaults[:max_tokens] <= 700,
  captain_v2_enabled: account.feature_enabled?('captain_integration_v2'),
  openrouter_provider: assistant.llm_config_with_defaults[:provider] == 'openrouter',
  configured_model: assistant.llm_config_with_defaults[:main_model] == configured_model,
  configured_summarizer_model: assistant.llm_config_with_defaults[:summarizer_model] == configured_summarizer_model,
  namespaced_models: [
    assistant.llm_config_with_defaults[:main_model],
    assistant.llm_config_with_defaults[:summarizer_model]
  ].all? { |model| model.to_s.include?('/') },
  legacy_chat_disabled: assistant.config['force_legacy_chat'] == false,
  deterministic_triage_disabled: assistant.config['deterministic_triage'] == false,
  explains_initial_intent: normalized(initial_planning_response).match?(/regra (?:e )?mais vantajosa/) &&
                           initial_planning_response.include?('CNIS atualizado e sua idade'),
  contextual_fallback: assistant.config['fallback_message'] !=
                       'Recebi sua mensagem. Pode me contar em uma frase o que você precisa resolver?',
  no_temperature: assistant.send(:agent_temperature).nil?,
  explicit_inbox_linked: inbox_id.blank? || linked_inbox_ids.include?(inbox_id),
  all_relevant_inboxes_preserved: expected_inbox_ids.all? do |expected_id|
    relevant_captain_inboxes[expected_id]&.captain_assistant_id == assistant.id
  end,
  managed_inboxes_preserved: managed_inbox_ids.all? { |managed_id| linked_inbox_ids.include?(managed_id) },
  campaign_inboxes_preserved: campaign_inbox_ids.all? { |campaign_id| linked_inbox_ids.include?(campaign_id) },
  all_linked_inboxes_request_driven: linked_captain_inboxes.all? do |link|
    link.handoff_strategy == 'human_request'
  end,
  all_linked_inboxes_operational: linked_captain_inboxes.all? do |link|
    link.enabled? && link.auto_reply_enabled? && link.ai_mode == 'auto'
  end,
  rag_documents: assistant.documents.available.where(
    external_link: [
      'internal://dr-paula-matos/planejamento-previdenciario',
      'internal://dr-paula-matos/faq',
      'internal://dr-paula-matos/fontes-inss'
    ]
  ).count == 3,
  required_scenarios: required_scenarios.count == required_scenario_titles.length,
  faq_tool_bound: required_scenarios.all? do |scenario|
    scenario.tools.to_a.include?('faq_lookup')
  end,
  scenario_single_faq_lookup_per_turn: normalized_scenario_instructions.all? do |instruction|
    instruction.include?('no maximo uma chamada') &&
      instruction.include?('uma unica consulta objetiva') &&
      instruction.include?('nunca repita a busca com sinonimos')
  end
}

checks.each { |name, passed| assert_check!(passed, name) }

sanitizer = Captain::Assistant::AgentRunnerService.new(
  assistant: assistant,
  conversation: nil
)
sanitized = sanitizer.send(
  :redact_credential_assignments,
  'CPF 123.456.789-00, senha do Meu INSS e exemplo.123, token: 654 321.'
)
assert_check!(sanitized.include?('123.456.789-00'), 'CPF must remain available for case intake')
assert_check!(!sanitized.match?(/exemplo|654|321/), 'credentials must not reach the provider')

# rubocop:disable Rails/Output -- this rails runner script returns a machine-readable verification result
puts({
  ok: true,
  assistant_id: assistant.id,
  assistant_name: assistant.name,
  profile_key: assistant.config['profile_key'],
  inbox_ids: linked_inbox_ids,
  inboxes: linked_captain_inboxes.sort_by(&:inbox_id).map do |link|
    {
      id: link.inbox_id,
      name: link.inbox.name,
      enabled: link.enabled,
      auto_reply_enabled: link.auto_reply_enabled,
      ai_mode: link.ai_mode,
      handoff_strategy: link.handoff_strategy
    }
  end,
  managed_inbox_ids: managed_inbox_ids,
  campaign_inbox_ids: campaign_inbox_ids,
  model: assistant.llm_config_with_defaults[:main_model],
  checks: checks
}.to_json)
# rubocop:enable Rails/Output
