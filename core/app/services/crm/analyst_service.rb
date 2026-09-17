class Crm::AnalystService
  HOT_LEAD_SCORE = 75

  def initialize(account:, question:, period_days: 30)
    @account = account
    @question = question.to_s.strip
    @period_days = period_days.to_i.positive? ? period_days.to_i : 30
  end

  def perform
    intent = detect_intent
    payload = send("answer_#{intent}")

    {
      question: @question,
      intent: intent,
      answer: payload[:answer],
      metrics: payload[:metrics],
      links: payload[:links] || [],
      generated_at: Time.current.iso8601
    }
  end

  private

  def detect_intent
    normalized = normalize(@question)

    return :hot_leads_without_owner if normalized.match?(/quente|sem responsavel|owner/)

    # Fase 2: no modo universal a pergunta casa qualquer categoria dos packs
    # (por valor, label transliterado ou keyword); fora dele, mantém o
    # intent legado de INSS/previdenciário que a conta em produção usa hoje.
    category_intent = universal? ? :category_leads : :inss_leads
    return category_intent if category_matched?(normalized)

    legacy_intent(normalized) || :overview
  end

  def category_matched?(normalized)
    universal? ? matched_category(normalized).present? : normalized.match?(/inss|previdenci/)
  end

  def legacy_intent(normalized)
    return :source_lists if normalized.match?(/lista|planilha|importad|origem/)
    return :waiting_documents if normalized.match?(/document/)
    return :owner_conversion if normalized.match?(/responsavel|converte|ganho|cliente/)
    return :campaigns if normalized.match?(/campanha|disparo|broadcast/)

    nil
  end

  def answer_overview
    metrics = Crm::MetricsService.new(@account).overview(period_days: @period_days)
    {
      answer: "Nos ultimos #{@period_days} dias o CRM tem #{metrics[:total_deals]} oportunidades, #{metrics[:open_deals]} abertas, #{metrics[:won_deals]} ganhas e taxa de ganho de #{metrics[:win_rate]}%.",
      metrics: metrics
    }
  end

  def answer_hot_leads_without_owner
    scope = @account.crm_deals.open_deals.where(owner_id: nil).where('score_total >= ?', HOT_LEAD_SCORE)
    {
      answer: "Encontrei #{scope.count} lead(s) quente(s) sem responsavel principal no CRM.",
      metrics: {
        total: scope.count,
        min_score: HOT_LEAD_SCORE,
        sample: deal_sample(scope)
      },
      links: [{ label: 'Abrir CRM', route: 'crm', query: { score_min: HOT_LEAD_SCORE, owner: 'none' } }]
    }
  end

  # Universal: responde "leads de <categoria>" para qualquer categoria dos
  # packs instalados — mesmo shape de resposta do intent legado.
  def answer_category_leads
    category = @matched_category
    term = category[:value]
    since = @period_days.days.ago

    contacts = @account.contacts.where('contacts.created_at >= ?', since)
    contacts = contacts.where(relationship_status: 'lead') if Contact.column_names.include?('relationship_status')
    contacts = contacts.where(
      "LOWER(contacts.additional_attributes ->> 'legal_area') LIKE ? OR LOWER(contacts.additional_attributes ->> 'source_list') LIKE ?",
      "%#{term}%", "%#{term}%"
    )

    deals = @account.crm_deals.where('crm_deals.created_at >= ?', since)
    deals = deals.where(
      'LOWER(COALESCE(category, legal_area)) = ? OR LOWER(source) LIKE ?',
      term, "%#{term}%"
    )

    {
      answer: "Nos ultimos #{@period_days} dias encontrei #{contacts.count} contato(s) lead de #{category[:label]} e #{deals.count} oportunidade(s) de #{category[:label]} no funil.",
      metrics: {
        contacts: contacts.count,
        deals: deals.count,
        period_days: @period_days,
        sample_deals: deal_sample(deals)
      }
    }
  end

  def answer_inss_leads
    since = @period_days.days.ago
    contacts = @account.contacts.where('contacts.created_at >= ?', since)
    contacts = contacts.where(relationship_status: 'lead') if Contact.column_names.include?('relationship_status')
    contacts = contacts.where(
      "LOWER(contacts.additional_attributes ->> 'legal_area') LIKE ? OR LOWER(contacts.additional_attributes ->> 'source_list') LIKE ?",
      '%inss%', '%inss%'
    )

    deals = @account.crm_deals.where('crm_deals.created_at >= ?', since)
    deals = deals.where("LOWER(legal_area) LIKE ? OR LOWER(source) LIKE ?", '%inss%', '%inss%')

    {
      answer: "Nos ultimos #{@period_days} dias encontrei #{contacts.count} contato(s) lead de INSS/previdenciario e #{deals.count} oportunidade(s) de INSS no funil.",
      metrics: {
        contacts: contacts.count,
        deals: deals.count,
        period_days: @period_days,
        sample_deals: deal_sample(deals)
      }
    }
  end

  def answer_source_lists
    rows = @account.contacts
                   .where("contacts.additional_attributes ->> 'source_list' IS NOT NULL")
                   .group("contacts.additional_attributes ->> 'source_list'")
                   .order(Arel.sql('COUNT(*) DESC'))
                   .limit(10)
                   .count

    top = rows.map { |name, count| { name: name, contacts: count } }
    leader = top.first
    answer = if leader
               "A maior lista importada e #{leader[:name]}, com #{leader[:contacts]} contato(s)."
             else
               'Ainda nao encontrei contatos com lista de origem preenchida.'
             end

    { answer: answer, metrics: { lists: top } }
  end

  def answer_waiting_documents
    scope = @account.crm_deals.open_deals
                    .where(documents_status: %w[pending waiting_document requested])
                    .where('crm_deals.updated_at <= ?', 3.days.ago)

    {
      answer: "Encontrei #{scope.count} oportunidade(s) aguardando documento ha mais de 3 dias.",
      metrics: {
        total: scope.count,
        sample: deal_sample(scope)
      }
    }
  end

  def answer_owner_conversion
    won_by_owner = @account.crm_deals.where(status: 'won').where.not(owner_id: nil).group(:owner_id).count
    open_by_owner = @account.crm_deals.where.not(owner_id: nil).group(:owner_id).count
    users = User.where(id: won_by_owner.keys | open_by_owner.keys).index_by(&:id)

    rows = open_by_owner.map do |owner_id, total|
      won = won_by_owner[owner_id].to_i
      {
        owner_id: owner_id,
        owner_name: users[owner_id]&.available_name || "Responsavel ##{owner_id}",
        total: total,
        won: won,
        win_rate: total.positive? ? ((won.to_f / total) * 100).round(1) : 0
      }
    end.sort_by { |row| -row[:win_rate] }

    best = rows.first
    answer = if best
               "#{best[:owner_name]} tem a melhor taxa de conversao atual: #{best[:win_rate]}% (#{best[:won]}/#{best[:total]})."
             else
               'Ainda nao ha oportunidades com responsavel suficiente para calcular conversao.'
             end

    { answer: answer, metrics: { owners: rows } }
  end

  def answer_campaigns
    campaigns = @account.campaigns.order(created_at: :desc).limit(10).map do |campaign|
      stats = (campaign.scoring_config || {})['delivery_stats'] || {}
      {
        id: campaign.id,
        title: campaign.title,
        status: campaign.status,
        sent: stats['sent'].to_i,
        skipped: stats['skipped'].to_i,
        failed: stats['failed'].to_i,
        total: stats['total'].to_i,
        processed_at: stats['processed_at']
      }
    end

    total_sent = campaigns.sum { |campaign| campaign[:sent] }
    total_failed = campaigns.sum { |campaign| campaign[:failed] }

    {
      answer: "Nas campanhas recentes, o Core registrou #{total_sent} envio(s) e #{total_failed} falha(s). Entrega/leitura/resposta dependem de webhook do provedor e ficam para a proxima camada de tracking.",
      metrics: { campaigns: campaigns, sent: total_sent, failed: total_failed }
    }
  end

  def normalize(text)
    I18n.transliterate(text.to_s).downcase
  end

  def universal?
    @account.feature_enabled?('crm_universal')
  end

  # Casa a pergunta com uma categoria dos packs (valor, label transliterado
  # ou keyword declarada no YAML). Memoriza o resultado para a resposta.
  def matched_category(normalized_question)
    @matched_category = Crm::PackOptions.installed_packs(@account)
                                        .flat_map(&:categories)
                                        .find do |option|
      needles = [option[:value], option[:label], *Array(option[:keywords])].compact
      needles.any? { |needle| normalized_question.include?(normalize(needle)) }
    end
  end

  def deal_sample(scope)
    scope.order(updated_at: :desc).limit(5).map do |deal|
      {
        id: deal.id,
        title: deal.title,
        contact: deal.contact&.name,
        stage: deal.crm_pipeline_stage&.name,
        score: deal.score_total,
        legal_area: deal.legal_area,
        updated_at: deal.updated_at&.iso8601
      }
    end
  end
end
