# Kubecraft Project Conventions

## Repository Model

- `values.yaml` is a commented DDL sketch and the primary discoverability surface.
- `workloads` is a map keyed by logical component. The key is also the default operation and naming scope when `operation` or `fullname` is absent.
- Resource templates iterate over maps and render only applicable, enabled entries.
- `examples/<name>.yaml` contains input DDL; `examples/<name>-manifests.yaml` contains the corresponding `helm template` result.

## Expressive DDL Patterns

- Compact maps replace verbose Kubernetes lists where keys naturally identify entries. Example: `servicePorts.http: 8080` generates container and Service port structures.
- Suffix notation can add behavior without another nested object. Example: secret item keys ending in `:plain` are base64 encoded by the chart.
- A scalar represents the common case; a map represents the detailed case. Gateway references, local/external backends, overlays, and environment-specific selections follow this principle.
- Existing DDL owns reusable facts. A feature should reference a named `servicePorts` entry rather than repeat its numeric port.
- `extras`, `templateExtras`, and `containerExtras` preserve access to native Kubernetes fields without making the main DDL verbose.

## Scope, Names, and Merges

- `kubecraft.app-fullname` derives names from `app.name` or release name, workload scope, and non-main subset unless `fullname` is explicit.
- Generated workload resources use the release namespace and shared labels from `kubecraft.metadata-labels`.
- Use `mustMergeOverwrite` with deliberate argument order. Generated identity, selectors, and other chart invariants should override user extras.
- Remove or override fields that would violate chart invariants instead of accepting unsafe native extras silently.

## Validation Philosophy

- Optional means absent configuration renders no resource and does not impose new requirements.
- Fail during `helm template` when configuration is present but internally inconsistent.
- Do not silently select from multiple possible ports, targets, or owners.
- Error messages should state what is invalid and where it occurred.
- Workload pod templates include `kubecraft.io/overlays-checksum` when they use chart-generated ConfigMap/Secret overlays or overlays with manual `checksum`.

## HTTPRoute Reference Design

The HTTPRoute implementation demonstrates the preferred feature shape:

- `httpRoute` belongs to an enabled `operation: api` workload and creates at most one route for it.
- `gateways` accepts `[namespace/]name[:port]` or a map with `name`, `namespace`, `sectionName`, and `port`.
- A cross-namespace Gateway reference requires the Gateway listener's `allowedRoutes` to permit the HTTPRoute namespace.
- Route rules expose concise `path`, `pathType`, `method`, and named local `port` fields.
- A missing `backend` infers the workload Service; the named local port must exist in `servicePorts`.
- An explicit `backend` supports an external Service; cross-namespace usage requires an externally managed `ReferenceGrant`.
- Rule-level `extras.backendRefs` replaces inferred backend references; route-level `extras.metadata` and `extras.spec` expose native fields.
- Omitted Gateway API defaults remain omitted: `parentRefs` default to group `gateway.networking.k8s.io`, kind `Gateway`; `backendRefs` default to core group `""`, kind `Service`.
