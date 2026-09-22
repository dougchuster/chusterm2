# Grava um envio do formulário público (PROJETO-COFRE-DOCUMENTOS.md §8.7):
#
# 1. valida as respostas (FormAnswers), a ciência LGPD e os arquivos;
# 2. identifica o contato — pelo link personalizado (envio verificado) ou por
#    telefone/e-mail (ContactResolver; envio "não verificado");
# 3. cria o envio com protocolo AAAA-NNNNNN;
# 4. guarda cada arquivo na Triagem do contato com o tipo SUGERIDO pelo item
#    do formulário — a equipe confirma com um Enter na Caixa de Triagem.
#
# Arquivo recusado (tipo não aceito, grande demais) não derruba o envio: volta
# na lista `rejected` para a tela avisar o cliente.
class Crm::Documents::FormSubmitter
  MAX_FILES = 20
  MAX_FILE_BYTES = 25.megabytes
  MAX_TOTAL_BYTES = 100.megabytes
  # Envios não verificados para o mesmo contato numa janela: quem digita o
  # telefone de outra pessoa não consegue inundar a Triagem dela.
  MAX_UNVERIFIED_PER_CONTACT = 5
  UNVERIFIED_WINDOW = 24.hours
  FLOODED_MESSAGE = 'Recebemos muitos envios para este contato nas últimas horas. Tente de novo amanhã ou fale com a equipe.'.freeze
  PROTOCOL_DIGITS = 6
  PROTOCOL_ATTEMPTS = 3

  class Flooded < StandardError; end

  Result = Struct.new(:submission, :errors, :rejected, keyword_init: true) do
    def success?
      errors.blank?
    end
  end

  # rubocop:disable Metrics/ParameterLists
  def initialize(form:, answers:, files:, consent:, link: nil, ip: nil, user_agent: nil)
    @form = form
    @account = form.account
    @link = link
    @answers = Crm::Documents::FormAnswers.new(form, answers, skip_mapped: link.present?)
    @files = files.to_h.transform_keys(&:to_s).transform_values { |list| Array(list).compact }
    @consent = ActiveModel::Type::Boolean.new.cast(consent) == true
    @ip = ip
    @user_agent = user_agent.to_s.first(255)
  end
  # rubocop:enable Metrics/ParameterLists

  def call
    errors = validate
    return Result.new(errors: errors, rejected: []) if errors.any?

    submission, rejected = persist
    audit(submission)
    Result.new(submission: submission, errors: {}, rejected: rejected)
  rescue Flooded
    Result.new(errors: { 'form' => FLOODED_MESSAGE }, rejected: [])
  end

  private

  def validate
    errors = answer_errors
    errors['consent'] = 'Confirme a autorização para o uso dos dados.' unless @consent
    errors.merge(file_errors)
  end

  def answer_errors
    @answers.valid? ? {} : @answers.errors
  end

  def file_errors
    errors = items.each_with_object({}) do |item, found|
      message = item_error(item, @files[item['key']] || [])
      found[item['key']] = message if message
    end
    batch = batch_error
    batch ? errors.merge('files' => batch) : errors
  end

  def batch_error
    return 'Arquivo enviado para um item que não existe.' if (@files.keys - items.pluck('key')).any?
    return 'Os arquivos passam de 100 MB no total. Envie em partes.' if total_bytes > MAX_TOTAL_BYTES

    "Envie no máximo #{MAX_FILES} arquivos." if @files.values.sum(&:size) > MAX_FILES
  end

  def total_bytes
    @files.values.flatten.sum { |file| file.try(:size).to_i }
  end

  def item_error(item, sent)
    return 'Envie só um arquivo aqui.' if !item['multiple'] && sent.size > 1

    'Envie este documento.' if item['required'] && sent.empty? && visible?(item)
  end

  def persist
    CrmDocumentSubmission.transaction do
      resolved = resolve_contact
      raise Flooded if flooded?(resolved.contact)

      submission = create_submission(resolved)
      rejected = store_files(submission)
      submission.update!(documents_count: submission.documents.count)
      bump_counters
      [submission, rejected]
    end
  end

  def resolve_contact
    return Crm::Documents::ContactResolver::Result.new(contact: @link.contact, match_status: 'link') if @link

    Crm::Documents::ContactResolver.new(
      account: @account, name: @answers.mapped('contact_name'),
      phone: @answers.mapped('contact_phone'), email: @answers.mapped('contact_email')
    ).call
  end

  def flooded?(contact)
    return false if @link

    CrmDocumentSubmission.where(account_id: @account.id, contact_id: contact.id, verified: false)
                         .where(created_at: UNVERIFIED_WINDOW.ago..).count >= MAX_UNVERIFIED_PER_CONTACT
  end

  def create_submission(resolved)
    attempts = 0
    begin
      attempts += 1
      CrmDocumentSubmission.transaction(requires_new: true) do
        CrmDocumentSubmission.create!(
          account: @account, crm_document_form: @form, crm_document_form_link: @link, contact: resolved.contact,
          crm_deal: @link&.crm_deal, protocol: next_protocol, answers: @answers.values,
          match_status: resolved.match_status, verified: @link.present?, consent_at: Time.current,
          ip: @ip, user_agent: @user_agent
        )
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      retry if attempts < PROTOCOL_ATTEMPTS
      raise
    end
  end

  def next_protocol
    year = Time.current.year
    last = CrmDocumentSubmission.where(account_id: @account.id).where('protocol LIKE ?', "#{year}-%")
                                .maximum(:protocol)
    sequence = last.to_s.split('-').last.to_i + 1
    "#{year}-#{sequence.to_s.rjust(PROTOCOL_DIGITS, '0')}"
  end

  def store_files(submission)
    items.each_with_object([]) do |item, rejected|
      next unless visible?(item)

      (@files[item['key']] || []).each do |file|
        store_file(submission, item, file)
      rescue Crm::Documents::Uploader::InvalidFile => e
        rejected << { item: item['key'], filename: file.try(:original_filename).to_s, error: e.message }
      end
    end
  end

  def store_file(submission, item, file)
    Crm::Documents::Uploader.new(
      contact: submission.contact, io: file, filename: file.try(:original_filename) || item['label'],
      source: 'portal', deal: submission.crm_deal, max_bytes: MAX_FILE_BYTES,
      provenance: { uploaded_by_contact: true, received_at: Time.current, meta: file_meta(submission, item) }
    ).call
  end

  def file_meta(submission, item)
    { 'submission_id' => submission.id, 'protocol' => submission.protocol, 'form_item' => item['key'],
      'caption' => item['label'], 'suggested_doc_type' => item['doc_type'].presence,
      'unverified' => !submission.verified }.compact
  end

  # Contadores atômicos (UPDATE ... + 1): dois envios simultâneos não se perdem.
  # rubocop:disable Rails/SkipsModelValidations
  def bump_counters
    CrmDocumentForm.where(id: @form.id).update_all('submissions_count = submissions_count + 1')
    CrmDocumentFormLink.where(id: @link.id).update_all('submissions_count = submissions_count + 1') if @link
  end
  # rubocop:enable Rails/SkipsModelValidations

  def items
    @items ||= Array(@form.document_items).map { |item| item.to_h.stringify_keys }
  end

  def visible?(item)
    @answers.visible?(item['show_if'])
  end

  def audit(submission)
    Crm::AuditLogger.log(account: @account, actor: :contact, action: 'document_form_submitted', target: submission,
                         payload: { form_id: @form.id, protocol: submission.protocol, verified: submission.verified },
                         ip: @ip, user_agent: @user_agent)
  end
end
