require 'rails_helper'

RSpec.describe MessageTemplates::HookExecutionService do
  let(:account) { create(:account, custom_attributes: { plan_name: 'startups' }) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, inbox: inbox, account: account, contact: contact, status: :pending) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let!(:captain_inbox_association) { create(:captain_inbox, captain_assistant: assistant, inbox: inbox) }

  def expect_captain_response_scheduled_for(target_conversation)
    scheduled_job = instance_double(ActiveJob::ConfiguredJob)

    expect(Captain::Conversation::ResponseBuilderJob).to receive(:set).with(wait: 3.seconds).and_return(scheduled_job)
    expect(scheduled_job).to receive(:perform_later).with(
      target_conversation,
      assistant,
      0,
      kind_of(Integer),
      kind_of(ActiveSupport::TimeWithZone)
    )
  end

  context 'when captain assistant is configured' do
    context 'when within business hours' do
      before do
        inbox.update!(working_hours_enabled: true)
        inbox.working_hours.find_by(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
          open_all_day: true,
          closed_all_day: false
        )
      end

      it 'schedules captain response job for incoming messages on pending conversations' do
        expect_captain_response_scheduled_for(conversation)

        create(:message, conversation: conversation, message_type: :incoming, account: account)
      end
    end

    context 'when outside business hours' do
      before do
        inbox.update!(
          working_hours_enabled: true,
          out_of_office_message: 'We are currently closed'
        )
        inbox.working_hours.find_by(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
          closed_all_day: true,
          open_all_day: false
        )
      end

      it 'schedules captain response job outside business hours (Captain always responds when configured)' do
        expect_captain_response_scheduled_for(conversation)

        create(:message, conversation: conversation, message_type: :incoming, account: account)
      end

      it 'performs captain handoff when quota is exceeded (OOO template will kick in after handoff)' do
        account.update!(
          limits: { 'captain_responses' => 100 },
          custom_attributes: account.custom_attributes.merge('captain_responses_usage' => 100)
        )

        create(:message, conversation: conversation, message_type: :incoming, account: account)

        expect(conversation.reload.status).to eq('open')
      end

      it 'does not send out of office message when Captain is handling' do
        out_of_office_service = instance_double(MessageTemplates::Template::OutOfOffice)
        allow(MessageTemplates::Template::OutOfOffice).to receive(:new).and_return(out_of_office_service)
        allow(out_of_office_service).to receive(:perform).and_return(true)

        create(:message, conversation: conversation, message_type: :incoming, account: account)

        expect(MessageTemplates::Template::OutOfOffice).not_to have_received(:new)
      end
    end

    context 'when business hours are not enabled' do
      before do
        inbox.update!(working_hours_enabled: false)
      end

      it 'schedules captain response job regardless of time' do
        expect_captain_response_scheduled_for(conversation)

        create(:message, conversation: conversation, message_type: :incoming, account: account)
      end

      it 'schedules captain response with the configured debounce delay' do
        captain_inbox_association.update!(routing_config: { 'response_delay_seconds' => 15, 'response_max_wait_seconds' => 45 })
        scheduled_job = instance_double(ActiveJob::ConfiguredJob)

        expect(Captain::Conversation::ResponseBuilderJob).to receive(:set).with(wait: 15.seconds).and_return(scheduled_job)
        expect(scheduled_job).to receive(:perform_later).with(
          conversation,
          assistant,
          0,
          kind_of(Integer),
          kind_of(ActiveSupport::TimeWithZone)
        )

        create(:message, conversation: conversation, message_type: :incoming, account: account)
      end
    end

    context 'when captain quota is exceeded within business hours' do
      before do
        inbox.update!(working_hours_enabled: true)
        inbox.working_hours.find_by(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
          open_all_day: true,
          closed_all_day: false
        )

        account.update!(
          limits: { 'captain_responses' => 100 },
          custom_attributes: account.custom_attributes.merge('captain_responses_usage' => 100)
        )
      end

      it 'performs handoff within business hours when quota exceeded' do
        create(:message, conversation: conversation, message_type: :incoming, account: account)

        expect(conversation.reload.status).to eq('open')
      end
    end
  end

  context 'when no captain assistant is configured' do
    before do
      CaptainInbox.where(inbox: inbox).destroy_all
    end

    it 'does not schedule captain response job' do
      expect(Captain::Conversation::ResponseBuilderJob).not_to receive(:perform_later)

      create(:message, conversation: conversation, message_type: :incoming, account: account)
    end
  end

  context 'when conversation is open and still manageable by Captain' do
    before do
      conversation.update!(status: :open)
    end

    it 'schedules captain response job and activates the conversation' do
      expect_captain_response_scheduled_for(conversation)

      create(:message, conversation: conversation, message_type: :incoming, account: account)
    end
  end

  context 'when conversation is marked as human controlled' do
    before do
      conversation.update!(status: :open)
      CaptainConversationState.for_conversation!(conversation).apply_ai_mode!(
        mode: 'human_only',
        reason: 'Atendimento assumido por humano'
      )
      inbox.update!(greeting_enabled: true, greeting_message: 'Hello! How can we help you?', enable_email_collect: false)
    end

    it 'does not schedule Captain or send automatic public templates' do
      expect(Captain::Conversation::ResponseBuilderJob).not_to receive(:perform_later)

      expect do
        create(:message, conversation: conversation, message_type: :incoming, account: account)
      end.not_to(change { conversation.reload.messages.template.count })
    end
  end

  context 'when a human has already joined the atendimento' do
    let(:agent) { create(:user, account: account, role: :agent) }

    before do
      create(:message, conversation: conversation, message_type: :outgoing, sender: assistant, account: account, inbox: inbox)
      create(:message, conversation: conversation, message_type: :outgoing, sender: agent, account: account, inbox: inbox, content: 'Vou seguir por aqui.')
      inbox.update!(greeting_enabled: true, greeting_message: 'Hello! How can we help you?', enable_email_collect: false)
    end

    it 'does not schedule Captain or send automatic public templates on the next customer reply' do
      expect(Captain::Conversation::ResponseBuilderJob).not_to receive(:set)
      expect(Captain::Conversation::ResponseBuilderJob).not_to receive(:perform_later)

      expect do
        create(:message, conversation: conversation, message_type: :incoming, account: account, content: 'Me encaminha o que ele passou')
      end.not_to(change { conversation.reload.messages.template.count })

      state = conversation.reload.captain_conversation_state
      expect(conversation.status).to eq('open')
      expect(state.ai_mode).to eq('human_only')
      expect(state.handoff_reason).to eq('Atendimento humano detectado; IA pausada automaticamente.')
    end

    it 'treats WhatsApp native app echoes as human atendimento' do
      create(:message, conversation: conversation, message_type: :incoming, account: account, inbox: inbox, content: 'Pode me chamar aqui?')
      conversation.update!(status: :pending)
      CaptainConversationState.where(conversation: conversation).delete_all
      conversation.reload

      expect(Captain::Conversation::ResponseBuilderJob).not_to receive(:set)
      expect(Captain::Conversation::ResponseBuilderJob).not_to receive(:perform_later)

      conversation.messages.create!(
        message_type: :outgoing,
        account: account,
        inbox: inbox,
        sender: nil,
        content: 'Estou atendendo pelo celular.',
        content_attributes: { 'external_echo' => true }
      )

      state = conversation.reload.captain_conversation_state
      expect(conversation.status).to eq('open')
      expect(state.ai_mode).to eq('human_only')
      expect(state.handoff_reason).to eq('Atendimento humano detectado; IA pausada automaticamente.')
    end
  end

  context 'when contact is already a CRM customer' do
    before do
      contact.update!(contact_type: :customer)
      inbox.update!(greeting_enabled: true, greeting_message: 'Hello! How can we help you?', enable_email_collect: false)
    end

    it 'does not schedule Captain or send automatic public templates' do
      expect(Captain::Conversation::ResponseBuilderJob).not_to receive(:set)
      expect(Captain::Conversation::ResponseBuilderJob).not_to receive(:perform_later)

      expect do
        create(:message, conversation: conversation, message_type: :incoming, account: account)
      end.not_to(change { conversation.reload.messages.template.count })

      state = conversation.reload.captain_conversation_state
      expect(conversation.status).to eq('open')
      expect(state.ai_mode).to eq('human_only')
      expect(state.handoff_reason).to eq('Contato classificado como cliente; atendimento por IA desativado.')
    end
  end

  context 'when message is outgoing' do
    it 'does not schedule captain response job' do
      expect(Captain::Conversation::ResponseBuilderJob).not_to receive(:perform_later)

      create(:message, conversation: conversation, message_type: :outgoing, account: account)
    end
  end

  context 'when greeting and out of office messages with Captain enabled' do
    context 'when conversation is pending (Captain is handling)' do
      before do
        conversation.update!(status: :pending)
      end

      it 'does not create greeting message in conversation' do
        inbox.update!(greeting_enabled: true, greeting_message: 'Hello! How can we help you?', enable_email_collect: false)

        expect do
          create(:message, conversation: conversation, message_type: :incoming, account: account)
        end.not_to(change { conversation.reload.messages.template.count })
      end

      it 'does not create out of office message in conversation' do
        inbox.update!(
          working_hours_enabled: true,
          out_of_office_message: 'We are currently closed',
          enable_email_collect: false
        )
        inbox.working_hours.find_by(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
          closed_all_day: true,
          open_all_day: false
        )

        expect do
          create(:message, conversation: conversation, message_type: :incoming, account: account)
        end.not_to(change { conversation.reload.messages.template.count })
      end
    end

    context 'when conversation is open (transferred to agent)' do
      before do
        conversation.update!(status: :open, assignee: create(:user, account: account))
      end

      it 'creates greeting message in conversation' do
        inbox.update!(greeting_enabled: true, greeting_message: 'Hello! How can we help you?', enable_email_collect: false)

        expect do
          create(:message, conversation: conversation, message_type: :incoming, account: account)
        end.to change { conversation.reload.messages.template.count }.by(1)

        greeting_message = conversation.reload.messages.template.last
        expect(greeting_message.content).to eq('Hello! How can we help you?')
      end

      it 'creates out of office message when outside business hours' do
        inbox.update!(
          working_hours_enabled: true,
          out_of_office_message: 'We are currently closed',
          enable_email_collect: false
        )
        inbox.working_hours.find_by(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
          closed_all_day: true,
          open_all_day: false
        )

        expect do
          create(:message, conversation: conversation, message_type: :incoming, account: account)
        end.to change { conversation.reload.messages.template.count }.by(1)

        out_of_office_message = conversation.reload.messages.template.last
        expect(out_of_office_message.content).to eq('We are currently closed')
      end
    end
  end

  context 'when Captain is not configured' do
    before do
      CaptainInbox.where(inbox: inbox).destroy_all
    end

    it 'creates greeting message in conversation' do
      inbox.update!(greeting_enabled: true, greeting_message: 'Hello! How can we help you?', enable_email_collect: false)

      expect do
        create(:message, conversation: conversation, message_type: :incoming, account: account)
      end.to change { conversation.reload.messages.template.count }.by(1)

      greeting_message = conversation.reload.messages.template.last
      expect(greeting_message.content).to eq('Hello! How can we help you?')
    end

    it 'creates out of office message when outside business hours' do
      inbox.update!(
        working_hours_enabled: true,
        out_of_office_message: 'We are currently closed',
        enable_email_collect: false
      )
      inbox.working_hours.find_by(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
        closed_all_day: true,
        open_all_day: false
      )

      expect do
        create(:message, conversation: conversation, message_type: :incoming, account: account)
      end.to change { conversation.reload.messages.template.count }.by(1)

      out_of_office_message = conversation.reload.messages.template.last
      expect(out_of_office_message.content).to eq('We are currently closed')
    end
  end

  context 'when conversation has a campaign' do
    let(:campaign) { create(:campaign, account: account) }
    let(:campaign_conversation) { create(:conversation, inbox: inbox, account: account, contact: contact, status: :pending, campaign: campaign) }

    it 'schedules captain response job for incoming messages on pending campaign conversations' do
      expect_captain_response_scheduled_for(campaign_conversation)

      create(:message, conversation: campaign_conversation, message_type: :incoming, account: account)
    end

    it 'does not send greeting template on campaign conversations' do
      inbox.update!(greeting_enabled: true, greeting_message: 'Hello! How can we help you?', enable_email_collect: false)

      greeting_service = instance_double(MessageTemplates::Template::Greeting)
      allow(MessageTemplates::Template::Greeting).to receive(:new).and_return(greeting_service)
      allow(greeting_service).to receive(:perform).and_return(true)

      create(:message, conversation: campaign_conversation, message_type: :incoming, account: account)

      expect(MessageTemplates::Template::Greeting).not_to have_received(:new)
    end

    it 'does not send out of office template on campaign conversations' do
      inbox.update!(working_hours_enabled: true, out_of_office_message: 'We are currently closed')
      inbox.working_hours.find_by(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
        closed_all_day: true,
        open_all_day: false
      )

      out_of_office_service = instance_double(MessageTemplates::Template::OutOfOffice)
      allow(MessageTemplates::Template::OutOfOffice).to receive(:new).and_return(out_of_office_service)
      allow(out_of_office_service).to receive(:perform).and_return(true)

      create(:message, conversation: campaign_conversation, message_type: :incoming, account: account)

      expect(MessageTemplates::Template::OutOfOffice).not_to have_received(:new)
    end

    it 'does not send email collect template on campaign conversations' do
      contact.update!(email: nil)
      inbox.update!(enable_email_collect: true)

      email_collect_service = instance_double(MessageTemplates::Template::EmailCollect)
      allow(MessageTemplates::Template::EmailCollect).to receive(:new).and_return(email_collect_service)
      allow(email_collect_service).to receive(:perform).and_return(true)

      create(:message, conversation: campaign_conversation, message_type: :incoming, account: account)

      expect(MessageTemplates::Template::EmailCollect).not_to have_received(:new)
    end

    it 'does not send out of office template after handoff on campaign conversations when quota is exceeded' do
      account.update!(
        limits: { 'captain_responses' => 100 },
        custom_attributes: account.custom_attributes.merge('captain_responses_usage' => 100)
      )
      inbox.update!(
        working_hours_enabled: true,
        out_of_office_message: 'We are currently closed'
      )
      inbox.working_hours.find_by(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
        closed_all_day: true,
        open_all_day: false
      )

      expect do
        create(:message, conversation: campaign_conversation, message_type: :incoming, account: account)
      end.not_to(change { campaign_conversation.messages.template.count })
    end
  end

  context 'when Captain quota is exceeded and handoff happens' do
    before do
      account.update!(
        limits: { 'captain_responses' => 100 },
        custom_attributes: account.custom_attributes.merge('captain_responses_usage' => 100)
      )
    end

    context 'when outside business hours' do
      before do
        inbox.update!(
          working_hours_enabled: true,
          out_of_office_message: 'We are currently closed. Please leave your email.',
          enable_email_collect: false
        )
        inbox.working_hours.find_by(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
          closed_all_day: true,
          open_all_day: false
        )
      end

      it 'sends out of office message after handoff due to quota exceeded' do
        expect do
          create(:message, conversation: conversation, message_type: :incoming, account: account)
        end.to change { conversation.messages.template.count }.by(1)

        expect(conversation.reload.status).to eq('open')
        ooo_message = conversation.messages.template.last
        expect(ooo_message.content).to eq('We are currently closed. Please leave your email.')
      end
    end

    context 'when within business hours' do
      before do
        inbox.update!(
          working_hours_enabled: true,
          out_of_office_message: 'We are currently closed.',
          enable_email_collect: false
        )
        inbox.working_hours.find_by(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
          open_all_day: true,
          closed_all_day: false
        )
      end

      it 'does not send out of office message after handoff' do
        expect do
          create(:message, conversation: conversation, message_type: :incoming, account: account)
        end.not_to(change { conversation.messages.template.count })

        expect(conversation.reload.status).to eq('open')
      end
    end
  end
end
