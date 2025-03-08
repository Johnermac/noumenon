require 'faraday'

class DirectoryScannerService
  def initialize(domain, verbose: false, stealth: false)
    @domain = domain
    @verbose = verbose
    @stealth = stealth
  end

  def check_directory(word)
    url = "http://#{@domain}/#{word}/"
    response = fetch_url(url)

    if response&.status.to_i == 200 || response&.status.to_s.start_with?("3")
      puts "->  #{word} ".light_green if @verbose
      save_directory(word)
    end
  end

  private

  def fetch_url(url)
    connection = Faraday.new(url) do |conn|
      conn.options.timeout = 5
      conn.proxy = ProxyService.get_proxy if @stealth # Implement ProxyService
      conn.adapter Faraday.default_adapter
    end

    connection.get
  rescue Faraday::Error
    nil
  end

  def save_directory(word)
    # Implement logic to save found directories
  end
end
