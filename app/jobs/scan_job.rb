class ScanJob
  include Sidekiq::Job
  
  BATCH_SIZE = 100 # Prevents overloading

  def perform(domain, options = {})
    scan = Scan.create(domain: domain, status: "running")

    # Call different scanning services based on options
    results = {}

    if options["directories"]
      wordlist_path = "tmp/wordlist.txt" # Define your wordlist path
      wordlist = File.readlines(wordlist_path).map(&:strip)

      wordlist.each do |word|
        DirectoryScanWorker.perform_async(domain, word, options["verbose"], options["stealth"])
      end
    end

    results[:subdomains] = SubdomainScannerService.new(domain).scan if options["subdomains"]
    results[:emails] = EmailExtractorService.new(domain).scan if options["emails"]
    results[:screenshots] = ScreenshotService.new(domain).capture if options["screenshots"]

    # ADD LINK LATER

    # Save results (to be refined based on DB structure)
    scan.update(results: results, status: "completed")
  rescue => e
    scan.update(status: "failed", error: e.message)
  end
end
