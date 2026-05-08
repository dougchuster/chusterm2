namespace :crm do
  desc 'Backfill CRM fields and owner from existing contacts. Usage: bin/rails crm:backfill_contacts [ACCOUNT_ID=1] [LIMIT=100]'
  task backfill_contacts: :environment do
    account = Account.find(ENV['ACCOUNT_ID']) if ENV['ACCOUNT_ID'].present?
    limit = ENV['LIMIT'].presence&.to_i

    stats = Crm::ContactBackfillService.new(account: account, limit: limit).perform
    puts stats.to_h.to_json
  end

  desc 'Create demo contact categories and 20 demo contacts. Usage: bin/rails crm:seed_contact_categories_demo ACCOUNT_ID=1'
  task seed_contact_categories_demo: :environment do
    account = Account.find(ENV.fetch('ACCOUNT_ID', Account.first&.id))
    raise 'No account found. Set ACCOUNT_ID=1' if account.blank?

    category_specs = [
      ['DF', 'location', '#2563eb', 'Contatos do Distrito Federal'],
      ['GO', 'location', '#059669', 'Contatos de Goias'],
      ['Previdenciario', 'area', '#7c3aed', 'INSS, BPC, aposentadoria e beneficios'],
      ['Trabalhista', 'area', '#ea580c', 'Demandas trabalhistas'],
      ['Familia', 'area', '#db2777', 'Divorcio, guarda e pensao'],
      ['Re-marketing', 'campaign', '#0891b2', 'Audiencia para reativacao'],
      ['Cliente base', 'status', '#10b981', 'Clientes antigos ou ativos'],
      ['Lead quente', 'status', '#dc2626', 'Prioridade comercial alta'],
      ['WhatsApp ativo', 'origin', '#4f46e5', 'Interacao recente via WhatsApp'],
      ['Nao chamar', 'restriction', '#64748b', 'Excluir de campanhas']
    ]

    labels_by_name = category_specs.each_with_object({}) do |(name, category, color, description), result|
      title = name.parameterize(separator: '_')
      slug = "#{category}.#{title}"
      label = account.labels.find_by(slug: slug) || account.labels.find_by(title: title) || account.labels.build(title: title)
      label.assign_attributes(
        category: category,
        color: color,
        description: description,
        show_on_sidebar: false,
        scope: 'contact',
        slug: slug,
        is_system: false
      )
      label.save!
      result[name] = label
    end

    demo_contacts = [
      ['Douglas Chuster', '+556199135861', 'douglas.demo@chusterm.local', 'customer', %w[DF Previdenciario Re-marketing Cliente\ base]],
      ['Mariana Costa', '+5561981112200', 'mariana.costa@demo.local', 'lead', %w[DF Previdenciario Lead\ quente WhatsApp\ ativo]],
      ['Rafael Almeida', '+5561981112201', 'rafael.almeida@demo.local', 'lead', %w[DF Trabalhista Re-marketing]],
      ['Patricia Gomes', '+5561981112202', 'patricia.gomes@demo.local', 'customer', %w[GO Familia Cliente\ base]],
      ['Bruno Fernandes', '+5561981112203', 'bruno.fernandes@demo.local', 'lead', %w[DF Familia Lead\ quente]],
      ['Renata Lima', '+5561981112204', 'renata.lima@demo.local', 'lead', %w[GO Previdenciario WhatsApp\ ativo]],
      ['Carlos Eduardo', '+5561981112205', 'carlos.eduardo@demo.local', 'customer', %w[DF Trabalhista Cliente\ base Re-marketing]],
      ['Aline Martins', '+5561981112206', 'aline.martins@demo.local', 'lead', %w[DF Previdenciario Re-marketing]],
      ['Joao Pedro', '+5561981112207', 'joao.pedro@demo.local', 'lead', %w[GO Trabalhista Lead\ quente]],
      ['Fernanda Rocha', '+5561981112208', 'fernanda.rocha@demo.local', 'customer', %w[DF Familia Cliente\ base WhatsApp\ ativo]],
      ['Lucas Ribeiro', '+5561981112209', 'lucas.ribeiro@demo.local', 'lead', %w[DF Previdenciario WhatsApp\ ativo]],
      ['Camila Nunes', '+5561981112210', 'camila.nunes@demo.local', 'lead', %w[GO Familia Re-marketing]],
      ['Thiago Moreira', '+5561981112211', 'thiago.moreira@demo.local', 'customer', %w[DF Trabalhista Cliente\ base]],
      ['Beatriz Santos', '+5561981112212', 'beatriz.santos@demo.local', 'lead', %w[DF Previdenciario Lead\ quente Re-marketing]],
      ['Felipe Castro', '+5561981112213', 'felipe.castro@demo.local', 'lead', %w[GO Trabalhista WhatsApp\ ativo]],
      ['Natalia Barbosa', '+5561981112214', 'natalia.barbosa@demo.local', 'customer', %w[DF Familia Cliente\ base]],
      ['Diego Lopes', '+5561981112215', 'diego.lopes@demo.local', 'lead', %w[DF Previdenciario Nao\ chamar]],
      ['Juliana Pires', '+5561981112216', 'juliana.pires@demo.local', 'lead', %w[GO Previdenciario Re-marketing]],
      ['Marcelo Vieira', '+5561981112217', 'marcelo.vieira@demo.local', 'customer', %w[DF Trabalhista Cliente\ base WhatsApp\ ativo]],
      ['Larissa Teixeira', '+5561981112218', 'larissa.teixeira@demo.local', 'lead', %w[DF Familia Lead\ quente Re-marketing]]
    ]

    created = 0
    demo_contacts.each do |name, phone, email, relationship_status, category_names|
      contact = account.contacts.find_or_initialize_by(phone_number: phone)
      contact.email = email
      contact.name = name
      contact.contact_type = relationship_status
      contact.relationship_status = relationship_status if contact.has_attribute?(:relationship_status)
      contact.lifecycle_stage = relationship_status if contact.has_attribute?(:lifecycle_stage)
      contact.label_list = category_names.map { |category_name| labels_by_name.fetch(category_name).title }
      contact.save!
      created += 1
    end

    puts({ account_id: account.id, categories: labels_by_name.size, contacts: created }.to_json)
  end
end
