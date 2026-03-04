require "httpx"
require "nokogiri"
require "digest"
require "uri"

class DirectoryPreflightService
  USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:136.0) Gecko/20100101 Firefox/136.0".freeze
  REQUEST_TIMEOUT = { connect_timeout: 5, operation_timeout: 8 }.freeze

  def initialize(site)
    @site = site
    @client = HTTPX.with(timeout: REQUEST_TIMEOUT)
  end

  def call
    home = safe_get(@site)
    baseline = safe_get("#{trimmed_site}/nonexistent_#{rand(100_000..999_999)}")
    robots = safe_get("#{trimmed_site}/robots.txt")
    sitemap = safe_get("#{trimmed_site}/sitemap.xml")

    {
      fingerprint: build_fingerprint(baseline),
      technologies: infer_technologies(home),
      waf_detected: waf_detected?(home, baseline),
      discovered_paths: discovered_paths(robots, sitemap)
    }
  end

  private

  attr_reader :site

  def safe_get(url)
    @client.get(url, headers: { "User-Agent" => USER_AGENT })
  rescue HTTPX::Error, StandardError
    nil
  end

  def build_fingerprint(response)
    return nil unless response.is_a?(HTTPX::Response)

    body = response.body.to_s
    {
      "status" => response.status.to_i,
      "body_size" => body.size,
      "prefix_hash" => Digest::SHA256.hexdigest(body[0, 512].to_s),
      "title" => extract_title(body),
      "text_tokens" => extract_tokens(body)
    }
  end

  def infer_technologies(home)
    return [] unless home.is_a?(HTTPX::Response)

    headers = home.headers.to_h.transform_keys(&:downcase)
    body = home.body.to_s.downcase
    result = []

    result << "wordpress" if body.include?("wp-content") || body.include?("wp-json")
    result << "drupal" if body.include?("drupal-settings-json") || body.include?("sites/default/files")
    result << "joomla" if body.include?("com_content") || body.include?("joomla")
    result << "laravel" if headers["set-cookie"].to_s.downcase.include?("laravel_session")
    result << "rails" if headers["x-powered-by"].to_s.downcase.include?("phusion passenger") || body.include?("csrf-param")
    result << "nginx" if headers["server"].to_s.downcase.include?("nginx")
    result << "apache" if headers["server"].to_s.downcase.include?("apache")

    result.uniq
  end

  def waf_detected?(home, baseline)
    [home, baseline].compact.any? do |response|
      headers = response.headers.to_h.transform_keys(&:downcase)
      header_blob = "#{headers['server']} #{headers['set-cookie']} #{headers['cf-ray']}".downcase
      body = response.body.to_s.downcase
      status = response.status.to_i

      status == 429 ||
        header_blob.include?("cloudflare") ||
        header_blob.include?("akamai") ||
        header_blob.include?("sucuri") ||
        header_blob.include?("incapsula") ||
        body.include?("attention required") ||
        body.include?("access denied")
    end
  end

  def discovered_paths(robots, sitemap)
    paths = []
    paths.concat(paths_from_robots(robots))
    paths.concat(paths_from_sitemap(sitemap))
    paths.map { |path| normalize_path(path) }.reject(&:empty?).uniq
  end

  def paths_from_robots(response)
    return [] unless response.is_a?(HTTPX::Response)

    response.body.to_s.lines.filter_map do |line|
      normalized = line.strip
      next unless normalized.downcase.start_with?("allow:", "disallow:")

      normalized.split(":", 2).last.to_s.strip
    end
  end

  def paths_from_sitemap(response)
    return [] unless response.is_a?(HTTPX::Response)

    doc = Nokogiri::XML(response.body.to_s)
    doc.remove_namespaces!
    doc.xpath("//url/loc").map { |node| URI(node.text).path rescue nil }.compact
  rescue StandardError
    []
  end

  def normalize_path(path)
    path.to_s.strip.gsub(%r{^/+}, "").split("?").first.to_s
  end

  def trimmed_site
    site.to_s.chomp("/")
  end

  def extract_title(html)
    return "" if html.to_s.empty?

    doc = Nokogiri::HTML(html)
    doc.at("title")&.text.to_s.strip.downcase
  rescue StandardError
    ""
  end

  def extract_tokens(html)
    return [] if html.to_s.empty?

    text = Nokogiri::HTML(html).text.downcase
    words = text.gsub(/[^a-z0-9\s]/, " ").split(/\s+/)
    stopwords = %w[the and for with from this that your are was were have has not you all www com http https]

    words
      .select { |word| word.length >= 4 }
      .reject { |word| stopwords.include?(word) }
      .uniq
      .first(120)
  rescue StandardError
    []
  end
end
