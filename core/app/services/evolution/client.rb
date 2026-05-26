# frozen_string_literal: true

module Evolution
  class Client
    DEFAULT_TIMEOUT = 10
    RETRYABLE_STATUSES = [429, 502, 503, 504].freeze

    def initialize(configuration:, timeout: DEFAULT_TIMEOUT)
      @configuration = configuration
      @timeout = timeout
    end

    def health
      get('/', timeout: 3)
    end

    def fetch_instances
      parsed = get('/instance/fetchInstances')
      normalize_instances_response(parsed)
    end

    def create_instance(instance_name:)
      post('/instance/create', {
        instanceName: instance_name,
        integration: 'WHATSAPP-BAILEYS',
        qrcode: true,
        rejectCall: false,
        groupsIgnore: true,
        alwaysOnline: false,
        readMessages: false,
        readStatus: false,
        syncFullHistory: true
      }, timeout: 15)
    end

    def set_settings(instance_name:, reject_call:, groups_ignore:, always_online:, read_messages:, read_status:, sync_full_history:)
      payload = {
        reject_call: reject_call,
        msg_call: 'Não podemos atender chamadas por este canal. Envie uma mensagem por escrito, por favor.',
        groups_ignore: groups_ignore,
        always_online: always_online,
        read_messages: read_messages,
        read_status: read_status,
        sync_full_history: sync_full_history
      }

      post("/settings/set/#{escape(instance_name)}", payload, timeout: 15)
    rescue Evolution::ApiError => e
      raise unless [400, 422].include?(e.status)

      post("/settings/set/#{escape(instance_name)}", payload.deep_transform_keys { |key| key.to_s.camelize(:lower) }, timeout: 15)
    end

    def set_webhook(instance_name:, url:, headers:, events:)
      post("/webhook/set/#{escape(instance_name)}", webhook_payload(url: url, headers: headers, events: events), timeout: 15)
    rescue Evolution::ApiError => e
      raise unless [400, 404, 405, 422].include?(e.status)

      post("/webhook/set/#{escape(instance_name)}", legacy_webhook_payload(url: url, headers: headers, events: events), timeout: 15)
    end

    def find_webhook(instance_name:)
      get("/webhook/find/#{escape(instance_name)}")
    end

    def connect(instance_name:)
      get("/instance/connect/#{escape(instance_name)}", timeout: 15)
    end

    def connection_state(instance_name:)
      parsed = get("/instance/connectionState/#{escape(instance_name)}")
      return 'unknown' unless parsed.is_a?(Hash)

      safe_dig(parsed, 'instance', 'state') ||
        safe_dig(parsed, 'instance', 'status') ||
        parsed['state'] ||
        parsed['status'] ||
        'unknown'
    end

    def logout(instance_name:)
      delete("/instance/logout/#{escape(instance_name)}", timeout: 15, ignore_not_found: true)
    end

    def restart(instance_name:)
      # Evolution deployments differ between POST and PUT for restart. Try POST first.
      post("/instance/restart/#{escape(instance_name)}", {}, timeout: 15)
    rescue Evolution::ApiError => e
      raise unless e.status == 404 || e.status == 405

      put("/instance/restart/#{escape(instance_name)}", {}, timeout: 15)
    end

    def delete_instance(instance_name:)
      delete("/instance/delete/#{escape(instance_name)}", timeout: 15, ignore_not_found: true)
    end

    def send_text(instance_name:, number:, text:)
      post("/message/sendText/#{escape(instance_name)}", {
        number: number,
        text: text
      }, timeout: 20)
    end

    def send_media(instance_name:, number:, mediatype:, media:, caption:, file_name:)
      post("/message/sendMedia/#{escape(instance_name)}", {
        number: number,
        mediatype: mediatype,
        media: media,
        caption: caption,
        fileName: file_name
      }, timeout: 45)
    end

    def fetch_profile_picture_url(instance_name:, number:)
      post("/chat/fetchProfilePictureUrl/#{escape(instance_name)}", {
        number: number.to_s.delete_prefix('+')
      }, timeout: 15)
    end

    def get_base64_from_media_message(instance_name:, message:, convert_to_mp4: false)
      post("/chat/getBase64FromMediaMessage/#{escape(instance_name)}", {
        message: message,
        convertToMp4: convert_to_mp4
      }, timeout: 45)
    end

    def find_messages(instance_name:, remote_jid:, limit: 50)
      post("/chat/findMessages/#{escape(instance_name)}", {
        where: {
          key: {
            remoteJid: remote_jid
          }
        },
        take: limit,
        limit: limit,
        orderBy: {
          messageTimestamp: 'desc'
        }
      }, timeout: 30)
    end

    def find_chats(instance_name:, limit: 50)
      post("/chat/findChats/#{escape(instance_name)}", {
        where: {},
        take: limit,
        skip: 0,
        orderBy: {
          updatedAt: 'desc'
        }
      }, timeout: 30)
    end

    def find_contacts(instance_name:, where: {}, limit: 500, skip: 0)
      post("/chat/findContacts/#{escape(instance_name)}", {
        where: where,
        take: limit,
        limit: limit,
        skip: skip,
        orderBy: {
          updatedAt: 'desc'
        }
      }, timeout: 30)
    end

    def normalize_instances_response(parsed)
      raw_list =
        case parsed
        when Array then parsed
        when Hash
          parsed['instances'] || parsed['data'] || Array(parsed['value'])
        else
          []
        end

      Array(raw_list).filter_map do |raw|
        next unless raw.is_a?(Hash)

        name = raw['name'] ||
               raw['instanceName'] ||
               safe_dig(raw, 'instance', 'instanceName') ||
               safe_dig(raw, 'instance', 'name')
        next if name.blank?

        phone_number = first_real_phone(raw)

        {
          name: name,
          connection_status: raw['connectionStatus'] || raw['status'] ||
            safe_dig(raw, 'instance', 'status') || safe_dig(raw, 'instance', 'state'),
          owner_jid: raw['ownerJid'] || raw['owner'] || safe_dig(raw, 'instance', 'ownerJid'),
          phone_number: phone_number,
          profile_name: raw['profileName'] || safe_dig(raw, 'profile', 'name'),
          profile_picture_url: raw['profilePicUrl'] || raw['profilePictureUrl'] || safe_dig(raw, 'profile', 'pictureUrl')
        }.compact
      end
    end

    private

    def get(path, timeout: @timeout)
      request(:get, path, timeout: timeout)
    end

    def post(path, body, timeout: @timeout)
      request(:post, path, body: body, timeout: timeout)
    end

    def put(path, body, timeout: @timeout)
      request(:put, path, body: body, timeout: timeout)
    end

    def delete(path, timeout: @timeout, ignore_not_found: false)
      request(:delete, path, timeout: timeout, ignore_not_found: ignore_not_found)
    end

    def request(method, path, body: nil, timeout: @timeout, ignore_not_found: false)
      response = with_retries do
        HTTParty.public_send(
          method,
          "#{base_url}#{path}",
          headers: headers,
          timeout: timeout,
          body: body.nil? ? nil : body.to_json
        )
      end

      return {} if ignore_not_found && response.code.to_i == 404
      return parsed_response(response) if response.success?

      raise Evolution::ApiError.new(error_message(response), status: response.code.to_i, body: response.body)
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
      raise Evolution::TimeoutError, e.message
    end

    def with_retries
      attempts = 0

      begin
        attempts += 1
        response = yield
        return response unless RETRYABLE_STATUSES.include?(response.code.to_i) && attempts < 4

        sleep(0.25 * attempts)
      end while attempts < 4

      response
    end

    def parsed_response(response)
      parsed = response.parsed_response
      parsed = JSON.parse(parsed) if parsed.is_a?(String) && parsed.strip.start_with?('{', '[')
      parsed.presence || {}
    rescue StandardError
      {}
    end

    def error_message(response)
      parsed = parsed_response(response)
      return parsed if parsed.is_a?(String)
      return response.body.to_s.truncate(300) unless parsed.is_a?(Hash)

      message = parsed['message'] || safe_dig(parsed, 'error', 'message') || safe_dig(parsed, 'response', 'message')
      message = message.flatten.join(', ') if message.is_a?(Array)
      message.presence || response.body.to_s.truncate(300)
    end

    def base_url
      @configuration.base_url.to_s.chomp('/')
    end

    def headers
      {
        'apikey' => @configuration.global_api_key.to_s,
        'Content-Type' => 'application/json'
      }
    end

    def webhook_payload(url:, headers:, events:)
      {
        enabled: true,
        url: url,
        headers: headers,
        webhookByEvents: false,
        webhook_by_events: false,
        webhookBase64: true,
        webhook_base64: true,
        base64: true,
        events: events
      }
    end

    def legacy_webhook_payload(url:, headers:, events:)
      {
        webhook: {
          enabled: true,
          url: url,
          headers: headers,
          webhookByEvents: false,
          webhook_by_events: false,
          webhookBase64: true,
          webhook_base64: true,
          base64: true,
          events: events
        }
      }
    end

    def escape(value)
      ERB::Util.url_encode(value.to_s)
    end

    def safe_dig(value, *keys)
      keys.reduce(value) do |memo, key|
        return nil unless memo.respond_to?(:[])

        memo = memo[key]
        return nil if memo.is_a?(String) && key != keys.last

        memo
      end
    end

    def normalize_phone(value)
      text = value.to_s
      return nil if text.blank? || text.include?('@lid')

      phone = text.split('@').first
      return nil if phone.blank?

      digits = phone.gsub(/\D/, '')
      return nil if lid_like_number?(digits)

      digits.present? ? "+#{digits}" : nil
    end

    def first_real_phone(raw)
      [
        raw['ownerJid'],
        safe_dig(raw, 'instance', 'ownerJid'),
        raw['wuid'],
        safe_dig(raw, 'instance', 'wuid'),
        raw['number'],
        safe_dig(raw, 'instance', 'number'),
        raw['owner'],
        safe_dig(raw, 'instance', 'owner')
      ].filter_map { |candidate| normalize_phone(candidate) }.first
    end

    def lid_like_number?(digits)
      digits.start_with?('1000') && digits.length >= 12
    end
  end
end
