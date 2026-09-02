# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Assistant::InitialMessageResponseService do
  subject(:response) { described_class.new(message: message).perform }

  context 'with the planning message from the website' do
    let(:message) do
      <<~TEXT.squish
        Olá! Vim pelo site de planejamento previdenciário. Quero entender se já posso me aposentar e qual
        o melhor caminho no meu caso. Como funciona a análise?
      TEXT
    end

    it 'explains the analysis and asks for CNIS and age' do
      expect(response).to include('histórico de contribuições, vínculos e documentos previdenciários')
      expect(response).to include('CNIS atualizado e sua idade')
      expect(response).not_to include('conte em uma frase')
    end
  end

  {
    'planning plus contribution' => 'Olá! Vim pelo site de planejamento previdenciário e quero conferir meu tempo de contribuição.',
    'planning plus revision' => 'Olá! Vim pelo site de planejamento previdenciário e quero revisar meu CNIS.',
    'retirement contribution time' => 'Tenho tempo de contribuição e quero saber se posso me aposentar.',
    'retirement rules' => 'Quero saber das regras da aposentadoria.',
    'retirement timing' => 'Qual é o prazo para saber se posso me aposentar?'
  }.each do |case_name, message_text|
    context "with #{case_name}" do
      let(:message) { message_text }

      it 'prioritizes planning without falling into a broader pattern' do
        expect(response).to match(/regra (?:é )?mais vantajosa/)
        expect(response).to include('CNIS atualizado e sua idade')
      end
    end
  end

  context 'with planning plus denial and a CNIS only mentioned as available' do
    let(:message) { 'Olá! Vim pelo site de planejamento previdenciário, tive um pedido negado e tenho o CNIS.' }

    it 'keeps planning priority without claiming that the CNIS was sent' do
      expect(response).to match(/regra (?:é )?mais vantajosa/)
      expect(response).to match(/(?:me envie|preciso do) seu CNIS atualizado e sua idade/)
      expect(response).not_to include('CNIS que você já enviou')
    end
  end

  context 'with planning and a CNIS that was actually sent' do
    let(:message) { 'Vim pelo site de planejamento previdenciário e enviei meu CNIS.' }

    it 'asks only for the missing age' do
      expect(response).to include('informe sua idade')
      expect(response).to include('CNIS que você já enviou')
      expect(response).not_to include('me envie seu CNIS atualizado e sua idade')
    end
  end

  context 'when the customer already provided material planning details' do
    let(:message) { 'Tenho 65 anos e anexei meu CNIS para o planejamento previdenciário.' }

    it 'does not request the same intake data again in a provider fallback' do
      expect(response).to include('CNIS e a idade já informados')
      expect(response).not_to include('me envie seu CNIS atualizado e sua idade')
    end
  end

  context 'when only age was already provided for planning' do
    let(:message) { 'Tenho 65 anos e quero saber se posso me aposentar.' }

    it 'asks only for CNIS without claiming a document was received' do
      expect(response).to include('me envie seu CNIS atualizado')
      expect(response).not_to match(/documentos? que (?:você )?(?:enviou|anexou)/i)
      expect(response).not_to include('sua idade. Com essas informações')
    end
  end

  context 'when years of contribution are supplied without the customer age' do
    let(:message) { 'Tenho 35 anos de contribuição e quero saber se posso me aposentar.' }

    it 'does not mistake contribution time for age' do
      expect(response).to include('CNIS atualizado e sua idade')
      expect(response).not_to include('Vou considerar a idade que você já informou')
    end
  end

  [
    'Contribuo para o INSS há 35 anos e quero me aposentar.',
    'Tenho 35 anos contribuindo e quero me aposentar.',
    'Tenho 35 anos de INSS e quero me aposentar.'
  ].each do |message_text|
    context "with non-age years phrased as #{message_text}" do
      let(:message) { message_text }

      it 'still requests the customer age' do
        expect(response).to include('CNIS atualizado e sua idade')
        expect(response).not_to include('Vou considerar a idade que você já informou')
      end
    end
  end

  context 'when CNIS and age were actually supplied for planning' do
    let(:message) { 'Tenho 65 anos e anexei meu CNIS para o planejamento previdenciário.' }

    it 'continues with one concrete next question' do
      expect(response).to include('Você já fez algum pedido de aposentadoria no INSS?')
    end
  end

  context 'when a BPC lead already supplies the age' do
    let(:message) { 'Tenho 70 anos e preciso entender o BPC LOAS.' }

    it 'keeps the specific explanation and next intake step' do
      expect(response).to include('renda e composição familiar')
      expect(response).to include('Quantas pessoas moram com você')
    end
  end

  context 'when a pension lead supplies the death date and relationship' do
    let(:message) { 'Meu marido faleceu em 10/07/2026 e preciso de pensão por morte.' }

    it 'continues after both supplied details' do
      expect(response).to include('contribuía para o INSS ou recebia algum benefício')
      expect(response).not_to include('informe a data do falecimento')
      expect(response).not_to include('qual era sua relação')
    end
  end

  context 'when an incapacity lead sent a medical report' do
    let(:message) { 'Enviei meu laudo e preciso de auxílio-doença.' }

    it 'asks for work status without requesting the report again' do
      expect(response).to include('informe se está trabalhando ou afastado')
      expect(response).not_to include('envie o laudo ou relatório médico mais recente')
    end
  end

  context 'when a maternity lead supplies the expected month' do
    let(:message) { 'Meu parto está previsto para setembro e quero o salário-maternidade.' }

    it 'asks only for the contribution category next' do
      expect(response).to include('Como você contribui para o INSS')
      expect(response).not_to include('informe a data do parto ou a previsão')
    end
  end

  context 'when a BPC lead supplies age and household size' do
    let(:message) { 'Tenho 70 anos, moram 3 pessoas comigo e preciso do BPC.' }

    it 'moves to household income without repeating supplied data' do
      expect(response).to include('renda mensal aproximada')
      expect(response).not_to include('informe sua idade')
      expect(response).not_to include('Quantas pessoas moram com você?')
    end
  end

  context 'with a generic contribution question' do
    let(:message) { 'Quero entender se minhas contribuições estão corretas.' }

    it 'uses the contribution analysis instead of the generic greeting' do
      expect(response).to include('códigos, alíquotas, períodos')
    end
  end

  {
    'pedido negado e prazo de recurso' => ['Meu pedido foi negado e preciso recorrer.', 'carta de indeferimento'],
    'revisão de benefício' => ['Quero revisar o valor do meu benefício.', 'carta de concessão'],
    'BPC/LOAS' => ['Como funciona o BPC LOAS para pessoa com deficiência?', 'CadÚnico'],
    'pensão por morte' => ['Meu marido faleceu e preciso de pensão por morte.', 'data do falecimento'],
    'benefício por incapacidade' => ['Preciso de auxílio-doença por incapacidade.', 'trabalhando ou afastado'],
    'salário-maternidade' => ['Estou grávida e quero saber sobre salário-maternidade.', 'data do parto'],
    'atividade especial' => ['Trabalhei em atividade especial e tenho PPP.', 'PPP ou LTCAT'],
    'tempo rural' => ['Fui trabalhador rural por vários anos.', 'meio rural'],
    'contribuições como MEI' => ['Sou MEI e quero saber se contribuo corretamente.', 'códigos, alíquotas, períodos'],
    'análise do CNIS' => ['Meu CNIS tem vínculo ausente.', 'vínculos, remunerações, contribuições']
  }.each do |intent, (message_text, expected_text)|
    context "with #{intent}" do
      let(:message) { message_text }

      it 'returns the matching initial explanation' do
        expect(response).to include(expected_text)
      end
    end
  end

  context 'with a generic first contact' do
    let(:message) { 'Olá, preciso de ajuda jurídica.' }

    it 'introduces Dra. Letícia without impersonating Dra. Paula and asks for a brief description' do
      expect(response).to include(
        'Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos'
      )
      expect(response).not_to match(/(?:sou|aqui é) a Dra\. Paula Matos/i)
      expect(response).not_to include('Capitão')
      expect(response).to include('o que você precisa resolver')
    end
  end

  context 'when another lawyer requested the customer CNIS' do
    let(:message) { 'Uma advogada me pediu meu CNIS?' }

    it 'identifies itself as a lawyer, explains Meu INSS and never requests the CPF' do
      expect(response).to include('Também sou advogada e posso resolver isso')
      expect(response).to include('Meu INSS')
      expect(response).to include('Extrato de Contribuição (CNIS)')
      expect(response).not_to match(/(?:envie|informe|passe|mande).{0,30}\bCPF\b/i)
    end
  end

  {
    'RG' => /órgão de identificação do seu estado/i,
    'PPP' => /empresa onde você trabalhou.*RH/i,
    'laudo' => /médico ou serviço de saúde/i
  }.each do |document_name, guidance_pattern|
    context "when another lawyer requested the customer #{document_name}" do
      let(:message) { "Uma advogada me pediu meu #{document_name}. Como consigo esse documento?" }

      it 'recognizes the named document and answers how to obtain it' do
        expect(response).to include('Também sou advogada e posso resolver isso')
        expect(response).to include("pediu seu #{document_name}")
        expect(response).to match(guidance_pattern)
        expect(response).not_to include('O que a outra advogada pediu')
      end
    end
  end

  describe '#other_lawyer_request?' do
    it 'distinguishes a request made by another lawyer from a request to speak with Dra. Letícia' do
      expect(described_class.new(message: 'Uma advogada me pediu meu PPP.').other_lawyer_request?).to be(true)
      expect(described_class.new(message: 'Quero falar com uma advogada.').other_lawyer_request?).to be(false)
    end
  end

  describe '#greeting_only?' do
    it 'recognizes a greeting without treating a described case as generic' do
      expect(described_class.new(message: 'Bom dia!').greeting_only?).to be(true)
      expect(described_class.new(message: 'Olá, boa tarde!').greeting_only?).to be(true)
      expect(described_class.new(message: 'Oi! Tudo bem?').greeting_only?).to be(true)
      expect(described_class.new(message: 'Bom dia, preciso revisar meu benefício.').greeting_only?).to be(false)
    end

    it 'does not add the new-lead review notice to a compound greeting' do
      response = described_class.new(message: 'Olá, boa tarde!', new_lead: true).perform

      expect(response).to include('Dra. Letícia')
      expect(response).not_to include(described_class::NEW_LEAD_REVIEW_NOTICE)
    end
  end
end
