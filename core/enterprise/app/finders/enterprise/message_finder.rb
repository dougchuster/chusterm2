module Enterprise::MessageFinder
  def conversation_messages
    scope = super
    return scope unless Message.reflect_on_association(:call)

    scope.includes(call: [:contact, { inbox: :channel }])
  end
end
