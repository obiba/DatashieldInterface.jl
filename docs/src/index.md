# DatashieldInterface.jl

[![Build Status](https://github.com/obiba/DatashieldInterface.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/obiba/DatashieldInterface.jl/actions/workflows/CI.yml?query=branch%3Amain)

DatashieldInterface.jl defines the DataSHIELD client interface in Julia: a set of
`datashield_*` operations and generic `ds*` functions that downstream drivers
(e.g. DatashieldOpal.jl) implement for a specific data repository.

## Installation

```julia
using Pkg
Pkg.add("DatashieldInterface")
```

## Quick Start

```julia
using DatashieldInterface

# Build login details for an Opal server
builder = newDSLoginBuilder("opal")
builder("url", "https://opal-demo.obiba.org")
builder("user", "administrator")
builder("password", "password")
logins = build(builder)

# Open a connection through a registered driver
conn = dsConnect(logins[1])

# Work with the remote session
tables = dsListTables(conn)

dsDisconnect(conn)
```

## Testing

```bash
julia --project -e 'using Pkg; Pkg.test()'
```

See the [API Reference](api.md) for the full list of exported functions.

## License

This project is licensed under the MIT license.
