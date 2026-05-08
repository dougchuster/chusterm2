module Crm
  class DocumentLabelSync
    RECEIVED_DOCUMENTS = {
      'rg' => ['doc.rg_recebido', 'doc.rg_pendente'],
      'cpf' => ['doc.cpf_recebido', 'doc.cpf_pendente'],
      'cnh' => ['doc.cnh_recebido', nil],
      'ctps' => ['doc.ctps_recebido', 'doc.ctps_pendente'],
      'cnis' => ['doc.cnis_recebido', 'doc.cnis_pendente'],
      'comprovante_residencia' => ['doc.comprovante_recebido', nil],
      'procuracao' => ['doc.procuracao_recebido', nil],
      'contrato' => ['doc.contrato_recebido', nil],
      'termo_rescisao' => ['doc.termo_rescisao_recebido', nil],
      'extrato' => ['doc.extrato_recebido', nil],
      'peticao' => ['doc.peticao_recebida', nil],
      'decisao' => ['doc.decisao_recebida', nil]
    }.freeze

    DOCUMENT_LABEL_COLOR = '#16a34a'.freeze
    ILLEGIBLE_LABEL = 'doc.documento_ilegivel'.freeze
    GENERIC_RECEIVED_LABEL = 'doc.documento_recebido'.freeze

    def initialize(attachment)
      @attachment = attachment
      @message = attachment.message
      @conversation = @message&.conversation
      @contact = @conversation&.contact
      @account = @message&.account
    end

    def perform
      return if @attachment.blank? || @message.blank? || @conversation.blank? || @account.blank?
      return unless @attachment.image? || @attachment.file?

      received_slug, pending_slug = received_document_slugs
      received_slug ||= GENERIC_RECEIVED_LABEL if generic_document_received?
      received_slug ||= ILLEGIBLE_LABEL if illegible_document?
      return if received_slug.blank?

      added_to_conversation = sync_record(@conversation, received_slug, pending_slug)
      added_to_contact = sync_record(@contact, received_slug, pending_slug) if @contact

      log_changes(received_slug, pending_slug, added_to_conversation, added_to_contact)
    end

    private

    def meta
      @meta ||= (@attachment.meta || {}).with_indifferent_access
    end

    def document_guess
      meta[:document_guess].to_s.strip.downcase
    end

    def ocr_text
      meta[:ocr_text].to_s.strip
    end

    def image_description
      meta[:image_description].to_s.strip
    end

    def received_document_slugs
      RECEIVED_DOCUMENTS[document_guess] || [nil, nil]
    end

    def generic_document_received?
      return false if document_guess.blank?
      return false if document_guess == 'outro' && ocr_text.blank?

      true
    end

    def illegible_document?
      return false if ocr_text.present? || document_guess.present?

      image_description.match?(/\b(documento|identidade|cpf|rg|cnis|ctps|carteira|comprovante|procura|contrato|rescis|extrato)\b/i)
    end

    def sync_record(record, received_slug, pending_slug)
      return false if record.blank?

      received_label = label_for_slug(received_slug)
      pending_label_title = label_title_for_slug(pending_slug) if pending_slug.present?
      current_titles = record.label_list.to_a
      next_titles = current_titles.dup
      next_titles -= [pending_label_title] if pending_label_title.present?
      next_titles << received_label.title
      next_titles.uniq!
      return false if current_titles.sort == next_titles.sort

      record.update!(label_list: next_titles)
      true
    end

    def label_title_for_slug(slug)
      @account.labels.find_by(slug: slug)&.title || slug.tr('.', '_')
    end

    def label_for_slug(slug)
      @account.labels.find_by(slug: slug) ||
        @account.labels.find_by(title: slug.tr('.', '_')) ||
        @account.labels.create!(
          title: slug.tr('.', '_'),
          slug: slug,
          category: 'document',
          scope: 'both',
          color: slug == ILLEGIBLE_LABEL ? '#dc2626' : DOCUMENT_LABEL_COLOR,
          is_system: true,
          show_on_sidebar: false
        )
    end

    def log_changes(received_slug, pending_slug, added_to_conversation, added_to_contact)
      return unless added_to_conversation || added_to_contact

      Crm::AuditLogger.log(
        account: @account,
        actor: nil,
        action: 'crm_document_labels_synced',
        target: @conversation,
        payload: {
          attachment_id: @attachment.id,
          document_guess: document_guess,
          received_label: received_slug,
          pending_label_removed: pending_slug,
          conversation_updated: added_to_conversation,
          contact_updated: added_to_contact
        }
      )
    end
  end
end
