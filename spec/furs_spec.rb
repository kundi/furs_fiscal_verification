require 'spec_helper'

RSpec.describe Furs do
  let(:cert_path) { File.expand_path('../certs/demo_podjetje.p12', __FILE__) }
  let(:cert_password) { 'Geslo123#' }
  let(:production) { ENV['FFV_ENV'] == 'production' }

  context 'basics' do
    subject { described_class.new({
                                      cert_path: cert_path,
                                      cert_password: cert_password,
                                      production: production
                                  }) }

    context '#register_immovable_business_premise' do
      let(:ok_load) {
        {tax_number: 10115609,
         premise_id: 'BP105',
         real_estate_cadastral_number: 112,
         real_estate_building_number: 11,
         real_estate_building_section_number: 1,
         street: 'Trzaska cesta',
         house_number: '24',
         house_number_additional: 'A',
         community: 'Ljubljana',
         city: 'Ljubljana',
         postal_code: '1000',
         validity_date: Date.today - 10,
         software_supplier_tax_number: 24564444,
         foreign_software_supplier_name: 'Neki'}
      }

      let(:fail_load) {
        {tax_number: 222}
      }

      context 'ok' do
        let(:register) { subject.register_immovable_business_premise(ok_load) }
        it { expect(register).to be_kind_of(Net::HTTPOK) }
      end

      context 'fail with arguments' do
        let(:register) { subject.register_immovable_business_premise(fail_load) }
        it { expect { register }.to raise_error(ArgumentError) }
      end

      context 'fail with wrong data' do
        let(:fail_load) { Hash[ok_load.keys.map { |k| [k, nil] }].merge(validity_date: Date.today) }
        let(:register) { subject.register_immovable_business_premise(fail_load) }
        it { expect { register }.to raise_error(Furs::VATError) }
      end
    end
  end

end
