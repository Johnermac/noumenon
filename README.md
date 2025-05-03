[Download the docker image](https://hub.docker.com/r/johnermac/noumenon/)

> docker-compose up --build

docker-compose.yml
```
version: '3.8'
services:
  redis:
    image: redis:latest
    container_name: redis_container
    ports:
      - "6379:6379"

  app:
    image: johnermac/noumenon 
    container_name: rails_app
    environment:
      - RAILS_ENV=development
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - redis
    ports:
      - "3000:3000"
```
