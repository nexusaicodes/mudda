#!/usr/bin/env bash

set -e

# mudda-lb-101.df-iad-int.37signals.com
#
ssh app@mudda-lb-101.df-iad-int.37signals.com \
  docker exec mudda-load-balancer \
    kamal-proxy deploy mudda \
      --force \
      --tls \
      --host=app.mudda.do \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=mudda-app-101.df-iad-int.37signals.com \
      --target=mudda-app-102.df-iad-int.37signals.com


# mudda-lb-102.df-iad-int.37signals.com
#
ssh app@mudda-lb-102.df-iad-int.37signals.com \
  docker exec mudda-load-balancer \
    kamal-proxy deploy mudda \
      --force \
      --tls \
      --host=app.mudda.do \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=mudda-app-101.df-iad-int.37signals.com \
      --target=mudda-app-102.df-iad-int.37signals.com


# mudda-lb-01.sc-chi-int.37signals.com
#
ssh app@mudda-lb-01.sc-chi-int.37signals.com \
  docker exec mudda-load-balancer \
    kamal-proxy deploy mudda \
      --force \
      --tls \
      --host=app.mudda.do \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=mudda-app-101.df-iad-int.37signals.com \
      --target=mudda-app-102.df-iad-int.37signals.com \
      --read-target=mudda-app-01.sc-chi-int.37signals.com \
      --read-target=mudda-app-02.sc-chi-int.37signals.com


# mudda-lb-02.sc-chi-int.37signals.com
#
ssh app@mudda-lb-02.sc-chi-int.37signals.com \
  docker exec mudda-load-balancer \
    kamal-proxy deploy mudda \
      --force \
      --tls \
      --host=app.mudda.do \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=mudda-app-101.df-iad-int.37signals.com \
      --target=mudda-app-102.df-iad-int.37signals.com \
      --read-target=mudda-app-01.sc-chi-int.37signals.com \
      --read-target=mudda-app-02.sc-chi-int.37signals.com


# mudda-lb-401.df-ams-int.37signals.com
#
ssh app@mudda-lb-401.df-ams-int.37signals.com \
  docker exec mudda-load-balancer \
    kamal-proxy deploy mudda \
      --force \
      --tls \
      --host=app.mudda.do \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=mudda-app-101.df-iad-int.37signals.com \
      --target=mudda-app-102.df-iad-int.37signals.com \
      --read-target=mudda-app-401.df-ams-int.37signals.com \
      --read-target=mudda-app-402.df-ams-int.37signals.com


# mudda-lb-402.df-ams-int.37signals.com
#
ssh app@mudda-lb-402.df-ams-int.37signals.com \
  docker exec mudda-load-balancer \
    kamal-proxy deploy mudda \
      --force \
      --tls \
      --host=app.mudda.do \
      --writer-affinity-timeout=0 \
      --tls-acme-cache-path=/certificates \
      --target=mudda-app-101.df-iad-int.37signals.com \
      --target=mudda-app-102.df-iad-int.37signals.com \
      --read-target=mudda-app-401.df-ams-int.37signals.com \
      --read-target=mudda-app-402.df-ams-int.37signals.com
