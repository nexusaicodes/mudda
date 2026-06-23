#!/usr/bin/env bash

set -e

# Beta 1: mudda-beta-lb-101 -> mudda-beta-app-101
ssh app@mudda-beta-lb-101.df-iad-int.37signals.com \
  docker exec mudda-load-balancer \
    kamal-proxy deploy mudda \
      --force \
      --tls \
      --host=beta1.mudda-beta.com \
      --target=mudda-beta-app-101.df-iad-int.37signals.com

# Beta 2: mudda-beta-lb-102 -> mudda-beta-app-102
ssh app@mudda-beta-lb-102.df-iad-int.37signals.com \
  docker exec mudda-load-balancer \
    kamal-proxy deploy mudda \
      --force \
      --tls \
      --host=beta2.mudda-beta.com \
      --target=mudda-beta-app-102.df-iad-int.37signals.com

# Beta 3: mudda-beta-lb-103 -> mudda-beta-app-103
ssh app@mudda-beta-lb-103.df-iad-int.37signals.com \
  docker exec mudda-load-balancer \
    kamal-proxy deploy mudda \
      --force \
      --tls \
      --host=beta3.mudda-beta.com \
      --target=mudda-beta-app-103.df-iad-int.37signals.com

# Beta 4: mudda-beta-lb-104 -> mudda-beta-app-104
ssh app@mudda-beta-lb-104.df-iad-int.37signals.com \
  docker exec mudda-load-balancer \
    kamal-proxy deploy mudda \
      --force \
      --tls \
      --host=beta4.mudda-beta.com \
      --target=mudda-beta-app-104.df-iad-int.37signals.com
