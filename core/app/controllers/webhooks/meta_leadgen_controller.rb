# Webhook Leadgen da Meta: GET valida o endpoint (hub.challenge) e POST
# enfileira um job por leadgen_id — nunca processa inline.
# Docs: https://developers.facebook.com/docs/marketing-api/guides/lead-ads
class Webhooks::MetaLeadgenController < ActionController::API
  def verify
    if params['hub.mode'] == 'subscribe' && params['hub.verify_token'] == verify_token
      render plain: params['hub.challenge']
    else
      head :unauthorized
    end
  end

  def process_payload
    leadgen_ids.each do |leadgen_id|
      Marketing::LeadgenIngestJob.perform_later(leadgen_id, payload_context)
    end
    head :ok
  end

  private

  def leadgen_ids
    Array(params['entry']).flat_map do |entry|
      Array(entry['changes']).filter_map do |change|
        change.dig('value', 'leadgen_id') if change['field'] == 'leadgen'
      end
    end.uniq
  end

  def payload_context
    Array(params['entry']).each_with_object({}) do |entry, ctx|
      Array(entry['changes']).each do |change|
        value = change['value'] || {}
        ctx[value['leadgen_id']] = {
          'page_id' => value['page_id'] || entry['id'],
          'form_id' => value['form_id'],
          'adgroup_id' => value['adgroup_id'],
          'ad_id' => value['ad_id'],
          'campaign_id' => value['campaign_id']
        }.compact
      end
    end
  end

  def verify_token
    GlobalConfigService.load('META_WEBHOOK_VERIFY_TOKEN', nil).to_s
  end
end
