require 'spec_helper'

RSpec.describe FursFiscalVerification do

  context 'VERSION' do
    it { expect(FursFiscalVerification::VERSION).not_to be_nil }
    it { expect(FursFiscalVerification::VERSION).to be_frozen }
  end

  context 'Certificates magic' do

  end

  context 'basic sign' do
    pending 'basic works / fails test here'
  end
end
