require 'rails_helper'

# Revisão de um envio pela equipe (fila "Novos envios").
RSpec.describe Crm::Documents::SubmissionReviewer do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:form) { account.crm_document_forms.create!(Crm::Documents::FormTemplates.default_attributes(account)) }
  let(:submission) do
    Crm::Documents::FormSubmitter.new(
      form: form, answers: { nome: 'Lia Costa', whatsapp: '11 91234-5678' }, consent: '1',
      files: { identidade: [crm_pdf_upload('rg.pdf')] }
    ).call.submission
  end

  before { crm_documents_enable!(account, preset: 'geral') }

  it 'verifica o envio e tira a marca de não verificado dos arquivos' do
    described_class.new(submission, user: user).call(verified: true)

    expect(submission.reload.verified).to be(true)
    expect(submission.documents.first.meta).not_to have_key('unverified')
  end

  # Revisão de segurança (22/09): concluir sem verificar dava por bom um
  # arquivo que qualquer pessoa pode ter mandado com o telefone de outra.
  it 'não conclui envio não verificado' do
    expect { described_class.new(submission, user: user).call(review_status: 'done') }
      .to raise_error(ArgumentError, /Confirme/)
    expect(submission.reload.review_status).to eq('new')
  end

  it 'conclui depois de verificar, na mesma chamada ou em outra' do
    described_class.new(submission, user: user).call(verified: true, review_status: 'done')

    expect(submission.reload).to have_attributes(review_status: 'done', reviewed_by_user_id: user.id)
  end

  it 'marca spam sem verificar e arquiva os arquivos' do
    described_class.new(submission, user: user).call(review_status: 'spam')

    expect(submission.reload.review_status).to eq('spam')
    expect(submission.documents.active).to be_empty
  end
end
