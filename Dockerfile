FROM ruby:2.7.6

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    gnupg \
    libsnappy-dev \
    liblz4-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /cassandra-ruby-driver
