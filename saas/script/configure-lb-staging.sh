#!/usr/bin/env bash

set -e

# mudda-staging-lb-01.sc-chi-int.37signals.com
#
ssh app@mudda-staging-lb-01.sc-chi-int.37signals.com \
  docker exec mudda-load-balancer \
    kamal-proxy deploy mudda \
      --force \
      --tls \
      --host=app.mudda-staging.com \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=mudda-staging-app-101.df-iad-int.37signals.com \
      --target=mudda-staging-app-102.df-iad-int.37signals.com \
      --read-target=mudda-staging-app-01.sc-chi-int.37signals.com \
      --read-target=mudda-staging-app-02.sc-chi-int.37signals.com

# mudda-staging-lb-101.df-iad-int.37signals.com
#
ssh app@mudda-staging-lb-101.df-iad-int.37signals.com \
  docker exec mudda-load-balancer \
    kamal-proxy deploy mudda \
      --force \
      --tls \
      --host=app.mudda-staging.com \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=mudda-staging-app-101.df-iad-int.37signals.com \
      --target=mudda-staging-app-102.df-iad-int.37signals.com

# mudda-staging-lb-401.df-ams-int.37signals.com
#
ssh app@mudda-staging-lb-401.df-ams-int.37signals.com \
  docker exec mudda-load-balancer \
    kamal-proxy deploy mudda \
      --force \
      --tls \
      --host=app.mudda-staging.com \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=mudda-staging-app-101.df-iad-int.37signals.com \
      --target=mudda-staging-app-102.df-iad-int.37signals.com \
      --read-target=mudda-staging-app-401.df-ams-int.37signals.com \
      --read-target=mudda-staging-app-402.df-ams-int.37signals.com 

