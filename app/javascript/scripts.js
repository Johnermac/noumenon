
let resultData = {};

function updateResults(site) {
  let resultHTML = `<p>📡 Scan Results for: <strong>${site}</strong></p>`;

  // Found Directories
  if (resultData.found_directories?.length) {
    resultHTML += `<div class="result-section">
                      <p class="found_directories">✅ Found Directories:</p><ul>`;
    resultData.found_directories.forEach(directory => {
      resultHTML += `<li><a href="${site}/${directory}" target="_blank">${directory}</a></li>`;
    });
    resultHTML += `</ul></div>`;
  }

  // Not Found Directories
  if (resultData.not_found_directories?.length) {
    resultHTML += `<div class="result-section">
                      <p class="not-found_dir">❌ Not Found Directories:</p><ul>`;
    resultData.not_found_directories.forEach(directory => {
      resultHTML += `<li><span>${directory}</span></li>`;
    });
    resultHTML += `</ul></div>`;
  }

  // Found Subdomains
  if (resultData.found_subdomains?.length) {
    resultHTML += `<div class="result-section">
                      <p class="found_subdomains">🟡 Found Subdomains:</p><ul>`;
    resultData.found_subdomains.forEach(subdomain => {
      resultHTML += `<li><a href="https://${subdomain}" target="_blank">${subdomain}</a></li>`;
    });
    resultHTML += `</ul></div>`;
  }

  // Active Subdomains
  if (resultData.active_subdomains?.length) {
    resultHTML += `<div class="result-section">
                      <p class="active_sub">🟢 Active Subdomains:</p><ul>`;
    resultData.active_subdomains.forEach(subdomain => {
      resultHTML += `<li><a href="https://${subdomain}" target="_blank">${subdomain}</a></li>`;
    });
    resultHTML += `</ul></div>`;
  }

  // Extracted Links
  if (resultData.extracted_links?.length) {
    resultHTML += `<div class="result-section">
                      <p class="extracted_links">🔗 Extracted Links:</p><ul>`;
    resultData.extracted_links.forEach(link => {
      resultHTML += `<li><a href="${link}" target="_blank">${link}</a></li>`;
    });
    resultHTML += `</ul></div>`;
  }

  // Extracted Emails
  if (resultData.extracted_emails?.length) {
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
  fetch(`/download/screenshot_zip_info?site=${encodeURIComponent(site)}`)
    .then(res => res.json())
    .then(data => {
      if (data.zip_ready) {
        alert(`🗝️ ZIP Password: ${data.password}`);
        const a = document.createElement("a");
        a.href = `/download/screenshot_zip?site=${encodeURIComponent(site)}`;
        a.download = `${site}_screenshots.zip`;
        a.click();
      } else {
        console.warn("⏳ Zip not ready yet.");
      }
    })
    .catch(err => {
      console.error("❌ Failed to fetch zip info:", err);
    });
}

let pollingIntervalId = null;

function startPolling(site, options) {
  let retryCount = 0;
  const maxRetries = 60;

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

  const siteInput = document.getElementById("site-input");
  const resultElement = document.getElementById("result");

  const site = siteInput.value.trim();
  const scanDirectories = document.getElementById("scan-directories-toggle").checked;
  const scanSubdomains = document.getElementById("scan-subdomains-toggle").checked;
  const scanLinks = document.getElementById("scan-links-toggle").checked;
  const scanEmails = document.getElementById("scan-emails-toggle").checked;
  const scanScreenshots = document.getElementById("scan-screenshots-toggle").checked;

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
      resultElement.innerHTML = `<p>📡 Scan started for: <strong>${site}</strong></p>`;

      startPolling(site, {
        directoriesComplete: !scanDirectories,
        subdomainsComplete: !scanSubdomains,
        linksComplete: !scanLinks,
        emailsComplete: !scanEmails,
        screenshotsComplete: !scanScreenshots,
        scanDirectories,
        scanSubdomains,
        scanLinks,
        scanEmails,
        scanScreenshots
      });
    } else {
      resultElement.innerHTML = `❌ Error: ${data.error}`;
    }
  } catch (error) {
    console.error("Scan request failed:", error);
    resultElement.innerHTML = `❌ Error starting scan: ${error.message}`;
  }
});

