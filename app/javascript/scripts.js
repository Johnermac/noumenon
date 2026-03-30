
let resultData = {};
let zipDownloadMessage = null;
function normalizeSite(site) {
  return site.trim().replace(/\/+$/, "");
}

function asBool(value) {
  return value === true || value === "true";
}

function moduleStatus(enabled, complete) {
  if (enabled === false) return "not enabled";
  return complete ? "complete" : "running";
}

function updateResults(site) {
  const scanOptions = resultData.scan_options || {};
  let resultHTML = `<p>📡 Scan Results for: <strong>${site}</strong></p>`;
  resultHTML += `<div class="result-section"><p>📊 Scan Status:</p><ul>`;
  resultHTML += `<li><span>Directories: ${moduleStatus(scanOptions.scan_directories, resultData.directories_scan_complete)}</span></li>`;
  resultHTML += `<li><span>Subdomains: ${moduleStatus(scanOptions.scan_subdomains, resultData.subdomain_scan_complete)}</span></li>`;
  resultHTML += `<li><span>Links: ${moduleStatus(scanOptions.scan_links, resultData.link_scan_complete)}</span></li>`;
  resultHTML += `<li><span>Emails: ${moduleStatus(scanOptions.scan_emails, resultData.email_scan_complete)}</span></li>`;
  resultHTML += `<li><span>Screenshots: ${moduleStatus(scanOptions.scan_screenshots, resultData.screenshot_scan_complete)}</span></li>`;
  if (resultData.screenshot_scan_error) {
    resultHTML += `<li><span>Screenshot error: ${resultData.screenshot_scan_error}</span></li>`;
  }
  if (zipDownloadMessage) {
    resultHTML += `<li><span>${zipDownloadMessage}</span></li>`;
  }
  resultHTML += `</ul></div>`;

  const telemetry = resultData.directory_telemetry;
  if (telemetry) {
    const hasHitRates = telemetry.phase_hit_rates && Object.keys(telemetry.phase_hit_rates).length > 0;
    const hasPhaseProgress = telemetry.current_phase && telemetry.current_phase !== "completed";
    const shouldShowTelemetry = resultData.directories_scan_complete === false || telemetry.current_phase || telemetry.waf_detected || hasHitRates;

    if (shouldShowTelemetry) {
    resultHTML += `<div class="result-section"><p>🧠 Directory Scan Telemetry:</p><ul>`;
    resultHTML += `<li><span>Current phase: ${telemetry.current_phase || "n/a"}</span></li>`;

    if (hasPhaseProgress) {
      resultHTML += `<li><span>Phase progress: ${telemetry.phase_processed || 0}/${telemetry.phase_total || 0}</span></li>`;
    }

    resultHTML += `<li><span>WAF detected: ${telemetry.waf_detected ? "yes" : "no"}</span></li>`;
    if (telemetry.scan_error) {
      resultHTML += `<li><span>Error: ${telemetry.scan_error}</span></li>`;
    }

    if (hasHitRates) {
      Object.entries(telemetry.phase_hit_rates).forEach(([phase, rate]) => {
        resultHTML += `<li><span>${phase} hit-rate: ${rate}%</span></li>`;
      });
    }

    resultHTML += `</ul></div>`;
    }
  }

  // Found Directories
  if (Array.isArray(resultData.found_directories) && resultData.found_directories.length) {
    resultHTML += `<div class="result-section">
                      <p class="found_directories">✅ Found Directories:</p><ul>`;
    resultData.found_directories.forEach(directory => {
      resultHTML += `<li><a href="${site}/${directory}" target="_blank">${directory}</a></li>`;
    });
    resultHTML += `</ul></div>`;
  }

  // Found Subdomains
  if (Array.isArray(resultData.found_subdomains) && resultData.found_subdomains.length) {
    resultHTML += `<div class="result-section">
                      <p class="found_subdomains">🟡 Found Subdomains:</p><ul>`;
    resultData.found_subdomains.forEach(subdomain => {
      resultHTML += `<li><a href="https://${subdomain}" target="_blank">${subdomain}</a></li>`;
    });
    resultHTML += `</ul></div>`;
  }

  // Active Subdomains
  if (Array.isArray(resultData.active_subdomains) && resultData.active_subdomains.length) {
    resultHTML += `<div class="result-section">
                      <p class="active_sub">🟢 Active Subdomains:</p><ul>`;
    resultData.active_subdomains.forEach(subdomain => {
      resultHTML += `<li><a href="https://${subdomain}" target="_blank">${subdomain}</a></li>`;
    });
    resultHTML += `</ul></div>`;
  }

  // Extracted Links
  if (Array.isArray(resultData.extracted_links) && resultData.extracted_links.length) {
    resultHTML += `<div class="result-section">
                      <p class="extracted_links">🔗 Extracted Links:</p><ul>`;
    resultData.extracted_links.forEach(link => {
      resultHTML += `<li><a href="${link}" target="_blank">${link}</a></li>`;
    });
    resultHTML += `</ul></div>`;
  }

  // Extracted Emails
  if (Array.isArray(resultData.extracted_emails) && resultData.extracted_emails.length) {
    resultHTML += `<div class="result-section">
                      <p class="extracted_emails">🔵 Extracted Emails:</p><ul>`;
    resultData.extracted_emails.forEach(email => {
      resultHTML += `<li><span>${email}</span></li>`;
    });
    resultHTML += `</ul></div>`;
  }

  document.getElementById("result").innerHTML = resultHTML;
}

