# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.0.2

# -------------------------
# Build stage
# -------------------------
FROM ruby:$RUBY_VERSION-alpine AS build
WORKDIR /app

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    sqlite-dev \    
    zip \
    curl \
    unzip \
    chromium \
    build-base \
    ruby-dev \
    chromium-chromedriver

# -------------------------
# Runtime stage
# -------------------------
FROM ruby:$RUBY_VERSION-alpine AS runtime
WORKDIR /app

ENV RAILS_ENV=development \
    REDIS_URL="redis://redis:6379/0" \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="production"

# Install only necessary runtime packages
RUN apk add --no-cache \
    sqlite \    
    curl \
    chromium \
    chromium-chromedriver \  
    build-base \
    ruby-dev \  
    && adduser -D appuser

# Copy gems from build stage
COPY --from=build /usr/local/bundle /usr/local/bundle
# Copy app code and wordlist
COPY . .
RUN bundle install && rm -rf /usr/local/bundle/cache /tmp/*

# Ensure correct permissions
RUN chown -R appuser /app
USER appuser

# Expose app port
EXPOSE 3000

# Start both Sidekiq and Rails
CMD ["sh", "-c", "bundle exec sidekiq & bundle exec rails server -b 0.0.0.0"]
