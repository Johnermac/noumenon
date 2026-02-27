
**Noumenon** is a directory and subdomain enumeration tool built with Ruby on Rails, Redis, and Sidekiq. 
It scans and validates subdomains, directories, links, and emails — and takes screenshots of every subdomain and directory it finds.

![noumenon](https://github.com/user-attachments/assets/d9f95e71-ccb2-4ae5-b2b3-6c6c58b1ac07)


🛠️ Features:

  - Subdomain + directory enumeration
  - Email and link extraction
  - Screenshot capture (headless Chrome)
  - Queue-based architecture with Redis + Sidekiq   
  - Dark-themed web UI
  - Docker support:
        :latest (~210MB) full version with screenshots
        :slimmed (~90MB) minimal version without screenshot feature


[Docker image](https://hub.docker.com/r/johnermac/noumenon/)

**1** - **Running with Docker (recommended):**

Install docker:
```
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker
```

Copy the code below and name as docker-compose.yml

```yml
version: '3.8'
services:
  redis:
    image: redis:latest
    container_name: redis_container
    ports:
      - "6379:6379"

  app:
    image: johnermac/noumenon:latest #use :slimmed (90mb) if you're not gonna use the screenshot option
    container_name: rails_app
    environment:
      - RAILS_ENV=development
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - redis
    ports:
      - "3000:3000"
```

> Now just: docker-compose up --build

*It'll grab the images and start the app, when finish'd u can access the localhost:3000*

> I'd recommend to use the 'Scan Directory' by itself because it takes 20~30 min to finish. The others Scans are very fast.

> Open your browser and visit: http://localhost:3000


Hope you find it useful – feedback and suggestions are welcome!
