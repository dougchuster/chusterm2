require 'rails_helper'

RSpec.describe Captain::Conversation::ResponseBuilderJob, type: :job do
  let(:account) { create(:account, custom_attributes: { plan_name: 'startups' }) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:captain_inbox_association) { create(:captain_inbox, captain_assistant: assistant, inbox: inbox) }

  describe '#perform' do
    let(:conversation) { create(:conversation, inbox: inbox, account: account, status: :pending) }
    let(:mock_llm_chat_service) { instance_double(Captain::Llm::AssistantChatService) }
    let(:mock_agent_runner_service) { instance_double(Captain::Assistant::AgentRunnerService) }

    before do
      create(:message, conversation: conversation, content: 'Hello', message_type: :incoming)

      allow(inbox).to receive(:captain_active?).and_return(true)
      allow(account).to receive(:feature_enabled?).and_return(false)
      allow(account).to receive(:feature_enabled?).with('captain_integration_v2').and_return(false)
      allow(Captain::Llm::AssistantChatService).to receive(:new).and_return(mock_llm_chat_service)
      allow(mock_llm_chat_service).to receive(:generate_response).and_return({ 'response' => 'Hey, welcome to Captain Specs' })
      allow(Captain::Assistant::AgentRunnerService).to receive(:new).and_return(mock_agent_runner_service)
      allow(mock_agent_runner_service).to receive(:generate_response).and_return({ 'response' => 'Hey, welcome to Captain V2' })
    end

    context 'when captain_v2 is disabled' do
      before do
        allow(account).to receive(:feature_enabled?).and_return(false)
        allow(account).to receive(:feature_enabled?).with('captain_integration_v2').and_return(false)
      end

      it 'uses Captain::Llm::AssistantChatService' do
        expect(Captain::Llm::AssistantChatService).to receive(:new).with(assistant: assistant, conversation: conversation)
        expect(Captain::Assistant::AgentRunnerService).not_to receive(:new)

        described_class.perform_now(conversation, assistant)
        expect(conversation.messages.last.content).to eq('Hey, welcome to Captain Specs')
      end

      it 'generates and processes response' do
        described_class.perform_now(conversation, assistant)
        expect(conversation.messages.count).to eq(2)
        expect(conversation.messages.outgoing.count).to eq(1)
        expect(conversation.messages.last.content).to eq('Hey, welcome to Captain Specs')
      end

      it 'sanitizes banned Dra Juliana phrasing before sending' do
        conversation.contact.update!(name: 'Savia')
        allow(mock_llm_chat_service).to receive(:generate_response).and_return(
          {
            'response' => 'Poxa, Sávia, é um absurdo você passar por isso. Se puder, envie o contrato. Sávia, me diga quando aconteceu.'
          }
        )

        described_class.perform_now(conversation, assistant)

        content = conversation.messages.outgoing.last.content
        expect(content).not_to match(/poxa|absurdo|se puder/i)
        expect(content.scan(/S[áa]via/i).size).to eq(1)
      end

      it 'does not ask for Meu INSS simulation as an analysis parameter' do
        allow(mock_llm_chat_service).to receive(:generate_response).and_return(
          {
            'response' => 'Para adiantar, envie CNIS atualizado, simulação do Meu INSS, CTPS e comprovantes.'
          }
        )

        described_class.perform_now(conversation, assistant)

        content = conversation.messages.outgoing.last.content
        expect(content).not_to match(/simulação do Meu INSS/i)
        expect(content).to include('CNIS atualizado')
        expect(content).to include('CTPS')
      end

      it 'applies the response policy once to the complete answer before segmenting and flags scheduled parts' do
        raw_response = 'Primeira parte insegura.\n\nSegunda parte que pediria CPF.'
        sanitized_response = 'Primeira parte segura.\n\nSegunda parte segura.'
        policy = instance_double(Captain::Conversation::ResponsePolicyService)
        segmenter = instance_double(
          Captain::Conversation::MessageSegmenterService,
          perform: ['Primeira parte segura.', 'Segunda parte segura.']
        )
        configured_job = instance_double(ActiveJob::ConfiguredJob)

        allow(mock_llm_chat_service).to receive(:generate_response).and_return({ 'response' => raw_response })
        allow(Captain::Conversation::ResponsePolicyService).to receive(:new)
          .with(conversation: conversation, assistant: assistant)
          .and_return(policy)
        expect(policy).to receive(:apply).once.with(raw_response).and_return(sanitized_response)
        expect(Captain::Conversation::MessageSegmenterService).to receive(:new)
          .with(text: sanitized_response)
          .and_return(segmenter)
        expect(Captain::Conversation::ResponsePartJob).to receive(:set)
          .with(wait: described_class::RESPONSE_PART_DELAY_SECONDS)
          .and_return(configured_job)
        expect(configured_job).to receive(:perform_later).with(
          conversation,
          assistant,
          'Segunda parte segura.',
          nil,
          policy_applied: true,
          origin_incoming_id: conversation.messages.incoming.maximum(:id)
        )

        described_class.perform_now(conversation, assistant)

        expect(conversation.messages.outgoing.last.content).to eq('Primeira parte segura.')
      end

      it 'moves the lead review notice into the first delivered part before marking it as sent' do
        notice = Captain::Conversation::ResponsePolicyService::NEW_LEAD_REVIEW_NOTICE
        sanitized_response =
          'Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos. ' \
          "#{notice} Qual é a data da decisão?"
        policy = instance_double(Captain::Conversation::ResponsePolicyService, apply: sanitized_response)
        segmenter = instance_double(
          Captain::Conversation::MessageSegmenterService,
          perform: [
            'Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos.',
            notice,
            'Qual é a data da decisão?'
          ]
        )
        configured_job = instance_double(ActiveJob::ConfiguredJob, perform_later: true)

        allow(Captain::Conversation::ResponsePolicyService).to receive(:new).and_return(policy)
        allow(Captain::Conversation::MessageSegmenterService).to receive(:new).and_return(segmenter)
        allow(Captain::Conversation::ResponsePartJob).to receive(:set).and_return(configured_job)

        described_class.perform_now(conversation, assistant)

        first_message = conversation.messages.outgoing.where(sender: assistant).last
        expect(first_message.content).to include('Sou a Dra. Letícia')
        expect(first_message.content).to include(notice)
        expect(conversation.reload.captain_conversation_state.analysis_notice_sent_at).to be_present
      end

      it 'increments usage response' do
        described_class.perform_now(conversation, assistant)
        account.reload
        expect(account.usage_limits[:captain][:responses][:consumed]).to eq(1)
      end

      it 'does not send a response when the conversation is no longer pending' do
        conversation.open!

        expect(mock_llm_chat_service).not_to receive(:generate_response)
        expect do
          described_class.perform_now(conversation, assistant)
        end.not_to(change { conversation.messages.outgoing.count })
      end

      it 'does not send a queued response after Captain auto reply is disabled on the inbox' do
        allow(inbox).to receive(:captain_active?).and_return(false)

        expect(mock_llm_chat_service).not_to receive(:generate_response)
        expect do
          described_class.perform_now(conversation, assistant)
        end.not_to(change { conversation.messages.outgoing.count })
      end

      it 'does not send a queued response after a human has replied to the latest incoming message' do
        agent = create(:user, account: account, role: :agent)
        create(:message, conversation: conversation, content: 'Vou assumir por aqui.', message_type: :outgoing,
                         sender: agent, account: account, inbox: inbox)

        expect(mock_llm_chat_service).not_to receive(:generate_response)
        expect do
          described_class.perform_now(conversation, assistant)
        end.not_to(change { conversation.messages.outgoing.where(sender_type: 'Captain::Assistant').count })

        state = conversation.reload.captain_conversation_state
        expect(conversation.status).to eq('open')
        expect(state.ai_mode).to eq('human_only')
        expect(state.handoff_reason).to eq('Atendimento humano detectado; IA pausada automaticamente.')
      end

      it 'does not send a queued response after a human attended before the latest incoming message' do
        agent = create(:user, account: account, role: :agent)
        create(:message, conversation: conversation, content: 'Resposta anterior da IA.', message_type: :outgoing,
                         sender: assistant, account: account, inbox: inbox)
        create(:message, conversation: conversation, content: 'Vou assumir por aqui.', message_type: :outgoing,
                         sender: agent, account: account, inbox: inbox)
        create(:message, conversation: conversation, content: 'Me encaminha o que ele ja passou', message_type: :incoming,
                         account: account, inbox: inbox)

        expect(mock_llm_chat_service).not_to receive(:generate_response)
        expect do
          described_class.perform_now(conversation, assistant)
        end.not_to(change { conversation.messages.outgoing.where(sender_type: 'Captain::Assistant').count })

        state = conversation.reload.captain_conversation_state
        expect(conversation.status).to eq('open')
        expect(state.ai_mode).to eq('human_only')
        expect(state.handoff_reason).to eq('Atendimento humano detectado; IA pausada automaticamente.')
      end

      it 'does not send a queued response after a WhatsApp native app echo' do
        create(:message, conversation: conversation, content: 'Resposta anterior da IA.', message_type: :outgoing,
                         sender: assistant, account: account, inbox: inbox)

        conversation.messages.create!(
          message_type: :outgoing,
          account: account,
          inbox: inbox,
          sender: nil,
          content: 'Estou atendendo pelo celular.',
          content_attributes: { 'external_echo' => true }
        )

        create(:message, conversation: conversation, content: 'Tá bom', message_type: :incoming,
                         account: account, inbox: inbox)
        CaptainConversationState.where(conversation: conversation).delete_all
        conversation.pending!
        conversation.association(:captain_conversation_state).reset

        expect(mock_llm_chat_service).not_to receive(:generate_response)
        expect do
          described_class.perform_now(conversation, assistant)
        end.not_to(change { conversation.messages.outgoing.where(sender_type: 'Captain::Assistant').count })

        state = conversation.reload.captain_conversation_state
        expect(conversation.status).to eq('open')
        expect(state.ai_mode).to eq('human_only')
        expect(state.handoff_reason).to eq('Atendimento humano detectado; IA pausada automaticamente.')
      end

      it 'allows a response after a human manually resumes AI' do
        agent = create(:user, account: account, role: :agent)
        create(:message, conversation: conversation, content: 'Resposta anterior da IA.', message_type: :outgoing,
                         sender: assistant, account: account, inbox: inbox)
        create(:message, conversation: conversation, content: 'Vou assumir por aqui.', message_type: :outgoing,
                         sender: agent, account: account, inbox: inbox)

        state = CaptainConversationState.for_conversation!(conversation)
        state.update!(ai_mode: 'auto', handoff_reason: 'IA retomada manualmente', handoff_at: nil, handoff_by: nil)
        conversation.pending!
        create(:message, conversation: conversation, content: 'Pode seguir', message_type: :incoming,
                         account: account, inbox: inbox)

        expect do
          described_class.perform_now(conversation, assistant)
        end.to change { conversation.messages.outgoing.where(sender_type: 'Captain::Assistant').count }.by(1)
      end

      it 'continues supporting customer contacts instead of globally disabling AI' do
        conversation.contact.update!(contact_type: :customer)

        expect do
          described_class.perform_now(conversation, assistant)
        end.to change { conversation.messages.outgoing.where(sender_type: 'Captain::Assistant').count }.by(1)

        state = conversation.reload.captain_conversation_state
        expect(conversation.status).to eq('pending')
        expect(state.ai_mode).to eq('auto')
      end

      it 'does not send another response when the latest public message is already from the assistant' do
        create(:message, conversation: conversation, content: 'Already answered', message_type: :outgoing, sender: assistant)

        expect(mock_llm_chat_service).not_to receive(:generate_response)
        expect do
          described_class.perform_now(conversation, assistant)
        end.not_to(change { conversation.messages.outgoing.count })
      end

      it 'waits for the configured quiet window before generating a response' do
        captain_inbox_association.update!(routing_config: { 'response_delay_seconds' => 15, 'response_max_wait_seconds' => 45 })
        latest_incoming = create(:message, conversation: conversation, content: 'Quais documentos?', message_type: :incoming)
        scheduled_job = instance_double(ActiveJob::ConfiguredJob)

        expect(Captain::Conversation::ResponseBuilderJob).to receive(:set).with(wait: kind_of(ActiveSupport::Duration)).and_return(scheduled_job)
        expect(scheduled_job).to receive(:perform_later).with(
          conversation,
          assistant,
          0,
          latest_incoming.id,
          kind_of(ActiveSupport::TimeWithZone)
        )
        expect(mock_llm_chat_service).not_to receive(:generate_response)

        described_class.perform_now(conversation, assistant, 0, latest_incoming.id, Time.current)
      end

      it 'waits for audio transcription when the account uses the default enabled setting' do
        latest_incoming = create(:message, conversation: conversation, content: '', message_type: :incoming)
        latest_incoming.attachments.create!(
          account: account,
          file_type: :audio,
          meta: { 'media_understanding_status' => 'processing' }
        )
        account.update!(audio_transcriptions: nil)
        allow(Llm::MediaConfig).to receive(:transcription_configured?).and_return(true)
        scheduled_job = instance_double(ActiveJob::ConfiguredJob)

        expect(Captain::Conversation::ResponseBuilderJob).to receive(:set)
          .with(wait: kind_of(ActiveSupport::Duration))
          .and_return(scheduled_job)
        expect(scheduled_job).to receive(:perform_later).with(
          conversation,
          assistant,
          1,
          nil,
          nil
        )
        expect(mock_llm_chat_service).not_to receive(:generate_response)

        described_class.perform_now(conversation, assistant)
      end

      it 'publishes a readable recovery message, adds a private note and hands off when audio transcription failed' do
        latest_incoming = create(:message, conversation: conversation, content: '', message_type: :incoming)
        latest_incoming.attachments.create!(
          account: account,
          file_type: :audio,
          meta: {
            'media_understanding_status' => 'failed',
            'media_understanding_error' => 'transient_provider_exhausted: Gemini temporary API error 503'
          }
        )
        account.update!(audio_transcriptions: nil)
        allow(Llm::MediaConfig).to receive(:transcription_configured?).and_return(true)

        expect(mock_llm_chat_service).not_to receive(:generate_response)
        expect do
          described_class.perform_now(conversation, assistant)
        end.to change { conversation.messages.outgoing.where(private: false, sender_type: 'Captain::Assistant').count }.by(1)

        state = conversation.reload.captain_conversation_state
        expect(conversation.status).to eq('open')
        expect(state.ai_mode).to eq('human_only')
        expect(state.handoff_reason).to include('Mídia sem contexto seguro para IA')
        expect(conversation.messages.outgoing.where(private: false, sender: assistant).last.content).to include(
          'Recebi o arquivo, mas não consegui ler o conteúdo'
        )
        expect(conversation.messages.outgoing.where(private: true, sender: assistant).last.content).to include('IA pausada')
      end

      it 'publishes the recovery message and hands off when document analysis was skipped' do
        latest_incoming = create(:message, conversation: conversation, content: '', message_type: :incoming)
        latest_incoming.attachments.create!(
          account: account,
          file_type: :file,
          meta: { 'media_understanding_status' => 'skipped' }
        )

        expect(mock_llm_chat_service).not_to receive(:generate_response)

        described_class.perform_now(conversation, assistant)

        public_message = conversation.messages.outgoing.where(private: false, sender: assistant).last
        private_note = conversation.messages.outgoing.where(private: true, sender: assistant).last
        state = conversation.reload.captain_conversation_state
        expect(public_message.content).to include('não consegui ler o conteúdo')
        expect(public_message.content).to include('Reenvie em PDF ou em fotos nítidas')
        expect(private_note.content).to include('Atendimento humano necessário')
        expect(state.ai_mode).to eq('human_only')
      end

      %w[processed completed].each do |finished_status|
        it "treats #{finished_status} document understanding without usable fields as unreadable" do
          latest_incoming = create(:message, conversation: conversation, content: '', message_type: :incoming)
          latest_incoming.attachments.create!(
            account: account,
            file_type: :file,
            meta: {
              'media_understanding_status' => finished_status,
              'ocr_text' => '',
              'image_description' => '',
              'document_guess' => '',
              'media_understanding' => { 'ocr_text' => '', 'description' => '' }
            }
          )

          expect(mock_llm_chat_service).not_to receive(:generate_response)

          described_class.perform_now(conversation, assistant)

          expect(conversation.messages.outgoing.where(private: false, sender: assistant).last.content).to include(
            'não consegui ler o conteúdo'
          )
          expect(conversation.messages.outgoing.where(private: true, sender: assistant).last.content).to include('IA pausada')
          expect(conversation.reload.captain_conversation_state.ai_mode).to eq('human_only')
        end
      end

      it 'does not treat a document type guess without extracted content as readable' do
        latest_incoming = create(:message, conversation: conversation, content: '', message_type: :incoming)
        latest_incoming.attachments.create!(
          account: account,
          file_type: :file,
          meta: {
            'media_understanding_status' => 'processed',
            'document_guess' => 'CNIS'
          }
        )

        expect(mock_llm_chat_service).not_to receive(:generate_response)

        described_class.perform_now(conversation, assistant)

        expect(conversation.messages.outgoing.where(private: false, sender: assistant).last.content).to include(
          'não consegui ler o conteúdo'
        )
        expect(conversation.reload.captain_conversation_state.ai_mode).to eq('human_only')
      end

      it 'propagates a processed file description to the model instead of treating hidden metadata as sufficient' do
        conversation.contact.update!(contact_type: :customer)
        latest_incoming = create(:message, conversation: conversation, content: '', message_type: :incoming)
        latest_incoming.attachments.create!(
          account: account,
          file_type: :file,
          meta: {
            'media_understanding_status' => 'processed',
            'image_description' => 'Página de um extrato previdenciário com vínculos e remunerações.'
          }
        )

        expect(mock_llm_chat_service).to receive(:generate_response) do |message_history:|
          expect(message_history.last[:content]).to include('Contexto analisado do arquivo')
          expect(message_history.last[:content]).to include('extrato previdenciário')
          { 'response' => 'Vou considerar o conteúdo identificado no documento.' }
        end

        described_class.perform_now(conversation, assistant)

        expect(conversation.messages.outgoing.where(private: false, sender: assistant).last.content).to eq(
          'Vou considerar o conteúdo identificado no documento.'
        )
        expect(conversation.reload.captain_conversation_state.ai_mode).to eq('auto')
      end

      it 'publishes the recovery message and hands off when media remains processing after the timeout' do
        latest_incoming = create(:message, conversation: conversation, content: '', message_type: :incoming)
        latest_incoming.attachments.create!(
          account: account,
          file_type: :file,
          meta: { 'media_understanding_status' => 'processing' }
        )
        allow(Llm::OpenRouterMultimodalService).to receive(:active?).with(purpose: :media).and_return(true)

        expect(mock_llm_chat_service).not_to receive(:generate_response)

        described_class.perform_now(
          conversation,
          assistant,
          described_class::MAX_MEDIA_UNDERSTANDING_WAIT_ATTEMPTS
        )

        expect(conversation.messages.outgoing.where(private: false, sender: assistant).last.content).to include(
          'não consegui ler o conteúdo'
        )
        expect(conversation.messages.outgoing.where(private: true, sender: assistant).last.content).to include('IA pausada')
        expect(conversation.reload.captain_conversation_state.ai_mode).to eq('human_only')
      end

      it 'continues to the model when OCR text is available for the attachment' do
        latest_incoming = create(:message, conversation: conversation, content: '', message_type: :incoming)
        latest_incoming.attachments.create!(
          account: account,
          file_type: :file,
          meta: {
            'media_understanding_status' => 'completed',
            'ocr_text' => 'Extrato CNIS com vínculo empregatício de 2010 a 2020.'
          }
        )
        message_builder = instance_double(Captain::OpenAiMessageBuilderService, generate_content: 'Documento com OCR')
        allow(Captain::OpenAiMessageBuilderService).to receive(:new).and_return(message_builder)

        expect(mock_llm_chat_service).to receive(:generate_response).and_return({ 'response' => 'Analisei o texto do documento.' })

        described_class.perform_now(conversation, assistant)

        expect(conversation.messages.outgoing.where(private: false, sender: assistant).last.content).to eq(
          'Analisei o texto do documento.'
        )
        expect(conversation.reload.captain_conversation_state.ai_mode).to eq('auto')
      end

      it 'discards a stale completion and schedules one response for messages received during generation' do
        captain_inbox_association.update!(
          routing_config: { 'response_delay_seconds' => 4, 'response_max_wait_seconds' => 20 }
        )
        scheduled_job = instance_double(ActiveJob::ConfiguredJob)
        allow(mock_llm_chat_service).to receive(:generate_response) do
          create(
            :message,
            conversation: conversation,
            content: 'Também sou CLT e já tenho o CNIS.',
            message_type: :incoming
          )
          { 'response' => 'Resposta baseada apenas na mensagem anterior.' }
        end

        expect(Captain::Conversation::ResponseBuilderJob).to receive(:set)
          .with(wait: kind_of(ActiveSupport::Duration))
          .and_return(scheduled_job)
        expect(scheduled_job).to receive(:perform_later).with(
          conversation,
          assistant,
          0,
          kind_of(Integer),
          kind_of(ActiveSupport::TimeWithZone)
        )

        expect do
          described_class.perform_now(conversation, assistant)
        end.not_to(change { conversation.messages.outgoing.count })
      end
    end

    context 'when captain_v2 is enabled' do
      before do
        allow(account).to receive(:feature_enabled?).and_return(false)
        allow(account).to receive(:feature_enabled?).with('captain_integration_v2').and_return(true)
      end

      it 'uses Captain::Assistant::AgentRunnerService' do
        expect(Captain::Assistant::AgentRunnerService).to receive(:new).with(
          assistant: assistant,
          conversation: conversation
        )
        expect(Captain::Llm::AssistantChatService).not_to receive(:new)

        described_class.perform_now(conversation, assistant)
        expect(conversation.messages.last.content).to eq('Hey, welcome to Captain V2')
      end

      it 'passes message history to agent runner service' do
        expected_messages = [
          { content: 'Hello', role: 'user' }
        ]

        expect(mock_agent_runner_service).to receive(:generate_response).with(
          message_history: expected_messages
        )

        described_class.perform_now(conversation, assistant)
      end

      it 'generates and processes response' do
        described_class.perform_now(conversation, assistant)
        expect(conversation.messages.count).to eq(2)
        expect(conversation.messages.outgoing.count).to eq(1)
        expect(conversation.messages.last.content).to eq('Hey, welcome to Captain V2')
      end

      it 'stores the response origin and safe provider error category for auditing' do
        allow(mock_agent_runner_service).to receive(:generate_response).and_return(
          {
            'response' => 'Recebi sua mensagem. Vou orientar o próximo passo.',
            'response_origin' => 'provider_fallback',
            'ai_error_category' => 'insufficient_credit'
          }
        )

        described_class.perform_now(conversation, assistant)

        attributes = conversation.messages.outgoing.last.additional_attributes
        expect(attributes).to include(
          'ai_response_origin' => 'provider_fallback',
          'ai_error_category' => 'insufficient_credit'
        )
      end

      it 'increments usage response' do
        described_class.perform_now(conversation, assistant)
        account.reload
        expect(account.usage_limits[:captain][:responses][:consumed]).to eq(1)
      end

      it 'hands off an explicit request for Dra. Paula before calling the model' do
        captain_inbox_association.update!(handoff_strategy: 'human_request')
        conversation.messages.incoming.last.update!(
          content: 'Oi, gostaria de falar com a Dra. Paula.'
        )

        expect(Captain::Assistant::AgentRunnerService).not_to receive(:new)

        described_class.perform_now(conversation, assistant)

        state = conversation.reload.captain_conversation_state
        expect(conversation.status).to eq('open')
        expect(state.ai_mode).to eq('human_only')
        expect(state.handoff_reason_code).to eq('customer_request')
      end

      it 'does not hand off a question about Dra. Paula services' do
        captain_inbox_association.update!(handoff_strategy: 'human_request')
        conversation.messages.incoming.last.update!(
          content: 'A Dra. Paula atende casos de aposentadoria?'
        )

        expect(Captain::Assistant::AgentRunnerService).to receive(:new).and_return(mock_agent_runner_service)

        described_class.perform_now(conversation, assistant)

        expect(conversation.reload.status).to eq('pending')
        expect(conversation.messages.outgoing.last.content).to eq('Hey, welcome to Captain V2')
      end

      it 'lets Dra. Letícia answer a generic request for a lawyer instead of handing off' do
        captain_inbox_association.update!(handoff_strategy: 'human_request')
        conversation.messages.incoming.last.update!(
          content: 'Quero falar com uma advogada sobre minha aposentadoria.'
        )

        expect(Captain::Assistant::AgentRunnerService).to receive(:new).and_return(mock_agent_runner_service)

        described_class.perform_now(conversation, assistant)

        state = conversation.reload.captain_conversation_state
        expect(conversation.status).to eq('pending')
        expect(state.ai_mode).to eq('auto')
        expect(conversation.messages.outgoing.last.content).to eq('Hey, welcome to Captain V2')
      end
    end

    # Regression (PR #13417): wrapping create_handoff_message and bot_handoff! in the
    # same transaction defers the message's after_create_commit until commit, at which
    # point it clears waiting_since (bot_response). The handoff path must stay outside
    # the transaction so the callback fires before bot_handoff! sets waiting_since.
    context 'when handoff is requested' do
      let(:conversation) { create(:conversation, inbox: inbox, account: account, status: :pending) }
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        allow(account).to receive(:feature_enabled?).and_return(false)
        allow(account).to receive(:feature_enabled?).with('captain_integration_v2').and_return(false)
        conversation.messages.incoming.last.update!(
          content: 'Quero falar com um atendente humano.'
        )
        allow(mock_llm_chat_service).to receive(:generate_response).and_return({ 'response' => 'conversation_handoff' })
      end

      it 'sets waiting_since to approximately the handoff time' do
        freeze_time do
          described_class.perform_now(conversation, assistant)

          conversation.reload
          expect(conversation.status).to eq('open')
          expect(conversation.waiting_since).to be_within(1.second).of(Time.current)
        end
      end

      it 'preserves waiting_since so a human reply consumes it for reply_time tracking' do
        described_class.perform_now(conversation, assistant)

        conversation.reload
        expect(conversation.waiting_since).to be_present

        # A human reply clears waiting_since (consumed by dispatch_create_events
        # to emit FIRST_REPLY_CREATED or REPLY_CREATED for reply_time tracking).
        create(:message, conversation: conversation, message_type: :outgoing,
                         sender: agent, account: account, inbox: inbox)
        expect(conversation.reload.waiting_since).to be_nil
      end
    end

    context 'when message contains an image' do
      let(:message_with_image) { create(:message, conversation: conversation, message_type: :incoming, content: 'Can you help with this error?') }
      let(:image_attachment) { message_with_image.attachments.create!(account: account, file_type: :image, external_url: 'https://example.com/error.jpg') }

      before do
        image_attachment
      end

      it 'includes image URL directly in the message content for OpenAI vision analysis' do
        # Expect the generate_response to receive multimodal content with image URL
        expect(mock_llm_chat_service).to receive(:generate_response) do |**kwargs|
          history = kwargs[:message_history]
          last_entry = history.last
          expect(last_entry[:content]).to be_an(Array)
          expect(last_entry[:content].any? { |part| part[:type] == 'text' && part[:text] == 'Can you help with this error?' }).to be true
          expect(last_entry[:content].any? do |part|
            part[:type] == 'image_url' && part[:image_url][:url] == 'https://example.com/error.jpg'
          end).to be true
          { 'response' => 'I can see the error in your image. It appears to be a database connection issue.' }
        end

        described_class.perform_now(conversation, assistant)
      end
    end

    context 'when the model requests an unrequested handoff' do
      before do
        allow(account).to receive(:feature_enabled?).and_return(false)
        allow(account).to receive(:feature_enabled?).with('captain_integration_v2').and_return(false)
        allow(mock_llm_chat_service).to receive(:generate_response)
          .and_return({ 'response' => 'conversation_handoff' })
      end

      it 'keeps the conversation with the AI and asks one concise question' do
        described_class.perform_now(conversation, assistant)

        expect(conversation.reload.status).to eq('pending')
        expect(conversation.messages.outgoing.last.content).to eq(
          described_class::UNREQUESTED_HANDOFF_FALLBACK
        )
      end
    end

    context 'when another public reply is created during generation' do
      let(:human_agent) { create(:user, account: account, role: :agent) }

      before do
        allow(mock_llm_chat_service).to receive(:generate_response) do
          create(
            :message,
            conversation: conversation,
            account: account,
            inbox: inbox,
            sender: human_agent,
            message_type: :outgoing,
            content: 'Já estou atendendo este caso.'
          )
          { 'response' => 'Resposta antiga da IA.' }
        end
      end

      it 'discards the generated AI response' do
        expect do
          described_class.perform_now(conversation, assistant)
        end.to change { conversation.messages.outgoing.count }.by(1)

        expect(conversation.messages.outgoing.last.content).to eq(
          'Já estou atendendo este caso.'
        )
      end
    end
  end

  describe 'retry mechanisms for image processing' do
    let(:conversation) { create(:conversation, inbox: inbox, account: account, status: :pending) }
    let(:mock_llm_chat_service) { instance_double(Captain::Llm::AssistantChatService) }
    let(:mock_message_builder) { instance_double(Captain::OpenAiMessageBuilderService) }

    before do
      captain_inbox_association
      create(:message, conversation: conversation, content: 'Hello with image', message_type: :incoming)
      allow(account).to receive(:feature_enabled?).and_return(false)
      allow(account).to receive(:feature_enabled?).with('captain_integration_v2').and_return(false)
      allow(Captain::Llm::AssistantChatService).to receive(:new).and_return(mock_llm_chat_service)
      allow(Captain::OpenAiMessageBuilderService).to receive(:new).with(message: anything).and_return(mock_message_builder)
      allow(mock_message_builder).to receive(:generate_content).and_return('Hello with image')
      allow(mock_llm_chat_service).to receive(:generate_response).and_return({ 'response' => 'Test response' })
    end

    context 'when ActiveStorage::FileNotFoundError occurs' do
      it 'handles file errors and triggers handoff' do
        allow(mock_message_builder).to receive(:generate_content)
          .and_raise(ActiveStorage::FileNotFoundError, 'Image file not found')

        # For retryable errors, the job should handle them and proceed with handoff
        described_class.perform_now(conversation, assistant)

        # Verify handoff occurred due to repeated failures
        expect(conversation.reload.status).to eq('open')
      end

      it 'succeeds when no error occurs' do
        # Don't raise any error, should succeed normally
        allow(mock_message_builder).to receive(:generate_content)
          .and_return('Image content processed successfully')

        described_class.perform_now(conversation, assistant)

        expect(conversation.messages.outgoing.count).to eq(1)
        expect(conversation.messages.outgoing.last.content).to eq('Test response')
      end
    end

    context 'when Faraday::BadRequestError occurs' do
      it 'handles API errors and triggers handoff' do
        allow(mock_llm_chat_service).to receive(:generate_response)
          .and_raise(Faraday::BadRequestError, 'Bad request to image service')

        described_class.perform_now(conversation, assistant)
        expect(conversation.reload.status).to eq('open')
      end

      it 'succeeds when no error occurs' do
        # Don't raise any error, should succeed normally
        allow(mock_llm_chat_service).to receive(:generate_response)
          .and_return({ 'response' => 'Response after retry' })

        described_class.perform_now(conversation, assistant)

        expect(conversation.messages.outgoing.last.content).to eq('Response after retry')
      end
    end

    context 'when image processing fails permanently' do
      before do
        allow(mock_message_builder).to receive(:generate_content)
          .and_raise(ActiveStorage::FileNotFoundError, 'Image permanently unavailable')
      end

      it 'triggers handoff after max retries' do
        # Since perform_now re-raises retryable errors, simulate the final failure after retries
        allow(mock_message_builder).to receive(:generate_content)
          .and_raise(StandardError, 'Max retries exceeded')

        expect(ChusteRMExceptionTracker).to receive(:new).and_call_original

        described_class.perform_now(conversation, assistant)

        expect(conversation.reload.status).to eq('open')
      end
    end

    context 'when non-retryable error occurs' do
      let(:standard_error) { StandardError.new('Generic error') }

      before do
        allow(mock_llm_chat_service).to receive(:generate_response).and_raise(standard_error)
      end

      it 'handles error and triggers handoff' do
        expect(ChusteRMExceptionTracker).to receive(:new)
          .with(standard_error, account: account)
          .and_call_original

        described_class.perform_now(conversation, assistant)

        expect(conversation.reload.status).to eq('open')
      end

      it 'ensures Current.executed_by is reset' do
        expect(Current).to receive(:executed_by=).with(assistant)
        expect(Current).to receive(:executed_by=).with(nil)

        described_class.perform_now(conversation, assistant)
      end
    end
  end

  describe 'job configuration' do
    it 'has retry_on configuration for retryable errors' do
      expect(described_class).to respond_to(:retry_on)
    end

    it 'defines MAX_MESSAGE_LENGTH constant' do
      expect(described_class::MAX_MESSAGE_LENGTH).to eq(10_000)
    end
  end

  describe 'out of office message after handoff' do
    let(:conversation) { create(:conversation, inbox: inbox, account: account, status: :pending) }
    let(:mock_llm_chat_service) { instance_double(Captain::Llm::AssistantChatService) }

    before do
      captain_inbox_association
      create(
        :message,
        conversation: conversation,
        content: 'Quero falar com um atendente humano.',
        message_type: :incoming
      )
      allow(Captain::Llm::AssistantChatService).to receive(:new).and_return(mock_llm_chat_service)
      allow(account).to receive(:feature_enabled?).and_return(false)
      allow(account).to receive(:feature_enabled?).with('captain_integration_v2').and_return(false)
    end

    context 'when handoff occurs outside business hours' do
      before do
        inbox.update!(
          working_hours_enabled: true,
          out_of_office_message: 'We are currently closed. Please leave your email.'
        )
        inbox.working_hours.find_by(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
          closed_all_day: true,
          open_all_day: false
        )
        allow(mock_llm_chat_service).to receive(:generate_response).and_return({ 'response' => 'conversation_handoff' })
      end

      it 'sends out of office message after handoff' do
        expect do
          described_class.perform_now(conversation, assistant)
        end.to change { conversation.messages.template.count }.by(1)

        expect(conversation.reload.status).to eq('open')
        ooo_message = conversation.messages.template.last
        expect(ooo_message.content).to eq('We are currently closed. Please leave your email.')
      end
    end

    context 'when handoff occurs within business hours' do
      before do
        inbox.update!(
          working_hours_enabled: true,
          out_of_office_message: 'We are currently closed.'
        )
        inbox.working_hours.find_by(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
          open_all_day: true,
          closed_all_day: false
        )
        allow(mock_llm_chat_service).to receive(:generate_response).and_return({ 'response' => 'conversation_handoff' })
      end

      it 'does not send out of office message after handoff' do
        expect do
          described_class.perform_now(conversation, assistant)
        end.not_to(change { conversation.messages.template.count })

        expect(conversation.reload.status).to eq('open')
      end
    end

    context 'when handoff occurs due to error outside business hours' do
      before do
        inbox.update!(
          working_hours_enabled: true,
          out_of_office_message: 'We are currently closed.'
        )
        inbox.working_hours.find_by(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
          closed_all_day: true,
          open_all_day: false
        )
        allow(mock_llm_chat_service).to receive(:generate_response).and_raise(StandardError, 'API error')
      end

      it 'sends out of office message after error-triggered handoff' do
        expect do
          described_class.perform_now(conversation, assistant)
        end.to change { conversation.messages.template.count }.by(1)

        expect(conversation.reload.status).to eq('open')
        ooo_message = conversation.messages.template.last
        expect(ooo_message.content).to eq('We are currently closed.')
      end
    end

    context 'when no out of office message is configured' do
      before do
        inbox.update!(
          working_hours_enabled: true,
          out_of_office_message: nil
        )
        inbox.working_hours.find_by(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
          closed_all_day: true,
          open_all_day: false
        )
        allow(mock_llm_chat_service).to receive(:generate_response).and_return({ 'response' => 'conversation_handoff' })
      end

      it 'does not send out of office message' do
        expect do
          described_class.perform_now(conversation, assistant)
        end.not_to(change { conversation.messages.template.count })
      end
    end
  end
end
