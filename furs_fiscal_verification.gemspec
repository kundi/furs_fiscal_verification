# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'furs_fiscal_verification/version'

Gem::Specification.new do |spec|
  spec.name = 'furs_fiscal_verification'
  spec.version = FursFiscalVerification::VERSION
  spec.authors = ['Matic Jurglic', 'Oto Brglez']
  spec.email = ['matic@jurglic.si']

  spec.summary = 'Fiscal verification of invoices (davčno potrjevanje računov)'
  spec.homepage = 'http://codeandtechno.com'
  spec.license = 'MIT'

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir = 'bin'
  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'jwt', '~> 1.5'

  spec.add_development_dependency 'bundler', '~> 1.11'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'pry'

end
