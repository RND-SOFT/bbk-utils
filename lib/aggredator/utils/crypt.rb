require 'openssl'

module Aggredator

  class Crypt

    def self.full_check(key_path, cert_path, *cacert_chain)
      errors = []
      errors << 'Invalid key and cert pair' unless valid_key_cert?(key_path, cert_path)
      errors << 'Invalid cert and cacert pair' unless valid_cert_sign?(cert_path, *cacert_chain.compact)
      if errors.empty?
        nil
      else
        errors
      end
    end

    def self.valid_key_cert?(key_path, cert_path)
      raise "Key file #{key_path} not exists" unless File.exist? key_path
      raise "Cert file #{cert_path} not exists" unless File.exist? cert_path

      key = OpenSSL::PKey::RSA.new(File.read(key_path))
      cert = OpenSSL::X509::Certificate.new(File.read(cert_path))
      cert.check_private_key(key)
    end

    def self.valid_cert_sign?(cert_path, *ca_certs_paths)
      raise "Cert file #{cert_path} not exists" unless File.exist? cert_path
      raise "Not all files in ca chain #{ca_certs_paths} exists" unless ca_certs_paths.all? {|pth| File.exist? pth }

      store = ca_certs_paths.reduce(OpenSSL::X509::Store.new) {|st, c| st.add_file(c) }
      cert = OpenSSL::X509::Certificate.new File.read(cert_path)
      store.verify(cert)
    end

  end

end
