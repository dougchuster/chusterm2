# TODO: Wrap the schema lib under ai-agents
# So we can extend it as Agents::Schema
class Captain::ResponseSchema < RubyLLM::Schema
  string :response, description: 'The message to send to the user'
  string :reasoning, description: 'Brief operational justification for audit and routing; never private chain-of-thought'
end
