class Captain::Tools::FaqLookupTool < Captain::Tools::BasePublicTool
  LOOKUP_PERFORMED_STATE_KEY = :captain_faq_lookup_performed
  REPEATED_LOOKUP_MESSAGE = 'FAQ lookup already performed in this run. Use the previous result and answer the user now.'.freeze

  description 'Search FAQ responses using semantic similarity to find relevant answers'
  param :query, type: 'string', desc: 'The question or topic to search for in the FAQ database'

  def perform(tool_context, query:)
    return REPEATED_LOOKUP_MESSAGE if tool_context.state[LOOKUP_PERFORMED_STATE_KEY]

    tool_context.state[LOOKUP_PERFORMED_STATE_KEY] = true
    log_tool_usage('searching', { query: query })

    # Use existing vector search on approved responses
    responses = @assistant.responses.approved.search(query).to_a

    if responses.empty?
      log_tool_usage('no_results', { query: query })
      "No relevant FAQs found for: #{query}"
    else
      log_tool_usage('found_results', { query: query, count: responses.size })
      format_responses(responses)
    end
  end

  private

  def format_responses(responses)
    responses.map { |response| format_response(response) }.join
  end

  def format_response(response)
    formatted_response = "
        Question: #{response.question}
        Answer: #{response.answer}
        "
    if should_show_source?(response)
      formatted_response += "
          Source: #{response.documentable.external_link}
          "
    end

    formatted_response
  end

  def should_show_source?(response)
    return false if response.documentable.blank?
    return false unless response.documentable.try(:external_link)

    # Don't show source if it's a PDF placeholder
    external_link = response.documentable.external_link
    !external_link.start_with?('PDF:')
  end
end
