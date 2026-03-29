# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.4.9

# -------------------------
# Build stage
# -------------------------
FROM ruby:$RUBY_VERSION-slim AS build
WORKDIR /app

ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=production

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    libsqlite3-dev \
    pkg-config \
    sqlite3 \
    unzip \
    zip \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

# -------------------------
# Shared runtime base
# -------------------------
FROM ruby:$RUBY_VERSION-slim AS runtime-base
WORKDIR /app

ENV RAILS_ENV=development \
    REDIS_URL=redis://redis:6379/0 \
    SCREENSHOT_ENABLED=true \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=production

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    sqlite3 \
    zip \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /bin/bash appuser

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app
RUN mkdir -p /app/tmp/screenshots \
    && chown -R appuser:appuser /app

USER appuser
EXPOSE 3000
CMD ["sh", "-c", "bundle exec sidekiq & bundle exec rails server -b 0.0.0.0"]

# -------------------------
# Full runtime (with screenshots)
# -------------------------
FROM runtime-base AS runtime
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    chromium-driver \
    && rm -rf /var/lib/apt/lists/*
USER appuser

# -------------------------
# Slim runtime (no screenshots)
# -------------------------
FROM runtime-base AS runtime-slimmed
ENV SCREENSHOT_ENABLED=false
