require "httparty"
require "redis"


class ScanWorker
  include HTTParty
  include Sidekiq::Worker

  def perform(site, scan_directories, scan_subdomains)

    # -----------------  VALIDATE WORDLIST  ---------------------
 
    wordlist_path = Rails.root.join("tmp", "wordlist.txt")

    unless File.exist?(wordlist_path)
      puts "\n\t❌ Wordlist file not found at #{wordlist_path}"
      return
    end

    # ---------------------  DIR  ------------------------------

    directories = File.readlines(wordlist_path).map(&:strip).reject(&:empty?)    

    puts "\n => RUN DIR? #{scan_directories}"
    puts "\n => RUN SUB? #{scan_subdomains}"

    if scan_directories
      found_directories, not_found_directories = run_directories(site, directories)

      result = {
      found_directories: found_directories,
      not_found_directories: not_found_directories
      }

      REDIS.set("scan_results_#{site}_directories", result.to_json)
      REDIS.expire("scan_results_#{site}_directories", 10)

      puts "\n  Scan Results for #{site}:"
      puts "    \t✅ Found Directories: #{found_directories.join(', ')}" if found_directories.any?
      puts "    \t❌ Not Found Directories: #{not_found_directories.join(', ')}\n" if not_found_directories.any?

    end   

    # ---------------------  SUB  ------------------------------

    subdomains = ""

    if scan_subdomains
      found_subdomains, active_subdomains = run_subdomains(site, subdomains)

      result = {
        found_subdomains: found_subdomains,
        active_subdomains: active_subdomains 
      }

      REDIS.set("scan_results_#{site}_subdomains", result.to_json)
      REDIS.expire("scan_results_#{site}_subdomains", 10)

      puts "\n  Scan Results for #{site}:"
      puts "    \t✅ Found Subdomains: #{found_subdomains.join(', ')}" if found_subdomains.any?
      puts "    \t✅✅ Active Subdomains: #{active_subdomains .join(', ')}\n" if active_subdomains .any?

    end

  end

  private

  def run_directories(site, directories)
    found_directories = []
    not_found_directories = []

    directories.each do |dir|
      url = "#{site}/#{dir}"
      response = HTTParty.get(url)

      if response.code == 200
        found_directories << dir
      else
        not_found_directories << dir
      end      
    end
    [found_directories, not_found_directories]
  end


  def run_subdomains(site, subdomains)
    found_subdomains = []
    active_subdomains = []

    # implement logic
    puts "\n=> Time to shine"

    [found_subdomains, active_subdomains]
  end
end