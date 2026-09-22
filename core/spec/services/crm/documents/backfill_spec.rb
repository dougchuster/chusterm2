require 'rails_helper'

# PROJETO-COFRE-DOCUMENTOS.md §7.4 — traz para o cofre os anexos antigos.
# Idempotente: pode rodar quantas vezes precisar.
RSpec.describe Crm::Documents::Backfill do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  before { crm_documents_enable!(account) }

  def attachment_at(time, asset: 'sample.pdf', type: 'application/pdf', file_type: :file)
    message = create(:message, account: account, inbox: inbox, conversation: conversation, created_at: time)
    attachment = message.attachments.new(account_id: account.id, file_type: file_type)
    attachment.file.attach(io: StringIO.new("#{Rails.root.join('spec/assets', asset).read}#{SecureRandom.hex(4)}"),
                           filename: asset, content_type: type)
    attachment.save!
    attachment.update!(created_at: time)
    attachment
  end

  it 'captura os anexos existentes e relata o que fez' do
    attachment_at(2.days.ago)
    attachment_at(1.day.ago)
    attachment_at(1.day.ago, asset: 'sample.ogg', type: 'audio/ogg', file_type: :audio)

    report = described_class.new(account: account).call

    expect(report.to_h).to include(scanned: 2, created: 2, skipped: 0)
    expect(CrmDocument.where(contact: contact).count).to eq(2)
  end

  it 'respeita a data inicial' do
    attachment_at(10.days.ago)
    recent = attachment_at(1.day.ago)

    described_class.new(account: account, since: 3.days.ago.to_date).call

    expect(CrmDocument.pluck(:source_attachment_id)).to eq([recent.id])
  end

  it 'pode rodar de novo sem duplicar' do
    attachment_at(1.day.ago)
    described_class.new(account: account).call

    report = described_class.new(account: account).call

    expect(report.to_h).to include(created: 0, skipped: 1)
    expect(CrmDocument.count).to eq(1)
  end
end
