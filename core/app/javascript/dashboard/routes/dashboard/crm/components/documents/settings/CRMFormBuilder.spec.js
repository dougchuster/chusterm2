import { flushPromises, mount } from '@vue/test-utils';

import CrmDocumentsAPI from 'dashboard/api/crmDocuments';
import CRMFormBuilder from './CRMFormBuilder.vue';

vi.mock('dashboard/api/crmDocuments', () => ({
  default: { updateForm: vi.fn(), archiveForm: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const form = {
  id: 9,
  name: 'Envio de documentos',
  active: true,
  public_url: 'https://crm.example/f/abc',
  settings: { intro: 'Olá' },
  fields: [
    {
      key: 'nome',
      label: 'Nome completo',
      type: 'text',
      required: true,
      maps_to: 'contact_name',
    },
    {
      key: 'whatsapp',
      label: 'WhatsApp',
      type: 'phone',
      required: true,
      maps_to: 'contact_phone',
    },
  ],
  document_items: [{ key: 'identidade', label: 'Documento com foto' }],
};

const mountBuilder = () =>
  mount(CRMFormBuilder, {
    props: { form, documentTypes: [{ slug: 'cpf', label: 'CPF' }] },
  });

const clickButton = (wrapper, text) =>
  wrapper
    .findAll('button')
    .find(button => button.text().includes(text))
    .trigger('click');

describe('CRMFormBuilder', () => {
  beforeEach(() => vi.clearAllMocks());

  it('mostra o link público, as perguntas e os documentos pedidos', () => {
    const wrapper = mountBuilder();

    expect(wrapper.text()).toContain('https://crm.example/f/abc');
    expect(wrapper.text()).toContain('Perguntas (2)');
    expect(wrapper.text()).toContain('Documento com foto');
  });

  it('acrescenta pergunta e documento e salva tudo de uma vez', async () => {
    CrmDocumentsAPI.updateForm.mockResolvedValue({ data: form });
    const wrapper = mountBuilder();

    await clickButton(wrapper, 'Pergunta');
    await clickButton(wrapper, 'Documento');
    await clickButton(wrapper, 'Salvar formulário');
    await flushPromises();

    const [id, payload] = CrmDocumentsAPI.updateForm.mock.calls[0];
    expect(id).toBe(9);
    expect(payload.fields.map(field => field.key)).toEqual([
      'nome',
      'whatsapp',
      'nova_pergunta',
    ]);
    expect(payload.document_items.map(item => item.key)).toEqual([
      'identidade',
      'novo_documento',
    ]);
    expect(wrapper.emitted('saved')).toHaveLength(1);
  });

  it('mostra a mensagem do servidor quando a estrutura é recusada', async () => {
    CrmDocumentsAPI.updateForm.mockRejectedValue({
      response: {
        data: { error: 'o formulário precisa de um campo ligado ao nome' },
      },
    });
    const wrapper = mountBuilder();

    await clickButton(wrapper, 'Pergunta');
    await clickButton(wrapper, 'Salvar formulário');
    await flushPromises();

    expect(wrapper.text()).toContain(
      'o formulário precisa de um campo ligado ao nome'
    );
  });

  it('avisa antes de salvar quando some a identificação do contato', async () => {
    const wrapper = mountBuilder();

    const removeButtons = wrapper.findAll('button[aria-label^="Remover"]');
    await removeButtons[1].trigger('click');

    expect(wrapper.text()).toContain(
      'Ligue um campo ao telefone ou ao e-mail do contato.'
    );
  });
});
