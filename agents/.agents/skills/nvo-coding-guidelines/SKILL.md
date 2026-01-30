---
name: nvo-coding-guidelines
description: NVO (Network Visibility & Orchestration) Go development guidelines. Use when writing, reviewing, or debugging NVO service code including Network, Asset, Common services. Covers clean architecture patterns, GatewayInteractor adapters, database operations (GORM), logging with traceability, error handling (NVOError), testing structure, and git/PR conventions. Triggers on NVO, GoDCApp, GoSwitch, network service, device discovery, InferredDevice, AssetDevice.
---

# NVO Coding Guidelines

Coding standards and conventions for NVO (Network Visibility & Orchestration) Go services.

## Quick Reference

| Topic | Key Rule |
|-------|----------|
| Architecture | Clean architecture + SOLID. Use GatewayInteractor adapters. |
| Functions | `context.Context` as first param. Return `NVOError`. |
| Database | Use Repository interfaces. Use `Preload(<table>)` not `clause.Associations`. |
| Logging | Get logger via `LoggerFromCtx(ctx)`. Prefix with function name. |
| Testing | Unit tests in `Test/src/test/<service>/unit`. Run before commit. |
| Commits | `NVO-1234: feat: description` (JIRA prefix + conventional commits) |

## General Go Guidelines

- Import aliases: camelCase
- Imports grouped: stdlib, third-party, internal (blank line between)
- Function names: camelCase, verbose, self-documenting
- Function size: max 100 lines, refactor if larger
- Error handling: explicit, never swallow errors
- Reference params: nil check at function start

## Architecture

Follow **clean architecture** with clear layer separation:

```
Gateway Layer (adapters)          →  translates external I/O
    ↓
Usecase Layer (business logic)    →  GatewayInteractor for dependencies  
    ↓
Domain Layer (entities/repos)     →  pure business objects
```

### GatewayInteractor Pattern

Gateway layer adapters (GoSwitch Device Adapter, REST endpoints, gRPC endpoints, message bus handlers) should:

1. Translate from gateway domain → NVO domain objects
2. Call usecase business logic function
3. Translate NVO errors/data → gateway domain response

```go
// Gateway adapter example
func (h *HTTPHandler) GetDevice(w http.ResponseWriter, r *http.Request) {
    // 1. Translate request to domain
    deviceID := extractDeviceID(r)
    
    // 2. Call usecase
    device, err := h.usecase.GetDevice(r.Context(), deviceID)
    
    // 3. Translate response
    if err != nil {
        writeNVOError(w, err)
        return
    }
    writeJSON(w, toAPIResponse(device))
}
```

## Functions

### Required Patterns

```go
// First param is always context.Context
func (uc *GatewayInteractor) ProcessDevice(ctx context.Context, device *asset.AssetDevice) apperrors.NVOError {
    // If context unused, silence linter
    _ = ctx
    
    // Nil check reference params
    if device == nil {
        return apperrors.NewNVOError(apperrors.InvalidInput, "device is nil")
    }
    
    // Business logic...
    return nil
}
```

### Error Returns

All functions returning errors MUST return `NVOError`:

```go
// Import: Common/src/infra/apperrors

// Correct
func DoSomething(ctx context.Context) apperrors.NVOError

// Wrong - never return plain error
func DoSomething(ctx context.Context) error
```

### Adding New Error Codes

Edit `Common/src/infra/apperrors/constants.go`:
- Read file to understand section structure and offsets
- Append to end of appropriate section
- NEVER insert between existing codes

## Database Operations

### Repository Pattern

Use Repository interfaces defined in domain layer:

```go
// Domain layer defines interface
type DeviceRepository interface {
    FindByMAC(ctx context.Context, mac string) (*Device, error)
    Save(ctx context.Context, device *Device) error
}

// Gateway layer implements
type GormDeviceRepository struct {
    db *gorm.DB
}
```

### Generic Database Operations

Use utilities from `Common/src/gateway/database`:

```go
import database "Common/src/gateway/database"

// Find with specific preloads (preferred)
device, err := database.FindByID[Device](ctx, db, id, 
    database.WithPreload("Ports"),
    database.WithPreload("Interfaces"),
)

// Avoid: loads ALL associations unnecessarily
device, err := database.FindByID[Device](ctx, db, id,
    database.WithPreload(clause.Associations), // Only if using 50%+ of children
)
```

### Existence Checks

```go
// Correct: use Count for existence
count, err := database.Count[Device](ctx, db, "mac_address = ?", mac)
if count > 0 {
    // exists
}

// Wrong: loading full object just to check existence
device, err := database.FindFirst[Device](ctx, db, "mac_address = ?", mac)
if device != nil {
    // wastes memory
}
```

### Transactions

```go
// Multiple reads/writes need transaction
err := database.WithTransaction(ctx, db, func(tx *gorm.DB) error {
    device, err := database.FindByID[Device](ctx, tx, id)
    if err != nil {
        return err
    }
    device.Status = newStatus
    return database.Save(ctx, tx, device)
})

// Row-level locking for read-modify-write
err := database.WithTransaction(ctx, db, func(tx *gorm.DB) error {
    device, err := database.FindByIDForUpdate[Device](ctx, tx, id) // locks row
    // modify and save...
})
```

