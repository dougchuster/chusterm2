module Crm
  class LegalLabelSync
    AREA_SLUGS = {
      'previdenciario' => 'area.previdenciario',
      'trabalhista' => 'area.trabalhista',
      'civel' => 'area.civel',
      'consumidor' => 'area.consumidor',
      'familia' => 'area.familia',
      'imobiliario' => 'area.imobiliario',
      'criminal' => 'area.penal',
      'penal' => 'area.penal',
      'tributario' => 'area.tributario',
      'empresarial' => 'area.empresarial',
      'auxilio_maternidade' => 'area.auxilio_maternidade'
    }.freeze

    DOCUMENT_SLUGS = {
      'CNIS' => 'doc.cnis_pendente',
      'CTPS' => 'doc.ctps_pendente',
      'RG' => 'doc.rg_pendente',
      'CPF' => 'doc.cpf_pendente'
    }.freeze

    CATEGORY_COLORS = {
      'area' => '#2563eb',
      'temperature' => '#f59e0b',
      'relationship' => '#16a34a',
      'status' => '#64748b',
      'document' => '#f97316',
      'risk' => '#dc2626'
    }.freeze

    REPLACEABLE_CATEGORIES = %w[area temperature relationship].freeze

    def initialize(conversation:, triage:, actor: nil)
      @conversation = conversation
      @contact = conversation.contact
      @account = conversation.account
      @triage = triage.with_indifferent_access
      @actor = actor
    end

    def perform
      conversation_changes = sync_record(@conversation, conversation_slugs)
      contact_changes = sync_record(@contact, contact_slugs) if @contact

      log_changes(conversation_changes, contact_changes)
    end

    private

    def conversation_slugs
      [
        area_slug,
        ('status.em_triagem' unless insufficient_triage?),
        document_status_slug,
        risk_slug,
        risk_detail_slug,
        *document_slugs
      ].compact.uniq
    end

    def contact_slugs
      [
        area_slug,
        relationship_slug,
        temperature_slug,
        ('status.sem_responsavel' if @contact&.crm_owner_id.blank?)
      ].compact.uniq
    end

    def area_slug
      AREA_SLUGS[@triage[:legal_area].to_s]
    end

    def relationship_slug
      status = @contact.respond_to?(:crm_relationship_status) ? @contact.crm_relationship_status : @contact.contact_type
      status == 'customer' ? 'rel.cliente' : 'rel.lead'
    end

    def temperature_slug
      return if insufficient_triage?

      case @triage[:urgency_level].to_s
      when 'critica', 'alta'
        'temp.quente'
      when 'media'
        'temp.morno'
      else
        'temp.frio'
      end
    end

    def document_status_slug
      return if insufficient_triage?

      status = @triage[:documents_status].to_s
      return 'status.aguardando_documento' if status.in?(%w[solicitado parcial])

      nil
    end

    def risk_slug
      return 'risk.prazo_urgente' if @triage[:deadline_risk].to_s == 'alto'
      return 'risk.prazo_urgente' if @triage[:urgency_level].to_s.in?(%w[critica alta])

      nil
    end

    def risk_detail_slug
      text = [@triage[:summary], @triage[:next_best_action], @triage[:score_reason]].compact.join(' ')
      return 'risk.audiencia_marcada' if text.match?(/\baudi[eê]ncia\b/i)
      return 'risk.intimacao_recebida' if text.match?(/\bintima[cç][aã]o\b/i)

      nil
    end

    def document_slugs
      documents = Array(@triage[:documents_needed]).join(' ')
      DOCUMENT_SLUGS.filter_map do |needle, slug|
        slug if documents.match?(/\b#{Regexp.escape(needle)}\b/i)
      end
    end

    def insufficient_triage?
      @triage[:data_quality].to_s == 'insufficient'
    end

    def sync_record(record, slugs)
      return [] if record.blank? || slugs.blank?

      labels = slugs.filter_map { |slug| label_for_slug(slug) }
      new_titles = labels.map(&:title)
      replace_titles = @account.labels.where(category: REPLACEABLE_CATEGORIES).pluck(:title)
      current_titles = record.label_list.to_a
      next_titles = (current_titles - replace_titles + new_titles).uniq
      return [] if same_labels?(current_titles, next_titles)

      record.update!(label_list: next_titles)
      next_titles - current_titles
    end

    def same_labels?(current_titles, next_titles)
      current_titles.map(&:to_s).sort == next_titles.map(&:to_s).sort
    end

    def label_for_slug(slug)
      @account.labels.find_by(slug: slug) ||
        @account.labels.find_by(title: slug.tr('.', '_')) ||
        create_label(slug)
    end

    def create_label(slug)
      category = slug.split('.').first
      @account.labels.create!(
        title: slug.tr('.', '_'),
        slug: slug,
        category: category,
        scope: scope_for(category),
        color: CATEGORY_COLORS.fetch(category, '#1f93ff'),
        is_system: true,
        show_on_sidebar: false
      )
    end

    def scope_for(category)
      return 'contact' if category.in?(%w[temperature relationship])

      'both'
    end

    def log_changes(conversation_changes, contact_changes)
      changes = {
        conversation_labels_added: Array(conversation_changes),
        contact_labels_added: Array(contact_changes)
      }
      return if changes.values.all?(&:blank?)

      Crm::AuditLogger.log(
        account: @account,
        actor: @actor,
        action: 'crm_labels_synced',
        target: @conversation,
        payload: changes
      )
    end
  end
end
