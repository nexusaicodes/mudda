# Mudda

**Mudda** is a Kanban tool for tracking issues and ideas — boards, cards, and a simple
fixed workflow (Triage → Backlog → Todo → Doing → Done) for teams that want to move work
without ceremony.

Mudda is built and maintained by **Nexus AI**. It is a fork of
[Fizzy](https://fizzy.do/), originally created by [37signals](https://37signals.com).
We're grateful to 37signals for releasing Fizzy as open source; Mudda continues that work
under the same [O'Saasy License](LICENSE.md).

> **Heads up:** Mudda is an early fork. Some hosting-specific values still point at
> upstream infrastructure (deploy hosts, CDNs, container registries). See
> [`CLAUDE.md`](CLAUDE.md) for the list of values you must change before running your own
> hosted deployment.


## Running your own Mudda instance

If you want to run your own Mudda instance but don't need to change its code, you can use a
pre-built Docker image. You'll need a server that can run Docker, and you'll configure a few
options to customize your installation.

See the [Docker deployment guide](docs/docker-deployment.md) for details.

If you want more flexibility to customize Mudda by changing its code and deploying those
changes, we recommend deploying with Kamal. See the [Kamal deployment guide](docs/kamal-deployment.md).


## Development

You are welcome — and encouraged — to modify Mudda to your liking.
See the [Development guide](docs/development.md) to get Mudda set up locally.

For architecture and conventions, start with [AGENTS.md](AGENTS.md) (architecture) and
[STYLE.md](STYLE.md) (house style).


## Contributing

We welcome contributions! Please read the [style guide](STYLE.md) and
[CONTRIBUTING.md](CONTRIBUTING.md) before submitting code.


## License

Mudda is released under the [O'Saasy License](LICENSE.md). The license terms are inherited
from upstream Fizzy and apply to Mudda unchanged.
