require "openssl"
require "socket"
require "uri"

class TlsChecker < Recheck::Checker::Base
  def query
    # array of domains you host web servers on
    [].map do |domain|
      cert = fetch_certificate(domain)
      {domain: domain, cert: cert}
    end
  end

  def check_not_expiring_soon(record)
    expiration_date = record[:cert].not_after
    days_until_expiration = (expiration_date - Time.now) / (24 * 60 * 60)
    days_until_expiration > 30
  end

  def check_cert_matches_domain(record)
    cert = record[:cert]
    domain = record[:domain]
    cert.subject.to_a.any? { |name, value| name == "CN" && (value == domain || value == "*.#{domain}") } ||
      cert.extensions.any? { |ext| ext.oid == "subjectAltName" && ext.value.include?("DNS:#{domain}") }
  end

  def check_cert_suites_no_old(record)
    ctx = OpenSSL::SSL::SSLContext.new
    ctx.set_params(verify_mode: OpenSSL::SSL::VERIFY_NONE)
    socket = TCPSocket.new(record[:domain], 443)
    ssl = OpenSSL::SSL::SSLSocket.new(socket, ctx)
    ssl.connect
    ciphers = ssl.cipher
    ssl.close
    socket.close

    !["RC4", "MD5", "SHA1"].any? { |weak| ciphers.include?(weak) }
  end

  private

  def fetch_certificate(domain)
    uri = URI::HTTPS.build(host: domain)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.start do |h|
      h.peer_cert
    end
  end
end
