This is a Rails engine that [37signals](https://37signals.com/) bundles with [Mudda](https://github.com/basecamp/mudda) to offer the hosted version at https://mudda.do.

## Development

To make Mudda run in SaaS mode, run this in the terminal:

```ruby
bin/rails saas:enable
```

To go back to open source mode:

```ruby
bin/rails saas:disable
```

Then you can do [Mudda development as usual](https://github.com/basecamp/mudda).

## How to update Mudda

After making changes to this gem, you need to update Mudda to pick up the changes:

```ruby
BUNDLE_GEMFILE=Gemfile.saas bundle update --conservative mudda-saas
```

## Working with Stripe

The first time, you need to:

1. Install Stripe CLI: https://stripe.com/docs/stripe-cli
2. Run `stripe login` and authorize the environment `37signals Development`

Then, for working on the Stripe integration locally, you need to run this script to start the tunneling and set the environment variables:

```sh
eval "$(BUNDLE_GEMFILE=Gemfile.saas bundle exec stripe-dev)"
bin/dev # You need to start the dev server in the same terminal session
```

This will ask for your 1password authorization to read and set the environment variables that Stripe needs.

### Stripe environments

* [Development](https://dashboard.stripe.com/acct_1SdTFtRus34tgjsJ/test/dashboard)
* [Staging](https://dashboard.stripe.com/acct_1SdTbuRvb8txnPBR/test/dashboard)
* [Production](https://dashboard.stripe.com/acct_1SNy97RwChFE4it8/dashboard)

## Working with Push Notifications

To test native push notifications (APNs and FCM) locally, start the dev server with the `--push` flag:

```sh
bin/dev --push
```

This will ask for your 1Password authorization to fetch the push credentials. Note that this loads the **production** APNs and FCM credentials into your environment.

## Environments

Mudda is deployed with [Kamal](https://kamal-deploy.org/). You'll need to have the 1Password CLI set up in order to access the secrets that are used when deploying. Provided you have that, it should be as simple as `bin/kamal deploy` to the correct environment.

## Handbook

See the [Mudda handbook](https://handbooks.37signals.works/18/mudda) for runbooks and more.

### Production

- https://app.mudda.do/

This environment uses a FlashBlade bucket for blob storage.

### Beta

Beta is primarily intended for testing product features. It uses the same production database and Active Storage configuration.

There are 4 beta environments:

- https://beta1.mudda-beta.com
- https://beta2.mudda-beta.com
- https://beta3.mudda-beta.com
- https://beta4.mudda-beta.com

Deploy with: `bin/kamal deploy -d beta1` (or `-d beta2`, `-d beta3`, `-d beta4`)

### Staging

Staging is primarily intended for testing infrastructure changes. It uses production-like but separate database and Active Storage configurations.

- https://app.mudda-staging.com/

## Maintenance mode

To take production offline for maintenance, run `kamal-proxy stop` on the load balancers via `knife ssh`:

```bash
knife ssh 'hostname:mudda-lb-*' "sudo docker exec mudda-load-balancer kamal-proxy stop mudda --message='Sorry! Mudda is undergoing some maintenance and will be back shortly.'"
```

Verify maintenance is enabled by visiting https://app.mudda.do/.

To lift maintenance mode:

```bash
knife ssh 'hostname:mudda-lb-*' 'sudo docker exec mudda-load-balancer kamal-proxy resume mudda'
```

## License

mudda-saas is released under the [O'Saasy License](LICENSE.md).
