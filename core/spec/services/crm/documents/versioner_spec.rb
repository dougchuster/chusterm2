require 'rails_helper'

# PROJETO-COFRE-DOCUMENTOS.md §4.3/§5.3 — reenvio do mesmo documento lógico
# vira versão nova; a anterior nunca é apagada: vai para 99 Arquivo como (v1).
RSpec.describe Crm::Documents::Versioner do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }

  before { crm_documents_enable!(account) }

  it 'o reenvio do mesmo tipo na mesma pasta vira v2 e o anterior vai para 99 Arquivo como (v1)' do
    first = crm_document_for(contact, doc_type: 'comprovante_residencia')
    second = crm_document_for(contact, doc_type: 'comprovante_residencia')

    first.reload
    expect(first).to have_attributes(status: 'obsolete', name_locked: true)
    expect(first.crm_document_folder.slot).to eq('arquivo')
    expect(first.file_name).to end_with('(v1).pdf')
    expect(second.reload).to have_attributes(versions_count: 2)
    expect(second.meta['previous_version_id']).to eq(first.id)
    expect(second.crm_document_folder.slot).to eq('comprovantes')
  end

  it 'classificar da triagem também gera versão' do
    first = crm_document_for(contact, doc_type: 'rg')
    pending_doc = crm_document_for(contact)

    Crm::Documents::DocumentUpdater.new(document: pending_doc, attributes: { doc_type: 'rg' }).call

    expect(first.reload.status).to eq('obsolete')
    expect(pending_doc.reload.versions_count).to eq(2)
  end

  it 'a terceira versão continua a numeração' do
    crm_document_for(contact, doc_type: 'cpf')
    crm_document_for(contact, doc_type: 'cpf')
    third = crm_document_for(contact, doc_type: 'cpf')

    expect(third.reload.versions_count).to eq(3)
    expect(CrmDocument.where(contact: contact, status: 'obsolete').pluck(:file_name))
      .to contain_exactly(end_with('(v1).pdf'), end_with('(v2).pdf'))
  end

  it 'não versiona o tipo "outro" nem tipos diferentes' do
    first = crm_document_for(contact, doc_type: 'outro', description: 'Declaração A')
    crm_document_for(contact, doc_type: 'outro', description: 'Declaração B')
    rg = crm_document_for(contact, doc_type: 'rg')
    crm_document_for(contact, doc_type: 'cpf')

    expect(first.reload.status).to eq('received')
    expect(rg.reload.status).to eq('received')
  end

  it 'registra na auditoria' do
    first = crm_document_for(contact, doc_type: 'cnh')
    crm_document_for(contact, doc_type: 'cnh')

    expect(CrmAuditEvent.for_target('CrmDocument', first.id).pluck(:action)).to include('document_superseded')
  end
end
