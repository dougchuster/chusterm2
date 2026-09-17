# Dispatcher do sync de marketing por provider. Mantido fino: a logica de
# cada provider vive em Marketing::Sync::<Provider>Service.
class Marketing::Sync::AccountService
  SERVICES = {
    'meta_ads' => Marketing::Sync::MetaService,
    'google_ads' => Marketing::Sync::GoogleAdsService,
    'ga4' => Marketing::Sync::Ga4Service
  }.freeze

  def initialize(connection:, date_from: nil, date_to: nil)
    @connection = connection
    @date_from = date_from
    @date_to = date_to
  end

  def perform!
    service_class.new(connection: @connection, date_from: @date_from, date_to: @date_to).perform!
  end

  private

  def service_class
    SERVICES.fetch(@connection.provider) do
      raise "Unknown marketing provider: #{@connection.provider}"
    end
  end
end