### Save = Create or Update

```go
// database.Save handles both cases automatically
device := &Device{Name: "new"} // ID empty = CREATE
err := database.Save(ctx, db, device)

device.ID = existingID // ID populated = UPDATE  
err := database.Save(ctx, db, device)
```

## Logging

### Get Logger from Context

```go
import commonLogging "Common/src/infra/logging"

func ProcessDevice(ctx context.Context, device *Device) error {
    log := commonLogging.LoggerFromCtx(ctx) // preserves TraceID/SpanID
    
    log.Infof("ProcessDevice: starting processing for device %s", device.SerialNumber)
    // ...
}
```

**Why**: Context carries TraceID/SpanID/ParentSpanID for distributed tracing.

### Log Format

```go
// Prefix with function name + colon
log.Infof("ProcessDevice: device processed successfully")
log.Errorf("ProcessDevice: failed to save device: %v", err)

// Note: Function name in LOG only, NOT in error message
return apperrors.Wrap(err, "failed to save device") // no function prefix
```

### Log Levels

```go
// DEBUG for large object dumps (>10 attributes)
log.Debugf("ProcessDevice: device state: %+v", device)

// Use spew for pointer dereferencing
import "github.com/davecgh/go-spew/spew"
log.Debugf("ProcessDevice: full dump: %s", spew.Sdump(device))
```

### Enum Logging

```go
// Log both string and numeric value
import ccsutils "github.extremenetworks.com/Engineering/GoDCApp/NVO/Common/src/domain/models/ccs/utils"

status := device.DiscoveryStatus
log.Infof("ProcessDevice: status=%s(%d)", 
    ccsutils.GetStringFromInferredEnum(status), 
    status,
)
// Output: "ProcessDevice: status=DISCOVERY_SUCCESS(2)"
```

## Network Service Specifics

### InferredDevice Lookup

**Always query by MAC address**, not serial number:

```go
// Correct: MAC works for managed AND unmanaged devices
device, err := repo.FindByMAC(ctx, macAddress)

// Wrong: Unmanaged devices (LLDP neighbors) have no serial number
device, err := repo.FindBySerialNumber(ctx, serialNumber)
```

**Why**: Unmanaged InferredDevices (LLDP-discovered neighbors, `isManaged=false`) lack serial numbers.

## Multi-Repo Dependencies

| Repository | Contains |
|------------|----------|
| `PlatformCommonModels` | Asset/Inferred domain models |
| `PlatformServicesCommon` | Cross-service utilities |
| `GoDCApp/NVO` | NVO services (Network, Asset, Common, etc.) |

## Build & Lint

```bash
# Each service has its own lint config
# Location: <ServiceName>/src/<servicename>/.golangci.yaml

# Run before commit
cd Network/src/network
golangci-lint run
golint ./...
```

## Testing

### Directory Structure

```
Test/src/test/
├── network/
│   ├── unit/           # No external deps (except DB)
│   └── functional/     # Requires testbed
├── asset/
│   ├── unit/
│   └── functional/
└── ...
```

### Unit vs Functional

| Type | Dependencies | Location |
|------|--------------|----------|
| Unit | DB container only | `Test/src/test/<service>/unit` |
| Functional | Testbed (real/GNS3 devices) | `Test/src/test/<service>/functional` |

### Test Guidelines

```go
// Use real domain data, not random
device := &Device{
    SerialNumber: "1234AB5678",           // realistic
    MACAddress:   "00:11:22:33:44:55",    // realistic
    Platform:     "EXOS",                  // realistic
}

// Avoid time.Sleep - use synctest.Run for time control
synctest.Run(func() {
    // time bubble controlled test
})
```

### Running Tests

```bash
# Unit test dependencies
# 1. infra_database postgres container (with PlatformCommonModels schema)
# 2. tagging-service binary (from PlatformServices)

# Run single test with shorter timeout
go test -run TestDeviceDiscovery -timeout 30s ./...

# Logs written to /var/log/<service>/
tail -f /var/log/network/network.log
```

### CI Infrastructure

Jenkins pipeline per service:
- Config: `<ServiceName>/Jenkinsfile`
- Test script: `<ServiceName>/scripts/dependency_install.sh`
- Setup docs: `scripts/development/xiqemu/common_xiq_emulator_setup_readme.md`

## Git Conventions

### Commit Format

```
NVO-1234: feat: add device onboarding feature
NVO-5678: fix: resolve discovery timeout issue
NVO-9999: refactor: extract sparse device creation
```

Format: `<JIRA>: <type>: <description>`

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`

### PR Template

Location: `.github/pull_request_template.md`

**Feature PR sections**:
- `Background Context`: Why needed, system context
- `Feature`: What it does, use cases

**Bug Fix PR sections**:
- `Background Context`: How issue occurred
- `Issue`: Description (numbered if multiple)
- `Fix`: Solution and design choices (numbered if multiple)

Use tables, mermaid diagrams, and code snippets where helpful.
