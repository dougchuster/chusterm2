require 'rails_helper'

RSpec.describe CrmDocumentIntakeListener do
  include ActiveJob::TestHelper

  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) { create(:message, account: account, inbox: inbox, conversation: conversation, message_type: 'incoming') }
  let(:event) { Events::Base.new('message_created', Time.current, message: message) }

  before { clear_enqueued_jobs }

  def attach_file(file_type: :file)
    attachment = message.attachments.new(account_id: account.id, file_type: file_type)
    attachment.file.attach(io: Rails.root.join('spec/assets/sample.pdf').open, filename: 'sample.pdf',
                           content_type: 'application/pdf')
    attachment.save!
    attachment
  end

  it 'enfileira a ingestão de cada anexo com o módulo ligado' do
    crm_documents_enable!(account)
    attachment = attach_file

    expect { listener.message_created(event) }
      .to have_enqueued_job(Crm::Documents::IngestAttachmentJob).with(attachment.id)
  end

  it 'não enfileira nada com o módulo desligado' do
    attach_file

    expect { listener.message_created(event) }.not_to have_enqueued_job(Crm::Documents::IngestAttachmentJob)
  end

  it 'não enfileira mensagem sem anexo' do
    crm_documents_enable!(account)

    expect { listener.message_created(event) }.not_to have_enqueued_job(Crm::Documents::IngestAttachmentJob)
  end
end
