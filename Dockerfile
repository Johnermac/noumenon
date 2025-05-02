# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.0.2

# Build stage (for installing dependencies)
FROM ruby:$RUBY_VERSION-alpine AS build
WORKDIR /app

# Install required build dependencies
RUN apk add --no-cache \
    build-base \
    sqlite-dev \
    git \
    curl \
    wget \
    unzip \
    zip \
    chromium \
    chromium-chromedriver



# Runtime stage (smaller final image)
FROM ruby:$RUBY_VERSION-alpine AS runtime
WORKDIR /app

# Set environment variables
ENV RAILS_ENV=development \
    REDIS_URL="redis://redis:6379/0" \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="production"



# Install only necessary runtime dependencies
RUN apk add --no-cache \
    sqlite \
    vips \
    git \
    curl \
    wget \
    unzip \
    zip \
    chromium \
    chromium-chromedriver \    
    build-base \
    ruby-dev

# Copy application code and dependencies from build stage
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY . .

# Copy Gemfiles and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && rm -rf /usr/local/bundle/cache /tmp/*

# Expose application port
EXPOSE 3000

# Start Rails server with Sidekiq
CMD ["sh", "-c", "bundle exec sidekiq & bundle exec rails server -b 0.0.0.0"]