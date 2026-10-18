# API Reference

## Errors

```@docs
datashield_errors
datashield_error_messages
```

## Login Builder

```@docs
DSLoginBuilder
newDSLoginBuilder
build
```

## Connections

```@docs
datashield_connections
datashield_connections_default
datashield_connections_find
```

## Sessions

```@docs
datashield_sessions
```

## Symbols

```@docs
datashield_symbols
datashield_rm
```

## Tables, Resources and Workspaces

```@docs
datashield_tables
datashield_resources
datashield_workspaces
datashield_workspace_save
datashield_workspace_restore
datashield_workspace_rm
```

## Profiles and Status

```@docs
datashield_profiles
datashield_methods
datashield_method_status
datashield_pkg_status
datashield_pkg_check
datashield_table_status
datashield_resource_status
```

## Aggregate

```@docs
datashield_aggregate
```

## Assign

```@docs
datashield_assign
datashield_assign_table
datashield_assign_resource
datashield_assign_expr
```

## Login and Logout

```@docs
datashield_login
datashield_logout
```

## Interface Objects

```@docs
DSObject
DSDriver
DSSession
DSConnection
DSResult
```

## Generic Interface Functions

```@docs
dsConnect
dsDisconnect
dsKeepAlive
dsIsAsync
dsHasSession
dsSession
dsIsReady
dsStateMessage
dsListTables
dsHasTable
dsListResources
dsHasResource
dsListSymbols
dsRmSymbol
dsListProfiles
dsListMethods
dsListPackages
dsListWorkspaces
dsSaveWorkspace
dsRestoreWorkspace
dsRmWorkspace
dsAssignTable
dsAssignResource
dsAssignExpr
dsAggregate
dsIsCompleted
dsFetch
dsGetInfo
```

## Driver Registry

```@docs
register_driver!
get_driver
```
