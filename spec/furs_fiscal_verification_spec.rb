require 'spec_helper'

RSpec.describe FursFiscalVerification do
  context 'VERSION' do
    it { expect(FursFiscalVerification::VERSION).not_to be_nil }
    it { expect(FursFiscalVerification::VERSION).to be_frozen }
  end

  context 'environment' do
    it { expect(ENV['FFV_ENV']).to eq 'test' }
  end
end
