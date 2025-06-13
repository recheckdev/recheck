require "whois"
require "whois-parser"

class WhoisCheck < Recheck::Check::V1
  def query
    whois = Whois::Client.new
    # array of your domains
    [].map do |domain|
      whois.lookup(domain).parser
    end
  end

  def check_not_expiring_soon(parser)
    expiration_date = parser.expires_on
    expiration_date > (Time.now + 180 * 24 * 60 * 60) # 180 days
  end

  def check_registrar_lock(domain)
    domain_status.any? { |status| status.downcase.include?("clienttransferprohibited") }
  end

  def check_nameservers(domain)
    parser.nameservers.length >= 2
  end
end
