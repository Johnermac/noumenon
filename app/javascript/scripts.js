document.getElementById("scan-form").addEventListener("submit", async function(event) {
  event.preventDefault();

  const siteInput = document.getElementById("site-input");
  const scanDirectoriesToggle = document.getElementById("scan-directories-toggle");
  const scanSubdomainsToggle = document.getElementById("scan-subdomains-toggle");
  const scanLinksToggle = document.getElementById("scan-links-toggle");

  const resultElement = document.getElementById("result");
  resultElement.innerHTML = "⌛ Scanning...";

  const site = siteInput.value.trim();
  const scanDirectories = scanDirectoriesToggle.checked;
  const scanSubdomains = scanSubdomainsToggle.checked;
  const scanLinks = scanLinksToggle.checked;

  if (!site) {
      resultElement.innerHTML = "❌ Please enter a site URL.";
      return;
  }

  try {
      const response = await fetch("/scans/create", {
          method: "POST",
          headers: {
              "Content-Type": "application/json"
          },
          body: JSON.stringify({ site: site, scan_directories: scanDirectories, scan_subdomains: scanSubdomains, scan_links: scanLinks }) 
      });

      const data = await response.json();

      if (response.ok) {
          resultElement.innerHTML = `<p>📡 Scan started for: <strong>${site}</strong></p>`;
          
          // Initialize flags to check if scans are complete
          let directoriesComplete = !scanDirectories; // If scanDirectories is false, consider it complete
          let subdomainsComplete = !scanSubdomains;   // If scanSubdomains is false, consider it complete
          let linksComplete = !scanLinks;
          
          let resultData = {};

          // Function to update results
          const updateResults = () => {
            let resultHTML = `<p>📡 Scan Results for: <strong>${site}</strong></p>`;

            // Found Directories
            if (resultData.found_directories && resultData.found_directories.length > 0) {
              resultHTML += `<div class="result-section">
                                <p class="found_directories">✅ Found Directories:</p><ul>`;
              resultData.found_directories.forEach(directory => {
                resultHTML += `<li><a href="${site}/${directory}" target="_blank">${directory}</a></li>`;
              });
              resultHTML += `</ul></div>`;
            }

            // Not Found Directories
            if (resultData.not_found_directories && resultData.not_found_directories.length > 0) {
              resultHTML += `<div class="result-section">
                                <p class="not-found_dir">❌ Not Found Directories:</p><ul>`;
              resultData.not_found_directories.forEach(directory => {
                resultHTML += `<li><span>${directory}</span></li>`;
              });
              resultHTML += `</ul></div>`;
            }

            // Found Subdomains
            if (resultData.found_subdomains && resultData.found_subdomains.length > 0) {
              resultHTML += `<div class="result-section">
                                <p class="found_subdomains">🟡 Found Subdomains:</p><ul>`;
              resultData.found_subdomains.forEach(subdomain => {
                resultHTML += `<li><a href="https://${subdomain}" target="_blank">${subdomain}</a></li>`;
              });
              resultHTML += `</ul></div>`;
            }

            // Active Subdomains
            if (resultData.active_subdomains && resultData.active_subdomains.length > 0) {
              resultHTML += `<div class="result-section">
                                <p class="active_sub">🟢 Active Subdomains:</p><ul>`;
              resultData.active_subdomains.forEach(subdomain => {
                resultHTML += `<li><a href="https://${subdomain}" target="_blank">${subdomain}</a></li>`;
              });
              resultHTML += `</ul></div>`;
            }

            // Extracted Links
            if (resultData.extracted_links && resultData.extracted_links.length > 0) {
              resultHTML += `<div class="result-section">
                                <p class="extracted_links">🔗 Extracted Links:</p><ul>`;
              resultData.extracted_links.forEach(link => {
                resultHTML += `<li><a href="${link}" target="_blank">${link}</a></li>`;
              });
              resultHTML += `</ul></div>`;
            }

            resultElement.innerHTML = resultHTML;
          };


          // Periodically check for scan results
          const checkResults = setInterval(async () => {
            try {
              const resultResponse = await fetch(`/scans/show?site=${encodeURIComponent(site)}`);
              

              if (resultResponse.ok) {
                const currentResultData = await resultResponse.json();

                // Merge the current results into the overall results data
                resultData = { ...resultData, ...currentResultData };

                // Dynamically update the results
                updateResults();

                // Update completion flags based on scan status
                directoriesComplete = directoriesComplete || currentResultData.directories_scan_complete;
                subdomainsComplete = subdomainsComplete || currentResultData.subdomain_scan_complete;
                linksComplete = linksComplete || currentResultData.link_scan_complete;

                // Stop polling if both directories and subdomains scans are complete
                if (directoriesComplete && subdomainsComplete && linksComplete) {
                  clearInterval(checkResults); // Stop polling once the main scans are complete
                  resultElement.innerHTML += `<p>✅ Scans are complete for: <strong>${site}</strong></p>`;
                }
              } else {
                console.error("Failed to fetch scan results.");
              }
            } catch (error) {
              console.error("Error fetching results:", error);
            }
          }, 5000); // Check every 5 seconds

      } else {
          resultElement.innerHTML = `❌ Error: ${data.error}`;
      }
  } catch (error) {
      console.error("Scan request failed:", error);
      resultElement.innerHTML = `❌ Error starting scan: ${error.message}`;
  }
});