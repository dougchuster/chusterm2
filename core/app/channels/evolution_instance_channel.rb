# frozen_string_literal: true

class EvolutionInstanceChannel < ApplicationCable::Channel
  def subscribed
    user = User.find_by!(pubsub_token: params[:pubsub_token], id: params[:user_id])
    account = user.accounts.find(params[:account_id])
    instance = account.evolution_instances.find(params[:evolution_instance_id])
    stream_from "evolution_instance_#{instance.id}"
  end
end
