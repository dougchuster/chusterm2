class Api::V1::Accounts::ContactCategoriesController < Api::V1::Accounts::BaseController
  CATEGORY_ALIASES = {
    'area_juridica' => 'area',
    'legal_area' => 'area',
    'localidade' => 'location',
    'location' => 'location',
    'campanha' => 'campaign',
    'campaign' => 'campaign',
    'origem' => 'origin',
    'origin' => 'origin',
    'status_comercial' => 'status',
    'status' => 'status',
    'restricao' => 'restriction',
    'restriction' => 'restriction',
    'livre' => 'custom',
    'custom' => 'custom'
  }.freeze

  before_action :fetch_category, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    categories = policy_scope(Current.account.labels).contact_categories
    render json: { payload: categories.map { |category| serialize_category(category) } }
  end

  def show
    render json: serialize_category(@category)
  end

  def create
    category = build_or_find_category(category_params)
    category.assign_attributes(category_attributes(category_params, category))
    category.save!

    render json: serialize_category(category)
  end

  def update
    @category.assign_attributes(category_attributes(category_params, @category))
    @category.save!

    render json: serialize_category(@category)
  end

  def destroy
    remove_category_from_labelable_records(@category.title)
    @category.destroy!
    head :ok
  end

  def bulk_assign
    contacts = bulk_contacts
    categories = bulk_categories(create_missing: true)
    titles = categories.map(&:title)

    contacts.find_each do |contact|
      contact.update!(label_list: (contact.label_list + titles).uniq)
    end

    render json: bulk_payload(contacts, categories)
  end

  def bulk_remove
    contacts = bulk_contacts
    categories = bulk_categories(create_missing: false)
    titles = categories.map(&:title)

    contacts.find_each do |contact|
      contact.update!(label_list: contact.label_list - titles)
    end

    render json: bulk_payload(contacts, categories)
  end

  private

  def check_authorization
    authorize(Label)
  end

  def fetch_category
    @category = Current.account.labels.contact_categories.find(params[:id])
  end

  def category_params
    params.fetch(:category, params).permit(:title, :name, :description, :color, :category, :kind, :scope, :slug, :show_on_sidebar)
  end

  def bulk_params
    params.permit(:category, :kind, :color, contact_ids: [], category_ids: [], categories: [], titles: [])
  end

  def build_or_find_category(permitted)
    title = normalized_title(permitted[:title].presence || permitted[:name])
    category = normalized_category(permitted[:category].presence || permitted[:kind])
    slug = permitted[:slug].presence || "#{category}.#{title}"

    Current.account.labels.find_by(slug: slug) ||
      Current.account.labels.find_by(title: title) ||
      Current.account.labels.build(title: title)
  end

  def category_attributes(permitted, label)
    title = normalized_title(permitted[:title].presence || permitted[:name].presence || label.title)
    category = normalized_category(permitted[:category].presence || permitted[:kind].presence || label.category)

    {
      title: title,
      description: permitted[:description],
      color: permitted[:color].presence || label.color,
      category: category,
      scope: permitted[:scope].presence || 'contact',
      slug: permitted[:slug].presence || "#{category}.#{title}",
      show_on_sidebar: ActiveModel::Type::Boolean.new.cast(permitted.fetch(:show_on_sidebar, false)),
      is_system: false
    }.compact
  end

  def bulk_contacts
    ids = Array(bulk_params[:contact_ids]).compact_blank
    return Current.account.contacts.none if ids.blank?

    Current.account.contacts.where(id: ids)
  end

  def bulk_categories(create_missing:)
    ids = Array(bulk_params[:category_ids]).compact_blank
    titles = Array(bulk_params[:categories]).presence || Array(bulk_params[:titles])
    categories = Current.account.labels.contact_categories.where(id: ids).to_a

    titles.to_a.compact_blank.each do |title|
      categories << find_or_create_bulk_category(title, create_missing: create_missing)
    end

    categories.compact.uniq
  end

  def find_or_create_bulk_category(title, create_missing:)
    normalized = normalized_title(title)
    category = Current.account.labels.contact_categories.find_by(title: normalized)
    return category if category.present? || !create_missing

    kind = normalized_category(bulk_params[:category].presence || bulk_params[:kind])
    Current.account.labels.create!(
      title: normalized,
      category: kind,
      color: bulk_params[:color].presence || '#2563eb',
      scope: 'contact',
      slug: "#{kind}.#{normalized}",
      show_on_sidebar: false,
      is_system: false
    )
  end

  def remove_category_from_labelable_records(title)
    Current.account.contacts.tagged_with(title).find_each do |contact|
      contact.update!(label_list: contact.label_list - [title])
    end

    Current.account.conversations.tagged_with(title).find_each do |conversation|
      conversation.update!(label_list: conversation.label_list - [title])
    end
  end

  def normalized_category(value)
    normalized = CATEGORY_ALIASES.fetch(value.to_s.strip.downcase, value.to_s.strip.downcase)
    Label::CONTACT_CATEGORY_TYPES.include?(normalized) ? normalized : 'custom'
  end

  def normalized_title(value)
    value.to_s.strip.parameterize(separator: '_').presence || 'categoria'
  end

  def serialize_category(category)
    {
      id: category.id,
      title: category.title,
      display_title: category.display_title,
      description: category.description,
      color: category.color,
      category: category.category,
      kind: category.category,
      slug: category.slug,
      scope: category.scope,
      show_on_sidebar: category.show_on_sidebar,
      contacts_count: Current.account.contacts.tagged_with(category.title).count
    }
  end

  def bulk_payload(contacts, categories)
    {
      payload: {
        contacts_count: contacts.count,
        categories: categories.map { |category| serialize_category(category) }
      }
    }
  end
end
