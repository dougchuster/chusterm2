class Captain::DefaultPlaybooksSeeder
  DEFAULT_PLAYBOOKS = [
    {
      name: 'Triagem INSS',
      legal_area: 'INSS',
      case_type: 'beneficio_previdenciario',
      objective: 'Identificar beneficio, urgencia, documentos e proxima acao.',
      required_fields: %w[beneficio cpf documentos_medicos data_indeferimento],
      escalation_rules: {
        urgent_terms: %w[indeferido pericia judicial prazo bloqueado suspenso],
        handoff_when: 'documentos insuficientes, prazo em risco ou pedido de advogado humano'
      },
      instructions: 'Confirme o beneficio, colete datas relevantes, pergunte sobre documentos e nao prometa resultado.'
    },
    {
      name: 'Triagem Trabalhista',
      legal_area: 'Trabalhista',
      case_type: 'verbas_rescisorias',
      objective: 'Entender vinculo, datas, verbas em aberto e risco de prazo.',
      required_fields: %w[data_admissao data_demissao cargo salario documentos],
      escalation_rules: {
        urgent_terms: %w[prazo audiencia rescisao justa_causa acidente],
        handoff_when: 'existir audiencia, acidente, justa causa ou risco de prescricao'
      },
      instructions: 'Colete dados do contrato, evite calcular valores finais sem documentos e sugira envio de provas.'
    },
    {
      name: 'Triagem Civel',
      legal_area: 'Civel',
      case_type: 'consulta_inicial',
      objective: 'Classificar problema, partes envolvidas, valores e documentos.',
      required_fields: %w[tipo_problema parte_contraria valor_estimado documentos],
      escalation_rules: {
        urgent_terms: %w[liminar prazo audiencia intimacao bloqueio],
        handoff_when: 'houver liminar, audiencia, intimacao ou bloqueio'
      },
      instructions: 'Organize os fatos em ordem cronologica e pergunte quais documentos comprovam cada ponto.'
    }
  ].freeze

  def initialize(account, assistant: nil)
    @account = account
    @assistant = assistant
  end

  def perform
    DEFAULT_PLAYBOOKS.map do |attributes|
      account.captain_playbooks.find_or_create_by!(
        name: attributes[:name],
        legal_area: attributes[:legal_area]
      ) do |playbook|
        playbook.assign_attributes(attributes.merge(assistant: assistant, active: true))
      end
    end
  end

  private

  attr_reader :account, :assistant
end
