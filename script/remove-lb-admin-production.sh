#!/usr/bin/env bash

set -e

ssh app@mudda-lb-101.df-iad-int.37signals.com \
  docker exec mudda-load-balancer kamal-proxy rm mudda-admin

ssh app@mudda-lb-01.sc-chi-int.37signals.com \
  docker exec mudda-load-balancer kamal-proxy rm mudda-admin

ssh app@mudda-lb-401.df-ams-int.37signals.com \
  docker exec mudda-load-balancer kamal-proxy rm mudda-admin
