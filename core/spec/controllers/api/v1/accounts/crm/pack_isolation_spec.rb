require 'rails_helper'

# 2.8 do PLANO_17_09.md — "conta de clínica não vê nada jurídico".
# O aceite roda no payload de options: categorias, tipos de atividade e
# campos de uma conta com pack `clinic` não podem conter termos do pack
# `legal`; o inverso mantém a paridade jurídica.
RSpec.describe 'CRM pack isolation', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }

  def options
    get "/api/v1/accounts/#{account.id}/crm/options", headers: headers, as: :json
    response.parsed_body
  end

  context 'when the account runs the clinic pack' do
    before do
      account.enable_features!('crm_universal')
      Crm::PackInstaller.new(account).install('clinic')
    end

    it 'lista categorias do pack clinic' do
      values = options['categories'].map { |o| o['value'] }
      expect(values).to include('consulta', 'exame', 'procedimento')
    end

    it 'não expõe categorias jurídicas' do
      values = options['categories'].map { |o| o['value'] }
      expect(values).not_to include('previdenciario', 'trabalhista', 'criminal')
    end

    it 'não oferece tipos de atividade jurídicos' do
      keys = options['activity_types'].map { |o| o['value'] }
      expect(keys).not_to include('revisao_juridica', 'analise_documental', 'solicitacao_documentos')
      expect(keys).to include('confirmacao_agendamento')
    end

    it 'expõe campos da clínica e nenhum campo jurídico' do
      keys = options['field_definitions'].map { |o| o['key'] }
      expect(keys).to include('convenio', 'especialidade', 'data_preferida')
      expect(keys).not_to include('numero_processo', 'parte_contraria')
    end

    it 'traz perguntas do analista do pack clinic' do
      prompts = options['analyst_prompts']
      expect(prompts).to include('Quantos agendamentos estão pendentes de confirmação?')
      expect(prompts.join).not_to include('INSS')
    end
  end

  context 'when the account runs the legal pack' do
    before do
      account.enable_features!('crm_universal')
      Crm::PackInstaller.new(account).install('legal')
    end

    it 'mantém a paridade jurídica' do
      values = options['categories'].map { |o| o['value'] }
      expect(values).to include('previdenciario', 'trabalhista')
    end
  end

  context 'when packs load from disk' do
    it 'reconhece clinic, real_estate e education' do
      %w[clinic real_estate education sales_default legal].each do |slug|
        pack = Crm::Pack.find!(slug)
        expect(pack.categories).not_to be_empty
        expect(pack.activity_types).not_to be_empty
      end
    end

    it 'templates de funil marcam etapas terminais' do
      Crm::Pack.find!('clinic').pipeline_template[:stages].tap do |stages|
        expect(stages.filter_map { |s| s[:terminal_outcome] }.sort).to eq(%w[lost won])
      end
    end
  end
end
