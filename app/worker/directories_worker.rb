require "redis"
require 'httpx'
require 'digest'
require 'uri'
require 'nokogiri'
require 'set'

class DirectoriesWorker
  include Sidekiq::Worker

  USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:136.0) Gecko/20100101 Firefox/136.0".freeze
  REQUEST_TIMEOUT = { connect_timeout: 5, operation_timeout: 8 }.freeze
  MAX_REQUESTS_PER_SECOND = 4
  RETRYABLE_STATUSES = [403, 429, 503].freeze
  REDIS_TTL = 1500

  def perform(site, directories, total_directories, phase_key = "phase_1", mark_complete = false, fingerprint = nil)
    begin
      REDIS.set("directories_scan_started_at_#{site}", Time.now.to_i) unless REDIS.exists?("directories_scan_started_at_#{site}")

      directories.each do |dir|
        process_directory(site, dir, fingerprint)
        REDIS.incrby(processed_key(site, phase_key), 1)
      end      

      processed_directories = REDIS.get(processed_key(site, phase_key)).to_i
      check_progress(site, total_directories, processed_directories)      
      cleanup_directories(site, phase_key, mark_complete) if processed_directories >= total_directories      
    
    rescue StandardError => e
      puts "Error during directories scan: #{e.message}"
    end
  end

  private

  def cleanup_directories(site, phase_key, mark_complete)
    REDIS.expire(processed_key(site, phase_key), REDIS_TTL)
    REDIS.expire("found_directories_#{site}", REDIS_TTL)
    REDIS.expire("not_found_directories_#{site}", REDIS_TTL)
    REDIS.expire("directories_scan_started_at_#{site}", REDIS_TTL)

    return unless mark_complete

    REDIS.set("directories_scan_complete_#{site}", "true") 
    REDIS.expire("directories_scan_complete_#{site}", REDIS_TTL)
    found_directories = REDIS.smembers("found_directories_#{site}")
    not_found_directories = REDIS.smembers("not_found_directories_#{site}")

    puts "\n  Scan Results for #{site}:"
    puts "    \t✅ Found Directories: #{found_directories.join(', ')}" if found_directories.any?
    puts "    \t❌ Not Found Directories: #{not_found_directories.join(', ')}\n" if not_found_directories.any?
  end

  def check_progress(site, total_directories, processed_directories)
    # Check the number of completed subdomains      
    start_time = REDIS.get("directories_scan_started_at_#{site}").to_i

    return unless Time.now.min.even? && Time.now.sec == 0
    
    if start_time > 0 && processed_directories > 0
      percent = ((processed_directories / total_directories.to_f) * 100).round(2)
      elapsed = Time.now.to_i - start_time
      speed = processed_directories / elapsed.to_f             # entries per second
      remaining = total_directories - processed_directories
      eta_seconds = (remaining / speed).round      # estimated time left
      eta = Time.at(eta_seconds).utc.strftime("%H:%M:%S")
      
      line = "⏱️  Processed: #{processed_directories}/#{total_directories} (#{percent}%) | Elapsed: #{elapsed}s | Speed: #{speed.round(2)}/s | ETA: ~#{eta}"
      print "\r#{line.ljust(120)}"
      $stdout.flush
    end
  end

  def process_directory(site, dir, fingerprint)
    return if dir.to_s.strip.empty?

    url = "#{site}/#{dir}"
    response = resilient_request(url)

    if response.is_a?(HTTPX::Response) && interesting_status?(response.status)
      if fingerprint && false_positive?(response, fingerprint)
        REDIS.sadd("not_found_directories_#{site}", dir)
      else
        REDIS.sadd("found_directories_#{site}", dir)
        puts "\tFOUND: #{dir}"
      end
    else
      REDIS.sadd("not_found_directories_#{site}", dir)
    end
  end

  def resilient_request(url)
    attempts = 0

    loop do
      begin
        throttle!(url)
        response = HTTPX.with(timeout: REQUEST_TIMEOUT).get(url, headers: { "User-Agent" => USER_AGENT })
        if response.is_a?(HTTPX::Response) && RETRYABLE_STATUSES.include?(response.status.to_i) && attempts < 2
          attempts += 1
          backoff_sleep(attempts)
          next
        end
        return response
      rescue HTTPX::Error
        attempts += 1
        if attempts <= 2
          backoff_sleep(attempts)
          next
        end
        return nil
      end
    end
  end
  
  def backoff_sleep(attempt)
    base = 0.35 * (2**attempt)
    sleep(base + rand * 0.15)
  end

  def throttle!(url)
    host = URI.parse(url).host
    return if host.to_s.empty?
    key = "directories_ratelimit_#{host}_#{Time.now.to_i}"

    loop do
      count = REDIS.incr(key)
      REDIS.expire(key, 2) if count == 1
      break if count <= MAX_REQUESTS_PER_SECOND
      sleep(0.1 + rand * 0.1)
    end
  rescue URI::InvalidURIError
    sleep(0.1)
  end

  def interesting_status?(status)
    status_code = status.to_i
    status_code >= 200 && status_code < 400
  end

  def false_positive?(response, fingerprint)
    return false unless response && response.body

    body = response.body.to_s
    status_match = response.status.to_i == fingerprint["status"].to_i
    size_match = (body.size - fingerprint["body_size"].to_i).abs <= 140
    hash_match = Digest::SHA256.hexdigest(body[0, 512].to_s) == fingerprint["prefix_hash"].to_s

    title = extract_title(body)
    title_match = !fingerprint["title"].to_s.empty? && title == fingerprint["title"].to_s
    soft_error_title = title.match?(/\b(404|not found|error|acesso negado|pagina nao encontrada)\b/i)
    token_similarity = jaccard_similarity(extract_tokens(body), Array(fingerprint["text_tokens"]))
    high_similarity = token_similarity >= 0.72

    (status_match && size_match) || hash_match || (status_match && title_match) || (status_match && high_similarity) || soft_error_title
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

  def jaccard_similarity(a_tokens, b_tokens)
    a_set = Array(a_tokens).to_set
    b_set = Array(b_tokens).to_set
    return 0.0 if a_set.empty? || b_set.empty?

    intersection = (a_set & b_set).size.to_f
    union = (a_set | b_set).size.to_f
    return 0.0 if union.zero?

    intersection / union
  end

  def processed_key(site, phase_key)
    "processed_directories_#{site}_#{phase_key}"
  end
  
end