function downloadResultsAsTxt(filename, content) {
  const blob = new Blob([content], { type: "text/plain" });
  const url = URL.createObjectURL(blob);

  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();

  URL.revokeObjectURL(url);  
}

function downloadScreenshotZip(site) {
  let attempts = 0;
  const maxAttempts = 20;
  const resultElement = document.getElementById("result");

  const pollZip = async () => {
    try {
      const res = await fetch(`/download/screenshot_zip_info?site=${encodeURIComponent(site)}`);
      const data = await res.json();

      if (data.zip_ready) {
        alert(`🗝️ ZIP Password: ${data.password}`);
        const a = document.createElement("a");
        a.href = `/download/screenshot_zip?site=${encodeURIComponent(site)}`;
        a.download = `${site}_screenshots.zip`;
        a.click();
        zipDownloadMessage = "ZIP download started!";
        updateResults(site);
        return;
      }

      attempts += 1;
      if (attempts < maxAttempts) {
        setTimeout(pollZip, 3000);
      } else {
        console.warn("Screenshot ZIP is still not ready.");
      }
    } catch (err) {
      console.error("❌ Failed to fetch zip info:", err);
    }
  };

  pollZip();
}

let pollingIntervalId = null;

function startPolling(site, options) {
  let retryCount = 0;
  const maxRetries = 150;

  let {
    directoriesComplete,
    subdomainsComplete,
    linksComplete,
    emailsComplete,
    screenshotsComplete,
    scanDirectories,
    scanSubdomains,
    scanLinks,
    scanEmails,
    scanScreenshots
  } = options;

  if (pollingIntervalId !== null) {
    clearInterval(pollingIntervalId);
  }

  pollingIntervalId = setInterval(async () => {
    try {
      const resultResponse = await fetch(`/scans/show?site=${encodeURIComponent(site)}`);
      if (resultResponse.ok) {
        const currentResultData = await resultResponse.json();
        resultData = { ...resultData, ...currentResultData };

        console.log("Polling result:", currentResultData);
        console.log("Directory telemetry:", currentResultData.directory_telemetry);
        updateResults(site);

        directoriesComplete ||= currentResultData.directories_scan_complete;
        subdomainsComplete ||= currentResultData.subdomain_scan_complete;
        linksComplete ||= currentResultData.link_scan_complete;
        emailsComplete ||= currentResultData.email_scan_complete;
        screenshotsComplete ||= currentResultData.screenshot_scan_complete;

        if (directoriesComplete && subdomainsComplete && linksComplete && emailsComplete && screenshotsComplete) {
          clearInterval(pollingIntervalId);
          pollingIntervalId = null;

          const resultElement = document.getElementById("result");

          if (scanDirectories || scanSubdomains || scanLinks || scanEmails) {
            downloadResultsAsTxt(`${site}_scan_results.txt`, resultElement.innerText);
          }

          if (scanScreenshots) {
            downloadScreenshotZip(site);
          }

          resultElement.innerHTML += `<p>✅ Scans are complete for: <strong>${site}</strong></p>`;
        }
      } else {
        const errorText = await resultResponse.text();
        console.error(`❌ Fetch failed: ${resultResponse.statusText}\n${errorText}`);
      }

      if (++retryCount >= maxRetries) {
        clearInterval(pollingIntervalId);
        pollingIntervalId = null;
        document.getElementById("result").innerHTML += `<p>⚠️ Scan process took too long and was stopped. Please check manually.</p>`;
      }

    } catch (error) {
      console.error("Error fetching results:", error);
    }
  }, 10000); // 10s
}

