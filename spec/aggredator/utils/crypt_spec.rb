require 'tempfile'
require 'openssl'

RSpec.describe Aggredator::Crypt do
  def generate_cert(cn, cacert: nil, cakey: nil)
    key = OpenSSL::PKey::RSA.new 2048
    pub_key = key.public_key
    subject = "/CN=#{cn}"

    cert = OpenSSL::X509::Certificate.new
    cert.subject = OpenSSL::X509::Name.parse subject
    cert.not_before = Time.now
    cert.not_after = Time.now + 1.day
    cert.public_key = pub_key

    cert.issuer = (cacert || cert).subject

    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = cacert || cert

    cert.sign cakey || key, OpenSSL::Digest::SHA1.new
    [key, cert]
  end

  around(:each) do |example|
    ca_key, ca_cert = generate_cert('CA')
    key, cert = generate_cert('TEST', cacert: ca_cert, cakey: ca_key)

    @cacert = Tempfile.new
    @cacert.write ca_cert.to_pem
    @cacert.flush

    @key = Tempfile.new
    @key.write key.to_pem
    @key.flush

    @cert = Tempfile.new
    @cert.write cert.to_pem
    @cert.flush

    example.run
  end

  context 'full check' do
    before(:each) do
      expect(described_class).to receive(:valid_key_cert?).and_call_original
      expect(described_class).to receive(:valid_cert_sign?).and_call_original
    end

    it 'success' do
      errors = described_class.full_check(@key.path, @cert.path, @cacert.path)
      expect(errors).to be_nil
    end

    it 'errors' do
      key_file, cert_file = generate_cert('invalid').map do |obj|
        f = Tempfile.new
        f.write obj.to_pem
        f.flush
        f
      end
      errors = described_class.full_check(key_file.path, cert_file.path, @cacert.path)
      expect(errors).to be_a Array
      expect(errors.size).to eq 1
    end
  end
end
