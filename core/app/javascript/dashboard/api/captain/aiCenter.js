import ApiClient from '../ApiClient';

// UX-04: Central de IA — endpoint de leitura consolidada (index apenas).
class CaptainAiCenterAPI extends ApiClient {
  constructor() {
    super('captain/ai_center', { accountScoped: true });
  }
}

export default new CaptainAiCenterAPI();
