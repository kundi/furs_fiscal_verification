require 'furs_fiscal_verification/version'
require 'uri'
require 'net/http'
require 'net/https'
require 'digest'
require 'jwt'
require 'openssl'

ENV['FFV_ENV'] ||= 'production'

class Furs
  API_VERSION = 'v1'
  FURS_TEST_ENDPOINT = 'https://blagajne-test.fu.gov.si:9002'
  FURS_PRODUCTION_ENDPOINT = 'https://blagajne.fu.gov.si:9003'

  REGISTER_BUSINESS_UNIT_PATH = "/#{API_VERSION}/cash_registers/invoices/register"
  INVOICE_ISSUE_PATH = "/#{API_VERSION}/cash_registers/invoices"

  LOW_TAX_RATE = 9.5
  HIGH_TAX_RATE = 22

  def initialize(cert_path:, cert_password:, production: false)
    @cert = OpenSSL::PKCS12.new(File.read(cert_path), cert_password)
    @endpoint = production ? FURS_PRODUCTION_ENDPOINT : FURS_TEST_ENDPOINT
  end

  def furs_accessible?(msg: 'ping')
    data = {'EchoRequest' => msg}
    response = _post(data: data, path: "/v1/cash_registers/echo", sign: false)
    JSON.parse(response.body)["EchoResponse"] == msg
  end

  def calculate_zoi(tax_number:, issued_date:, invoice_number:, business_premise_id:, electronic_device_id:,
                    invoice_amount:)
    content = "#{tax_number}#{issued_date.strftime('%d-%m-%Y %H:%M:%S')}#{invoice_number}#{business_premise_id}
    #{electronic_device_id}#{invoice_amount}"

    Digest::MD5.hexdigest(_sign(content))
  end

  def report_invoice(zoi:,
                     tax_number:,
                     issued_date:,
                     invoice_number:,
                     business_premise_id:,
                     electronic_device_id:,
                     invoice_amount:,
                     low_tax_rate_base: nil,
                     low_tax_rate_amount: nil,
                     high_tax_rate_base: nil,
                     high_tax_rate_amount: nil,
                     other_taxes_amount: nil,
                     exempt_vat_taxable_amount: nil,
                     reverse_vat_taxable_amount: nil,
                     non_taxable_amount: nil,
                     special_tax_rules_amount: nil,
                     payment_amount: nil,
                     customer_vat_number: nil,
                     returns_amount: nil,
                     operator_tax_number: nil,
                     foreign_operator: nil,
                     subsequent_submit: nil,
                     reference_invoice_number: nil,
                     reference_invoice_business_premise_id: nil,
                     reference_invoice_electronic_device_id: nil,
                     reference_invoice_issued_date: nil,
                     numbering_structure: 'B',
                     special_notes: '')

    data = {}
    data['InvoiceRequest'] = {
        'Header' => {
            'MessageID' => SecureRandom.uuid,
            'DateTime' => DateTime.now.strftime("%Y-%m-%dT%H:%M:%SZ")
        },
        'Invoice' => {
            'TaxNumber' => tax_number.to_i,
            'IssueDateTime' => issued_date.strftime("%Y-%m-%dT%H:%M:%SZ"),
            'NumberingStructure' => numbering_structure,
            'InvoiceIdentifier' => {
                'BusinessPremiseID' => business_premise_id,
                'ElectronicDeviceID' => electronic_device_id,
                'InvoiceNumber' => invoice_number
            },
            'InvoiceAmount' => invoice_amount,
            'PaymentAmount' => if payment_amount
                                 payment_amount
                               else
                                 invoice_amount
                               end,
            'ProtectedID' => zoi,
            'TaxesPerSeller' => []
        }
    }

    tax_spec = {}
    if low_tax_rate_base || high_tax_rate_base
      tax_spec['VAT'] = _build_tax_specification(
          low_tax_rate_base,
          low_tax_rate_amount,
          high_tax_rate_base,
          high_tax_rate_amount)
    end

    tax_spec['NontaxableAmount'] = non_taxable_amount if non_taxable_amount

    if reverse_vat_taxable_amount
      tax_spec['ReverseVATTaxableAmount'] = reverse_vat_taxable_amount
    end

    if exempt_vat_taxable_amount
      tax_spec['ExemptVATTaxableAmount'] = exempt_vat_taxable_amount
    end

    tax_spec['OtherTaxesAmount'] = other_taxes_amount if other_taxes_amount

    data['InvoiceRequest']['Invoice']['TaxesPerSeller'] << tax_spec

    if customer_vat_number
      data['InvoiceRequest']['Invoice']['CustomerVATNumber'] = customer_vat_number
    end

    if returns_amount
      data['InvoiceRequest']['Invoice']['ReturnsAmount'] = returns_amount
    end

    if operator_tax_number
      data['InvoiceRequest']['Invoice']['OperatorTaxNumber'] = operator_tax_number
    end

    if foreign_operator
      data['InvoiceRequest']['Invoice']['ForeignOperator'] = true
    end

    if subsequent_submit
      data['InvoiceRequest']['Invoice']['SubsequentSubmit'] = true
    end

    if reference_invoice_number
      reference_invoice = [{
                               'ReferenceInvoiceIdentifier' => {
                                   'BusinessPremiseID' => reference_invoice_business_premise_id,
                                   'ElectronicDeviceID' => reference_invoice_electronic_device_id,
                                   'InvoiceNumber' => reference_invoice_number
                               },
                               'ReferenceInvoiceIssueDateTime' => reference_invoice_issued_date.strftime("%Y-%m-%dT%H:%M:%SZ")
                           }]

      data['InvoiceRequest']['Invoice']['ReferenceInvoice'] = reference_invoice
    end

    _post(path: INVOICE_ISSUE_PATH, data: data)
  end

  def _build_tax_specification(low_tax_rate_base,
                               low_tax_rate_amount,
                               high_tax_rate_base,
                               high_tax_rate_amount)
    low_tax_spec = {
        'TaxRate' => LOW_TAX_RATE,
        'TaxableAmount' => low_tax_rate_base,
        'TaxAmount' => low_tax_rate_amount
    }

    high_tax_spec = {
        'TaxRate' => HIGH_TAX_RATE,
        'TaxableAmount' => high_tax_rate_base,
        'TaxAmount' => high_tax_rate_amount
    }

    [low_tax_spec, high_tax_spec].select { |spec| !spec['TaxableAmount'].nil? }
  end

  def register_immovable_business_premise(tax_number:,
                                          premise_id:,
                                          real_estate_cadastral_number:,
                                          real_estate_building_number:,
                                          real_estate_building_section_number:,
                                          street:,
                                          house_number:,
                                          house_number_additional:,
                                          community:,
                                          city:,
                                          postal_code:,
                                          validity_date:,
                                          software_supplier_tax_number: nil,
                                          foreign_software_supplier_name: nil,
                                          special_notes: 'No notes')

    data = {
        "BusinessPremiseRequest" => {
            "Header" => {
                "MessageID" => SecureRandom.uuid,
                "DateTime" => DateTime.now.strftime("%Y-%m-%dT%H:%M:%SZ")
            },
            "BusinessPremise" => {
                "TaxNumber" => tax_number.to_i,
                "BusinessPremiseID" => premise_id,
                "BPIdentifier" => {
                    "RealEstateBP" => {
                        "PropertyID" => {
                            "CadastralNumber" => real_estate_cadastral_number.to_i,
                            "BuildingNumber" => real_estate_building_number.to_i,
                            "BuildingSectionNumber" => real_estate_building_section_number.to_i
                        },
                        "Address" => {
                            "Street" => street,
                            "HouseNumber" => house_number.to_s,
                            "HouseNumberAdditional" => house_number_additional,
                            "Community" => community,
                            "City" => city,
                            "PostalCode" => postal_code.to_s
                        }
                    }
                },
                "ValidityDate" => validity_date.strftime("%Y-%m-%d"),
                "SoftwareSupplier" => [
                    {
                        "NameForeign" => foreign_software_supplier_name
                    }
                ],
                "SpecialNotes" => special_notes
            }
        }
    }

    _post(path: REGISTER_BUSINESS_UNIT_PATH, data: data)
  end

  def prepare_printable(tax_number, zoi, issued_date)
    formatted_date = issued_date.strftime('%y%m%d%H%M%S')
    zoi_base_10 = zoi.hex.to_s(10).rjust(39, '0')
    data = "#{zoi_base_10}#{tax_number}#{formatted_date}"
    control = data.chars.map(&:to_i).inject(:+) % 10
    "#{data}#{control}"
  end

  Error = Class.new(StandardError) do
    attr_accessor :response
  end

  ServerError = Class.new(Furs::Error)
  VATError = Class.new(Furs::Error)

  private

  def _post(path:, data:, sign: true)
    if sign
      data = {
          'token' => _jwt_sign(header: _jws_header, payload: data)
      }
    end

    url = "#{@endpoint}#{path}"
    uri = URI(url)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    https.open_timeout = 60
    https.read_timeout = 60
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE # should probably verify...
    https.cert = @cert.certificate
    https.key = @cert.key
    req = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json; charset=UTF-8')
    _handle_response https.request(req, data.to_json)
  end

  def _jws_header
    {
        'alg' => 'RS256',
        'subject_name' => @cert.certificate.subject.to_a.map { |subject| "#{subject[0]}=#{subject[1]}" }.join(","),
        'issuer_name' => @cert.certificate.issuer.to_a.map { |subject| "#{subject[0]}=#{subject[1]}" }.join(","),
        'serial' => @cert.certificate.serial.to_i
    }
  end

  def _jwt_sign(header:, payload:)
    private_key = @cert.key
    JWT.encode(payload, private_key, 'RS256', header)
  end

  def _sign(content)
    digest = OpenSSL::Digest::SHA256.new
    @cert.key.sign(digest, content)
  end

  def _handle_response(response)
    if (message = response.instance_variable_get("@message")) =~ /VAT/i
      fail Furs::VATError.new(message).tap { |e| e.response = response }
    end

    response
  end
end
