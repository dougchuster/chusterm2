# Deriva o nome físico de um documento pelos padrões da conta
# (PROJETO-COFRE-DOCUMENTOS.md §5.3; editáveis em Configurações → Documentos):
#
#   classificado  '{data} — {tipo} — {descricao}'          2026-09-22 — RG — Frente e verso.pdf
#   na triagem    '{data_hora} — {origem} — {nome_original}' 2026-09-22 14h37 — WhatsApp — IMG-0012.jpg
#
# A extensão vem do tipo real do conteúdo (Active Storage identifica pelos
# magic bytes), não do nome que o cliente mandou.
class Crm::Documents::Naming::FileNamer
  MAX_BASE_LENGTH = 120
  OTHER_TYPE = 'outro'.freeze
  CLIENT_CODE_DIGITS = 6
  SOURCE_LABELS = {
    'whatsapp' => 'WhatsApp', 'email' => 'E-mail', 'instagram' => 'Instagram', 'chat' => 'Conversa',
    'upload' => 'Envio da equipe', 'portal' => 'Formulário', 'system' => 'Sistema'
  }.freeze

  def self.call(document)
    new(document).call
  end

  def initialize(document)
    @document = document
    @settings = Crm::Documents::Defaults.settings_for(document.account)
  end

  def call
    "#{base_name}.#{Crm::Documents::Naming::Extension.for(@document.content_type, @document.original_filename)}"
  end

  private

  def base_name
    name = if @document.doc_type.blank?
             render('triage_file', triage_values, %w[nome_original cliente])
           else
             render('file', classified_values, %w[descricao nome_original cliente])
           end
    name.presence || 'Documento'
  end

  def render(kind, values, shrink)
    Crm::Documents::Naming::Template.render(@settings.naming_template(kind), values, max: MAX_BASE_LENGTH,
                                                                                     shrink: shrink)
  end

  def classified_values
    other = @document.doc_type == OTHER_TYPE
    common_values.merge(
      'tipo' => other ? (@document.description.presence || 'Documento') : type_label,
      'descricao' => other ? '' : @document.description.to_s
    )
  end

  def triage_values
    common_values.merge(
      'data_hora' => received_at.strftime('%Y-%m-%d %Hh%M'),
      'origem' => SOURCE_LABELS.fetch(@document.source.to_s, 'Arquivo')
    )
  end

  def common_values
    {
      'data' => (@document.document_date || received_at.to_date).strftime('%Y-%m-%d'),
      'cliente' => @document.contact&.name.to_s,
      'codigo' => @document.contact_id.to_s.rjust(CLIENT_CODE_DIGITS, '0'),
      'nome_original' => File.basename(@document.original_filename.to_s, '.*').presence || 'arquivo'
    }
  end

  def received_at
    @document.received_at.in_time_zone(@document.time_zone)
  end

  def type_label
    @document.document_type&.label || @document.doc_type
  end
end
