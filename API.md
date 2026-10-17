# Mudda API

The JSON API's documentation lives at **<https://docs.mudda.today>**:

- [Quickstart](https://docs.mudda.today/guides/quickstart/)
- [Authentication](https://docs.mudda.today/guides/authentication/): tokens, scopes, labels, expiry
- [Cards and lanes](https://docs.mudda.today/guides/cards-and-lanes/), [Errors](https://docs.mudda.today/guides/errors/), [Pagination](https://docs.mudda.today/guides/pagination/), [Rate limits](https://docs.mudda.today/guides/rate-limits/)
- [API reference](https://docs.mudda.today/reference/): every endpoint

The reference is generated from [docs/openapi.yaml](docs/openapi.yaml), which changes in the same
commit as the endpoint it describes (see [AGENTS.md](AGENTS.md)). Self-hosted token commands
(`make token`, `make tokens`, `make revoke`, `make reset-auth`) are in
[DOCKER.md](DOCKER.md#local-development).
