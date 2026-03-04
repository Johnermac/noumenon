class SmartWordlistService
  PHASE_LIMITS = {
    phase_1: 120,
    phase_2: 400,
    phase_3: 1200
  }.freeze

  COMMON_PRIORITY_PATHS = %w[
    admin
    login
    dashboard
    api
    uploads
    assets
    backup
    backups
    dev
    test
    staging
    config
    docs
    robots.txt
    sitemap.xml
    .git
    .env
  ].freeze

  TECHNOLOGY_PATHS = {
    "wordpress" => %w[wp-admin wp-content wp-includes wp-json xmlrpc.php],
    "laravel" => %w[artisan storage bootstrap cache vendor .env],
    "rails" => %w[assets packs sidekiq rails info routes],
    "drupal" => %w[user admin sites/default modules themes],
    "joomla" => %w[administrator components modules templates]
  }.freeze

  def initialize(base_wordlist:, preflight:)
    @base_wordlist = base_wordlist
    @preflight = preflight || {}
  end

  def build
    technologies = Array(preflight[:technologies]).map(&:to_s)
    discovered_paths = Array(preflight[:discovered_paths]).map(&:to_s)

    tech_paths = technologies.flat_map { |tech| TECHNOLOGY_PATHS.fetch(tech, []) }
    merged = (discovered_paths + tech_paths + COMMON_PRIORITY_PATHS + base_wordlist).map do |path|
      normalize(path)
    end

    candidates = merged.reject(&:empty?).uniq

    {
      phase_1: candidates.first(PHASE_LIMITS[:phase_1]),
      phase_2: candidates.drop(PHASE_LIMITS[:phase_1]).first(PHASE_LIMITS[:phase_2]),
      phase_3: candidates.drop(PHASE_LIMITS[:phase_1] + PHASE_LIMITS[:phase_2]).first(PHASE_LIMITS[:phase_3])
    }
  end

  private

  attr_reader :base_wordlist, :preflight

  def normalize(path)
    cleaned = path.to_s.strip
    cleaned = cleaned.gsub(%r{^/+}, "")
    cleaned = cleaned.gsub(%r{/+$}, "")
    cleaned
  end
end
