class CampaignMailer < ApplicationMailer
  include ActionView::Helpers::TextHelper

  def marketing_email
    @account = params[:account]
    @campaign = params[:campaign]
    @contact = params[:contact]

    mail(
      to: @contact.email,
      from: from_address,
      subject: @campaign.title
    ) do |format|
      format.html { render html: html_body.html_safe }
      format.text { render plain: text_body }
    end
  end

  private

  def from_address
    channel = @campaign.inbox.channel
    return channel.email if channel.respond_to?(:email) && channel.email.present?

    ENV.fetch('MAILER_SENDER_EMAIL', 'ChusteRM <accounts@ChusteRM.com>')
  end

  def rendered_message
    @rendered_message ||= Liquid::CampaignTemplateService.new(
      campaign: @campaign,
      contact: @contact
    ).call(@campaign.message)
  end

  def html_body
    <<~HTML
      <div style="font-family:Inter,Arial,sans-serif;line-height:1.55;color:#0f172a">
        #{simple_format(sanitize(rendered_message))}
        <hr style="border:0;border-top:1px solid #e2e8f0;margin:24px 0" />
        <p style="font-size:12px;color:#64748b">
          Enviado por #{@account.name}. Responda este email para falar com a equipe.
        </p>
      </div>
    HTML
  end

  def text_body
    strip_tags(rendered_message)
  end
end
