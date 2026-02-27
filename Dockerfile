# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.0.2

# -------------------------
# Build stage
# -------------------------
FROM ruby:$RUBY_VERSION-alpine AS build
WORKDIR /app

ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=production

RUN apk add --no-cache \
    build-base \
    sqlite-dev \
    ruby-dev \
    curl \
    zip \
    unzip

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

# -------------------------
# Shared runtime base
# -------------------------
FROM ruby:$RUBY_VERSION-alpine AS runtime-base
WORKDIR /app

ENV RAILS_ENV=development \
    REDIS_URL=redis://redis:6379/0 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=production

RUN apk add --no-cache \
    sqlite \
    curl \
    zip \
    && adduser -D appuser

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app
RUN mkdir -p /app/screenshots && chown -R appuser:appuser /app

USER appuser
EXPOSE 3000
CMD ["sh", "-c", "bundle exec sidekiq & bundle exec rails server -b 0.0.0.0"]

# -------------------------
# Full runtime (with screenshots)
# -------------------------
FROM runtime-base AS runtime
USER root
RUN apk add --no-cache \
    chromium \
    chromium-chromedriver
USER appuser

# -------------------------
# Slim runtime (no screenshots)
# -------------------------
FROM runtime-base AS runtime-slimmed
