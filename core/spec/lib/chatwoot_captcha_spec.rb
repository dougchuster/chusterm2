require 'rails_helper'

describe ChusteRMCaptcha do
  it 'returns true if HCAPTCHA SERVER KEY is absent' do
    expect(described_class.new('random_key').valid?).to be(true)
  end

  context 'when HCAPTCHA SERVER KEY is present' do
    before do
      allow(GlobalConfigService).to receive(:load)
        .with('HCAPTCHA_SERVER_KEY', '')
        .and_return('hcaptch_server_key')
    end

    it 'returns false if client response is blank' do
      expect(described_class.new('').valid?).to be false
    end

    it 'returns true if client response is valid' do
      captcha_request = double
      allow(HTTParty).to receive(:post).and_return(captcha_request)
      allow(captcha_request).to receive(:success?).and_return(true)
      allow(captcha_request).to receive(:parsed_response).and_return({ 'success' => true })
      expect(described_class.new('valid_response').valid?).to be true
    end
  end
end