document.getElementById("scan-form").addEventListener("submit", async function(event) {
  event.preventDefault();

  const form = document.getElementById("scan-form");
  const siteInput = document.getElementById("site-input");
  const resultElement = document.getElementById("result");

  const site = normalizeSite(siteInput.value);
  zipDownloadMessage = null;
  const screenshotToggle = document.getElementById("scan-screenshots-toggle");
  const screenshotsFeatureEnabled = form.dataset.screenshotEnabled === "true";
  const scanDirectories = document.getElementById("scan-directories-toggle").checked;
  const scanSubdomains = document.getElementById("scan-subdomains-toggle").checked;
  const scanLinks = document.getElementById("scan-links-toggle").checked;
  const scanEmails = document.getElementById("scan-emails-toggle").checked;
  const scanScreenshots = screenshotsFeatureEnabled && screenshotToggle && screenshotToggle.checked === true;

  resultElement.innerHTML = "⌛ Scanning...";

  if (!site) {
    resultElement.innerHTML = "❌ Please enter a site URL.";
    return;
  }

  try {
    const response = await fetch("/scans/create", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ site, scan_directories: scanDirectories, scan_subdomains: scanSubdomains, scan_links: scanLinks, scan_emails: scanEmails, scan_screenshots: scanScreenshots })
    });

    const data = await response.json();

    if (response.ok) {
      const effectiveScanDirectories = asBool(data.scan_directories);
      const effectiveScanSubdomains = asBool(data.scan_subdomains);
      const effectiveScanLinks = asBool(data.scan_links);
      const effectiveScanEmails = asBool(data.scan_emails);
      const effectiveScanScreenshots = asBool(data.scan_screenshots);

      resultData.scan_options = {
        scan_directories: effectiveScanDirectories,
        scan_subdomains: effectiveScanSubdomains,
        scan_links: effectiveScanLinks,
        scan_emails: effectiveScanEmails,
        scan_screenshots: effectiveScanScreenshots
      };
      resultElement.innerHTML = `<p>📡 Scan started for: <strong>${site}</strong></p>`;

      startPolling(site, {
        directoriesComplete: !effectiveScanDirectories,
        subdomainsComplete: !effectiveScanSubdomains,
        linksComplete: !effectiveScanLinks,
        emailsComplete: !effectiveScanEmails,
        screenshotsComplete: !effectiveScanScreenshots,
        scanDirectories: effectiveScanDirectories,
        scanSubdomains: effectiveScanSubdomains,
        scanLinks: effectiveScanLinks,
        scanEmails: effectiveScanEmails,
        scanScreenshots: effectiveScanScreenshots
      });
    } else {
      resultElement.innerHTML = `❌ Error: ${data.error}`;
    }
  } catch (error) {
    console.error("Scan request failed:", error);
    resultElement.innerHTML = `❌ Error starting scan: ${error.message}`;
  }
});
