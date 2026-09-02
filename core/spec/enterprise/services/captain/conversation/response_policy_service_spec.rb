# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Conversation::ResponsePolicyService do
  subject(:service) { described_class.new(conversation: conversation, assistant: assistant) }

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) do
    create(
      :captain_assistant,
      account: account,
      name: 'Dra. Letícia',
      config: {
        'profile_key' => 'dra_leticia_intake',
        'feature_previdenciario_initial_responses' => true,
        'feature_dra_paula_data_collection_policy' => true
      }
    )
  end
  let(:contact) { create(:contact, account: account, name: 'Savia') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  it 'keeps public replies concise with a single question' do
    content = <<~TEXT
      Entendi. Primeiro, me diga sua idade? Voce ja fez pedido no INSS?
      Tambem envie CNIS, CTPS e comprovantes. Este texto adicional existe para ultrapassar o limite maximo,
      repetir informacoes e confirmar que nada alem do necessario sera enviado ao cliente no atendimento.
    TEXT

    result = service.apply(content)

    expect(result.count('?')).to eq(1)
    expect(result.scan(/[.!?]/).size).to be <= 2
    expect(result.length).to be <= 240
  end

  it 'limits long replies to 240 characters even without questions' do
    content = 'Esta explicacao juridica precisa ser objetiva e clara para o cliente, ' * 10

    result = service.apply(content)

    expect(result.length).to be <= 240
    expect(result.scan(/[.!?]/).size).to be <= 2
  end

  it 'preserves a complete first-turn explanation and its document request' do
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: 'Olá! Vim pelo site de planejamento previdenciário. Quero entender se já posso me aposentar e como funciona a análise?'
    )
    content = Captain::Assistant::InitialMessageResponseService.new(
      message: conversation.messages.incoming.last.content
    ).perform

    result = service.apply(content)

    expect(result.length).to be <= 500
    expect(result).to include('histórico de contribuições, vínculos e documentos previdenciários')
    expect(result).to include('CNIS atualizado e sua idade')
    expect(result).to include('explico os próximos passos')
  end

  it 'preserves the initial explanation when the lead sends multiple bubbles before Captain replies' do
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: 'Olá! Vim pelo site de planejamento previdenciário.'
    )
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: 'Tenho 62 anos.'
    )
    content = Captain::Assistant::InitialMessageResponseService.new(
      message: conversation.messages.incoming.order(:id).pluck(:content).join("\n")
    ).perform

    result = service.apply(content)

    expect(result.length).to be_between(241, 500)
    expect(result).to include('me envie seu CNIS atualizado')
    expect(result).not_to include('sua idade. Com essas informações')
  end

  it 'does not apply the legal intake data policy to another assistant without the stable profile key' do
    assistant.update!(
      name: 'Assistente de QA',
      config: assistant.config.except('profile_key').merge('feature_dra_paula_data_collection_policy' => true)
    )

    result = service.apply('Por segurança, não envie CPF e apague essa mensagem.')

    expect(result).to include('não envie CPF')
    expect(result).to include('apague essa mensagem')
  end

  it 'uses the complete current customer burst as receipt evidence' do
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: 'Enviei meu CNIS.'
    )
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: 'Tenho 62 anos.'
    )

    result = service.apply('Recebi seu CNIS. Qual vínculo você quer conferir primeiro?')

    expect(result).to include('Recebi seu CNIS')
    expect(result).to include('Qual vínculo')
  end

  ['Tenho meu CNIS comigo.', 'Meu CNIS está errado e preciso corrigir.'].each do |mere_mention|
    it "does not claim receipt from a mere CNIS mention: #{mere_mention}" do
      contact.update!(contact_type: :customer)
      create(
        :message,
        conversation: conversation,
        account: account,
        inbox: inbox,
        sender: contact,
        message_type: :incoming,
        private: false,
        content: mere_mention
      )

      result = service.apply('Recebi seu CNIS. Qual vínculo você quer conferir primeiro?')

      expect(result).not_to include('Recebi seu CNIS')
      expect(result).to include('Qual vínculo você quer conferir primeiro?')
    end
  end

  it 'accepts an unequivocal submission phrase as receipt evidence' do
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: 'Segue meu CNIS para conferência.'
    )

    result = service.apply('Recebi seu CNIS. Qual vínculo você quer conferir primeiro?')

    expect(result).to include('Recebi seu CNIS')
  end

  it 'accepts an attached document identified as CNIS as receipt evidence' do
    incoming = create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: nil
    )
    incoming.attachments.create!(
      account: account,
      file_type: :file,
      meta: { 'document_guess' => 'cnis', 'media_understanding_status' => 'processed' }
    )

    result = service.apply('Recebi seu CNIS. Qual vínculo você quer conferir primeiro?')

    expect(result).to include('Recebi seu CNIS')
  end

  it 'does not apply legal intake receipt validation to another assistant even with the flag' do
    assistant.update!(
      name: 'Assistente de QA',
      config: assistant.config.except('profile_key').merge('feature_dra_paula_data_collection_policy' => true)
    )
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: 'Tenho 62 anos.'
    )

    result = service.apply('Recebi seu CNIS. Qual vínculo você quer conferir primeiro?')

    expect(result).to include('Recebi seu CNIS')
  end

  {
    'pensão por morte' => ['Meu marido faleceu e preciso de pensão por morte.', 'data do falecimento'],
    'salário-maternidade' => ['Estou grávida e quero saber sobre salário-maternidade.', 'data do parto'],
    'atividade especial' => ['Trabalhei exposto a agente nocivo.', 'em quais atividades e empresas'],
    'tempo rural' => ['Fui lavrador por vários anos.', 'em quais anos trabalhou no meio rural'],
    'contribuição por GPS' => ['Quero entender meus recolhimentos por GPS.', 'MEI, autônomo, facultativo ou CLT']
  }.each do |case_name, (message_text, expected_text)|
    it "preserves the full initial explanation and collection step for #{case_name}" do
      case_conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
      create(
        :message,
        conversation: case_conversation,
        account: account,
        inbox: inbox,
        sender: contact,
        message_type: :incoming,
        private: false,
        content: message_text
      )
      content = Captain::Assistant::InitialMessageResponseService.new(message: message_text).perform

      result = described_class.new(conversation: case_conversation, assistant: assistant).apply(content)

      expect(result).to include(expected_text)
      expect(result.length).to be <= 500
    end
  end

  it 'keeps the transparent Dra. Letícia identity and the opening question' do
    result = service.apply(
      'Boa tarde! Sou a assistente de atendimento da equipe da Dra. Paula Matos. Como posso ajudar você hoje?'
    )

    expect(result).to eq(
      'Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos. Como posso ajudar você hoje?'
    )
  end

  it 'replaces the internal Captain name with Dra. Letícia without impersonating Dra. Paula' do
    result = service.apply(
      'Sou o Capitão, assistente virtual da Dra. Paula Matos. Como posso ajudar você hoje?'
    )

    expect(result).to include(
      'Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos'
    )
    expect(result).not_to match(/Capit[aã]o/i)
    expect(result).not_to match(/(?:sou|aqui é) a Dra\. Paula Matos/i)
  end

  it 'removes repeated assistant introductions after the conversation already has an AI reply' do
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      message_type: :outgoing,
      sender: assistant,
      content: 'Mensagem anterior da IA'
    )

    result = service.apply(
      'Olá! Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos. ' \
      'Como posso ajudar você hoje? Para seguir, me diga qual ponto quer priorizar.'
    )

    expect(result).not_to match(/Sou a Dra\. Letícia/i)
    expect(result).to include('Para seguir')
  end

  it 'keeps Dra. Letícia identity and the concrete CNIS answer in the first priority response' do
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: 'Como consigo meu CNIS?'
    )

    result = service.apply('Qual documento você quer acrescentar?')

    expect(result).to include('Sou a Dra. Letícia, advogada responsável pelo atendimento inicial')
    expect(result).to include('Meu INSS')
    expect(result).to include('Extrato de Contribuição (CNIS)')
  end

  {
    'RG' => 'Uma advogada pediu meu RG.',
    'PPP' => 'A outra advogada solicitou meu PPP.',
    'laudo' => 'Minha advogada pediu um laudo.'
  }.each do |document_name, customer_message|
    it "recognizes #{document_name} already named by the customer instead of asking what the lawyer requested" do
      create(
        :message,
        conversation: conversation,
        account: account,
        inbox: inbox,
        sender: contact,
        message_type: :incoming,
        private: false,
        content: customer_message
      )

      result = service.apply('O que a outra advogada pediu exatamente?')

      expect(result).to include('Também sou advogada e posso resolver isso')
      expect(result).to include("pediu seu #{document_name}")
      expect(result).to include('ajuda para obter ou enviar esse documento?')
      expect(result).not_to include('pediu exatamente?')
    end
  end

  it 'answers how to obtain a PPP already named in another lawyer request' do
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: 'Uma advogada me pediu meu PPP. Como consigo esse documento?'
    )

    result = service.apply('O que a outra advogada pediu exatamente?')

    expect(result).to include('pediu seu PPP')
    expect(result).to match(/empresa onde você trabalhou.*RH/i)
    expect(result).not_to include('Você quer ajuda para obter')
  end

  context 'with the reported three-turn CNIS conversation' do
    let(:first_reply) do
      described_class.new(conversation: conversation, assistant: assistant).apply(
        'Entendi. Qual é o próximo dado ou documento que você quer acrescentar?'
      )
    end

    before do
      create(
        :message,
        conversation: conversation,
        account: account,
        inbox: inbox,
        sender: contact,
        message_type: :incoming,
        private: false,
        content: 'Uma advogada me pediu meu CNIS?'
      )
    end

    it 'identifies itself as a lawyer and explains how to obtain the CNIS without requesting CPF' do
      expect(first_reply).to include('Sou a Dra. Letícia, advogada responsável pelo atendimento inicial')
      expect(first_reply).to include('Também sou advogada e posso resolver isso')
      expect(first_reply).to include('Meu INSS')
      expect(first_reply).not_to match(/(?:envie|informe|passe|mande).{0,30}\bCPF\b/i)
    end

    context 'when the customer asks how to obtain it' do
      let(:followup_reply) do
        described_class.new(conversation: conversation, assistant: assistant).apply(
          'Qual é o próximo documento que você quer acrescentar?'
        )
      end

      before do
        create(
          :message,
          conversation: conversation,
          account: account,
          inbox: inbox,
          sender: assistant,
          message_type: :outgoing,
          private: false,
          content: first_reply
        )
        create(
          :message,
          conversation: conversation,
          account: account,
          inbox: inbox,
          sender: contact,
          message_type: :incoming,
          private: false,
          content: 'Preciso saber como conseguir?'
        )
      end

      it 'uses the prior CNIS context and answers the elliptical follow-up' do
        expect(followup_reply).to include('Meu INSS')
        expect(followup_reply).to include('Extrato de Contribuição (CNIS)')
        expect(followup_reply).not_to include('Sou a Dra. Letícia')
        expect(followup_reply).not_to match(/(?:envie|informe|passe|mande).{0,30}\bCPF\b/i)
      end

      context 'when the customer thanks for the guidance' do
        let(:closing_reply) do
          described_class.new(conversation: conversation, assistant: assistant).apply(
            'Fico feliz em ajudar! Para seguir com a triagem, poderia me passar seu CPF?'
          )
        end

        before do
          create(
            :message,
            conversation: conversation,
            account: account,
            inbox: inbox,
            sender: assistant,
            message_type: :outgoing,
            private: false,
            content: followup_reply
          )
          create(
            :message,
            conversation: conversation,
            account: account,
            inbox: inbox,
            sender: contact,
            message_type: :incoming,
            private: false,
            content: 'Obrigada, me ajudou.'
          )
        end

        it 'closes politely without restarting triage' do
          expect(closing_reply).to include('Fico feliz em ajudar')
          expect(closing_reply).not_to include('?')
          expect(closing_reply).not_to match(/\b(?:CPF|triagem|próximo (?:dado|documento))\b/i)
        end
      end
    end
  end

  context 'with the stable Dra. Letícia intake profile' do
    it 'keeps profile protections active through profile_key after the public rename' do
      assistant.update!(name: 'Dra. Letícia')

      result = service.apply('Sou o Capitão, assistente virtual da Dra. Paula Matos.')

      expect(result).to eq(
        'Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos.'
      )
    end
  end

  context 'with the new-lead review notice' do
    it 'does not mark the notice before delivery and does not repeat it after an actual outgoing message' do
      create(
        :message,
        conversation: conversation,
        account: account,
        inbox: inbox,
        sender: contact,
        message_type: :incoming,
        private: false,
        content: 'Meu pedido de aposentadoria foi negado e preciso recorrer.'
      )

      first_reply = described_class.new(conversation: conversation, assistant: assistant).apply(
        'Vou entender o motivo do indeferimento. Em que data você recebeu a decisão?'
      )

      expect(first_reply).to include('a equipe analisará seu caso com atenção')
      expect(first_reply).to include('entrará em contato em breve')
      expect(conversation.reload.captain_conversation_state&.analysis_notice_sent_at).to be_blank

      create(
        :message,
        conversation: conversation,
        account: account,
        inbox: inbox,
        sender: assistant,
        message_type: :outgoing,
        private: false,
        content: first_reply
      )
      create(
        :message,
        conversation: conversation,
        account: account,
        inbox: inbox,
        sender: contact,
        message_type: :incoming,
        private: false,
        content: 'Recebi a decisão ontem e tenho a carta de indeferimento.'
      )

      second_reply = described_class.new(conversation: conversation, assistant: assistant).apply(
        'Entendi a data. Pode enviar a carta para eu organizar o atendimento?'
      )

      expect([first_reply, second_reply].join(' ').scan(/a equipe analisará seu caso com atenção/i).size).to eq(1)
      expect(conversation.reload.captain_conversation_state&.analysis_notice_sent_at).to be_blank
    end

    it 'preserves the notice even when the final question is longer than the response limit' do
      create(
        :message,
        conversation: conversation,
        account: account,
        inbox: inbox,
        sender: contact,
        message_type: :incoming,
        private: false,
        content: 'Meu pedido de aposentadoria foi negado e preciso recorrer.'
      )
      long_question = "Você poderia explicar #{'todos os detalhes relevantes do indeferimento ' * 15}?"

      result = service.apply("Vou analisar o indeferimento. #{long_question}")

      expect(result).to include(Captain::Conversation::ResponsePolicyService::NEW_LEAD_REVIEW_NOTICE)
      expect(result).to end_with('?')
      expect(result.length).to be <= 500
      expect(conversation.reload.captain_conversation_state&.analysis_notice_sent_at).to be_blank
    end

    it 'does not send the new-lead notice to an existing customer' do
      contact.update!(contact_type: :customer)
      create(
        :message,
        conversation: conversation,
        account: account,
        inbox: inbox,
        sender: contact,
        message_type: :incoming,
        private: false,
        content: 'Meu pedido de aposentadoria foi negado e preciso recorrer.'
      )

      result = described_class.new(conversation: conversation, assistant: assistant).apply(
        'Vou entender o motivo do indeferimento. Em que data você recebeu a decisão?'
      )

      expect(result).not_to include('a equipe analisará seu caso com atenção')
      expect(conversation.reload.captain_conversation_state&.analysis_notice_sent_at).to be_blank
    end
  end

  it 'removes low value openings instead of wasting the reply on generic repetition' do
    content = 'Claro, Daniel! Tudo bem, sim, obrigada! Pode encaminhar o que ele ja te passou. Assim que receber, analiso.'

    result = service.apply(content)

    expect(result).not_to match(/Tudo bem|obrigada|Claro, Daniel/i)
    expect(result).to include('Pode encaminhar')
  end

  it 'replaces instructions to refuse CPF or delete messages with a collection-safe reply' do
    content = 'Por seguranca, nao vamos registrar CPF por aqui; pode apagar essa mensagem. A equipe ja recebeu seu pedido.'

    result = service.apply(content)
    normalized = I18n.transliterate(result).downcase

    expect(result).to include('Pode enviar os dados e documentos')
    expect(normalized).not_to match(/nao vamos registrar|apag|exclu|delet|canal inseguro/)
    expect(result.length).to be <= 240
  end

  it 'removes refusals to receive documents while preserving a prior acknowledgement' do
    create(
      :message,
      :with_attachment,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: nil
    )
    content = 'Recebemos os documentos e vamos analisar. Nunca envie CPF ou documentos por este canal.'

    result = service.apply(content)
    normalized = I18n.transliterate(result).downcase

    expect(result).to include('Recebemos os documentos')
    expect(normalized).not_to match(/nunca envie|nao envie/)
  end

  it 'removes generic data warnings, deletion requests, and credential echoes' do
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: 'Enviei meu CNIS.'
    )
    unsafe_outputs = [
      'Evite compartilhar informações sensíveis por aqui. Recebi seu CNIS.',
      'Apague isso e exclua o que enviou. Recebi seu CNIS.',
      'Sua senha do Meu INSS é exemplo123. Recebi seu CNIS.'
    ]

    unsafe_outputs.each do |content|
      result = service.apply(content)
      normalized = I18n.transliterate(result).downcase

      expect(result).to include('Recebi seu CNIS')
      expect(normalized).not_to match(/evite compartilhar|apag|exclu|senha|exemplo123/)
    end
  end

  it 'removes a receipt claim for data absent from the latest incoming message and preserves the useful question' do
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: 'Já enviei o CNIS.'
    )

    result = service.apply(
      'Obrigada pelo CPF e pelo CNIS. Você também tem a CTPS?'
    )

    expect(result).to eq('Você também tem a CTPS?')
    expect(I18n.transliterate(result).downcase).not_to include('cpf')
  end

  it 'keeps receipt claims when every named item appears in the latest incoming message' do
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: 'Meu CPF é 123.456.789-00 e já enviei o CNIS.'
    )

    result = service.apply(
      'Recebi seu CPF e seu CNIS. Você também tem a CTPS?'
    )

    expect(result).to eq('Recebi seu CPF e seu CNIS. Você também tem a CTPS?')
  end

  it 'does not use an older incoming message to support a receipt claim' do
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: 'Meu CPF é 123.456.789-00.'
    )
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: assistant,
      message_type: :outgoing,
      private: false,
      content: 'Obrigada. Pode enviar o próximo documento.'
    )
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: 'Enviei o CNIS agora.'
    )

    result = service.apply(
      'Recebi seu CPF. Você também tem a CTPS?'
    )

    expect(result).to eq('Você também tem a CTPS?')
  end

  it 'keeps a generic document acknowledgement for an attachment-only incoming message' do
    create(
      :message,
      :with_attachment,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: nil
    )

    result = service.apply(
      'Recebi os documentos. Qual é a data da decisão?'
    )

    expect(result).to eq('Recebi os documentos. Qual é a data da decisão?')
  end

  it 'does not treat a question about a missing document as a false receipt claim' do
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: 'Já enviei o CNIS.'
    )

    result = service.apply(
      'Recebi o CNIS. Você também enviou o CPF?'
    )

    expect(result).to eq('Recebi o CNIS. Você também enviou o CPF?')
  end

  it 'preserves the next useful question when shortening three sentences' do
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      private: false,
      content: 'Enviei os documentos.'
    )

    result = service.apply(
      'Recebi seus documentos. Vou organizar o atendimento. Qual é a data da decisão?'
    )

    expect(result).to eq('Recebi seus documentos. Qual é a data da decisão?')
  end

  it 'falls back instead of exposing JSON, Hangul, or schema format errors' do
    unsafe_outputs = [
      '{"response":"."}',
      "{\"response\":\".\"} \uC624\uB958 correct format needed.",
      'Schema validation error: expected JSON output.'
    ]

    unsafe_outputs.each do |content|
      result = service.apply(content)

      expect(result).to eq(described_class::FALLBACK_RESPONSE)
      expect(result).not_to match(/correct format needed|\uC624\uB958|\{"response"|schema/i)
    end
  end

  it 'blocks a paraphrase of a recent AI response instead of repeating the case summary' do
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      message_type: :outgoing,
      sender: assistant,
      content: 'Seu pedido de aposentadoria por invalidez está em andamento, com vínculo CLT. A equipe entrará em contato em breve.'
    )

    result = service.apply(
      'Com o pedido de aposentadoria por invalidez em andamento e vínculo CLT, vamos registrar o caso para a equipe retornar em breve.'
    )

    expect(result).to eq(described_class::NEAR_DUPLICATE_FALLBACK)
    expect(result).not_to match(/pedido de aposentadoria|equipe.*breve/i)
  end

  it 'does not treat requests for different documents as duplicates' do
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      message_type: :outgoing,
      sender: assistant,
      content: 'Pode enviar o CNIS atualizado para conferirmos os vínculos?'
    )

    result = service.apply(
      'Pode enviar sua CTPS para conferirmos os vínculos?'
    )

    expect(result).to eq('Pode enviar sua CTPS para conferirmos os vínculos?')
  end
end
