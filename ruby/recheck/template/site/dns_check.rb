require "resolv"

class EmailRecordsCheck < Recheck::Check::V1
  def query
    # domains you send email from
    []
  end

  def check_mx_records(domain)
    mx_records = Resolv::DNS.open do |dns|
      dns.getresources(domain, Resolv::DNS::Resource::IN::MX)
    end
    !mx_records.empty?
  end

  def check_soa_record(domain)
    soa_record = Resolv::DNS.open do |dns|
      dns.getresource(domain, Resolv::DNS::Resource::IN::SOA)
    end
    !soa_record.nil?
  rescue Resolv::ResolvError
    false
  end

  def check_spf_record(domain)
    txt_records = Resolv::DNS.open do |dns|
      dns.getresources(domain, Resolv::DNS::Resource::IN::TXT)
    end
    txt_records.any? { |record| record.strings.first.start_with?("v=spf1") }
  end
end
