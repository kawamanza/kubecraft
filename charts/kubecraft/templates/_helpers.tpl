{{- define "kubecraft.app-fullname" -}}
  {{- if .fullname }}
    {{- printf "%s" .fullname }}
  {{- else }}
    {{- $suf := (ternary (printf "-%s" $.Values.app.subset) "" (ne "main" $.Values.app.subset)) }}
    {{- printf "%s-%s%s" (default $.Release.Name $.Values.app.name) .scope $suf }}
  {{- end }}
{{- end -}}

{{- define "kubecraft.app-image" -}}
  {{- if .image }}
    {{- printf "%s" .image }}
  {{- else }}
    {{- printf "%s%s:%s" $.Values.image.registry $.Values.image.name $.Values.image.tag }}
  {{- end }}
{{- end -}}

{{- define "kubecraft.httproute-parent-ref" -}}
  {{- $gateway := .gateway -}}
  {{- $workload := .workload -}}
  {{- $parentRef := dict -}}
  {{- if kindIs "string" $gateway -}}
    {{- if not (regexMatch "^[^/[:space:]:]+(/[^/[:space:]:]+)?(:[0-9]+)?$" $gateway) -}}
      {{- required (printf "httpRoute gateway reference '%s' is invalid for workload '%s'; expected [namespace/]name[:port]" $gateway $workload) nil -}}
    {{- end -}}
    {{- $identityAndPort := splitList ":" $gateway -}}
    {{- $identity := index $identityAndPort 0 -}}
    {{- $namespaceAndName := splitList "/" $identity -}}
    {{- $_ := set $parentRef "name" (last $namespaceAndName) -}}
    {{- if eq (len $namespaceAndName) 2 -}}
      {{- $_ := set $parentRef "namespace" (first $namespaceAndName) -}}
    {{- end -}}
    {{- if eq (len $identityAndPort) 2 -}}
      {{- $_ := set $parentRef "port" (int (index $identityAndPort 1)) -}}
    {{- end -}}
  {{- else if kindIs "map" $gateway -}}
    {{- if not $gateway.name -}}
      {{- required (printf "httpRoute gateway name is required for workload '%s'" $workload) nil -}}
    {{- end -}}
    {{- $_ := set $parentRef "name" $gateway.name -}}
    {{- if $gateway.namespace }}{{- $_ := set $parentRef "namespace" $gateway.namespace }}{{- end -}}
    {{- if $gateway.sectionName }}{{- $_ := set $parentRef "sectionName" $gateway.sectionName }}{{- end -}}
    {{- if hasKey $gateway "port" -}}
      {{- if not (regexMatch "^[0-9]+$" (toString $gateway.port)) -}}
        {{- required (printf "httpRoute gateway port '%v' is invalid for workload '%s'; expected an integer from 1 to 65535" $gateway.port $workload) nil -}}
      {{- end -}}
      {{- $_ := set $parentRef "port" (int $gateway.port) -}}
    {{- end -}}
  {{- else -}}
    {{- required (printf "httpRoute gateways must be strings or maps for workload '%s'" $workload) nil -}}
  {{- end -}}
  {{- if hasKey $parentRef "port" -}}
    {{- $port := get $parentRef "port" -}}
    {{- if or (lt $port 1) (gt $port 65535) -}}
      {{- required (printf "httpRoute gateway port '%v' is invalid for workload '%s'; expected an integer from 1 to 65535" $port $workload) nil -}}
    {{- end -}}
  {{- end -}}
  {{- $parentRef | toYaml -}}
{{- end -}}

{{- define "kubecraft.app-env-vars" -}}
  {{- range $key, $value := .env }}
- name: {{ $key }}
    {{- if kindIs "string" $value }}
  value: {{ $value | quote }}
    {{- else if $value.fromFieldRef }}
  valueFrom:
    fieldRef:
      fieldPath: {{ $value.fromFieldRef }}
    {{- else }}
      {{- $value | toYaml | indent 2 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "kubecraft.overlay-env-vars" -}}
env:
  {{- range .overlays -}}
    {{- $ol_ref := ternary . (dict $.Values.app.env .) (kindIs "map" .) -}}
    {{- $ol_name := get $ol_ref $.Values.app.env }}
    {{- $ol := get $.Values.overlays (toString $ol_name) | default dict -}}
    {{- if or (not (hasKey $ol_ref $.Values.app.env)) (not (or (kindIs "bool" $ol_name) (hasKey $.Values.overlays $ol_name))) -}}
      {{- required (printf "Overlay not found: %s for %s" $ol_ref $.Values.app.env) nil -}}
    {{- end -}}
    {{- if eq "env-vars" $ol.type -}}
      {{- range $key, $value := $ol.items -}}
        {{- if kindIs "map" $value }}
  {{ $key }}:{{ $value | toYaml | nindent 4 }}
        {{- else if regexMatch "\\$\\([\\w]+\\)" $value }}
  {{ $key }}: {{ $value }}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end }}
{{- end -}}

{{- define "kubecraft.overlay-rbac" -}}
  {{- range .overlays }}
    {{- $ol_ref := ternary . (dict $.Values.app.env .) (kindIs "map" .) -}}
    {{- $ol_name := get $ol_ref $.Values.app.env }}
    {{- $ol := get $.Values.overlays (toString $ol_name) | default dict -}}
    {{- if or (not (hasKey $ol_ref $.Values.app.env)) (not (or (kindIs "bool" $ol_name) (hasKey $.Values.overlays $ol_name))) -}}
      {{- required (printf "Overlay not found: %s for %s" $ol_ref $.Values.app.env) nil -}}
    {{- end -}}
    {{- if eq "rbac" $ol.type -}}
spec:
  serviceAccountName: {{ printf "%s-%s" $.Release.Name $ol_name }}
    {{- end -}}
  {{- end }}
{{- end -}}

{{- define "kubecraft.overlay-checksum" -}}
  {{- $checksums := dict -}}
  {{- range .overlays }}
    {{- $ol_ref := ternary . (dict $.Values.app.env .) (kindIs "map" .) -}}
    {{- $ol_name := get $ol_ref $.Values.app.env }}
    {{- $ol := get $.Values.overlays (toString $ol_name) | default dict -}}
    {{- if or (not (hasKey $ol_ref $.Values.app.env)) (not (or (kindIs "bool" $ol_name) (hasKey $.Values.overlays $ol_name))) -}}
      {{- required (printf "Overlay not found: %s for %s" $ol_ref $.Values.app.env) nil -}}
    {{- end -}}
    {{- if and (not (kindIs "bool" $ol_name)) (eq (default $.Values.app.env $ol.env) $.Values.app.env) -}}
      {{- $checksum := dict -}}
      {{- if $ol.checksum }}
        {{- $_ := set $checksum "manual" $ol.checksum }}
      {{- end -}}
      {{- if eq "env-vars" $ol.type -}}
        {{- $items := dict -}}
        {{- range $env_key, $env_value := $ol.items }}
          {{- if not (or (kindIs "map" $env_value) (regexMatch "\\$\\([\\w]+\\)" $env_value) ) }}
            {{- $_ := set $items $env_key $env_value }}
          {{- end -}}
        {{- end -}}
        {{- if $items }}
          {{- $_ := set $checksum "configMap" $items }}
        {{- end -}}
      {{- else if and (eq "volume" $ol.type) (not $ol.hostPath) (not $ol.fromSecretRef) $ol.secret (kindIs "map" $ol.items) -}}
        {{- $items := dict -}}
        {{- range $k, $v := $ol.items }}
          {{- if hasSuffix ":plain" $k }}
            {{- $_ := set $items (trimSuffix ":plain" $k) (b64enc $v) }}
          {{- else }}
            {{- $_ := set $items $k $v }}
          {{- end }}
        {{- end }}
        {{- if $items }}
          {{- $_ := set $checksum "secret" $items }}
        {{- end }}
      {{- end -}}
      {{- if $checksum }}
        {{- $_ := set $checksums (toString $ol_name) $checksum }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if $checksums }}
metadata:
  annotations:
    kubecraft.io/overlays-checksum: {{ $checksums | toYaml | sha256sum }}
  {{- end }}
{{- end -}}

{{- define "kubecraft.app-env-from" -}}
  {{- range $value := .envFrom }}
    {{- $key := (index (keys $value) 0) }}
- {{ $key }}:
    name: {{ get $value $key }}
    {{- else }}
  {{- end }}
{{- end -}}

{{- define "kubecraft.overlay-env-from" -}}
envFrom:
  {{- range .overlays -}}
    {{- $ol_ref := ternary . (dict $.Values.app.env .) (kindIs "map" .) -}}
    {{- $ol_name := get $ol_ref $.Values.app.env }}
    {{- $ol := get $.Values.overlays (toString $ol_name) | default dict -}}
    {{- if or (not (hasKey $ol_ref $.Values.app.env)) (not (or (kindIs "bool" $ol_name) (hasKey $.Values.overlays $ol_name))) -}}
      {{- required (printf "Overlay not found: %s for %s" $ol_ref $.Values.app.env) nil -}}
    {{- end -}}
    {{- if eq "env-vars" $ol.type -}}
      {{- $scope := mustMergeOverwrite (deepCopy $ol) (dict "Values" $.Values "Release" $.Release "scope" $ol_name) -}}
      {{- $template_name := ternary "%s" "%s-env-vars" (kindIs "string" $ol.fullname) }}
- configMapRef: {{ printf $template_name (include "kubecraft.app-fullname" $scope) }}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "kubecraft.overlay-volumes" }}
  {{- range .overlays }}
    {{- $ol_ref := ternary . (dict $.Values.app.env .) (kindIs "map" .) -}}
    {{- $ol_name := get $ol_ref $.Values.app.env }}
    {{- $ol := get $.Values.overlays (toString $ol_name) | default dict -}}
    {{- if or (not (hasKey $ol_ref $.Values.app.env)) (not (or (kindIs "bool" $ol_name) (hasKey $.Values.overlays $ol_name))) -}}
      {{- required (printf "Overlay not found: %s for %s" $ol_ref $.Values.app.env) nil -}}
    {{- end -}}
    {{- if eq "volume" $ol.type }}
      {{- if $ol.hostPath }}
- hostPath:
    path: {{ $ol.hostPath }}
  name: {{ $ol_name }}
      {{- else if $ol.fromSecretRef }}
- name: {{ $ol_name }}
  secret:
    defaultMode: {{ $ol.defaultMode | default 420 }}
    secretName: {{ $ol.fromSecretRef }}
      {{- else if and $ol.secret (kindIs "map" $ol.items) }}
- name: {{ $ol_name }}
  secret:
    defaultMode: {{ $ol.defaultMode | default 420 }}
    secretName: {{ $ol.fullname | default (printf "%s-%s-files-%s" (default $.Release.Name $.Values.app.name) (trimSuffix "-files" $ol_name) (ternary "" $.Values.app.subset (eq "main" $.Values.app.subset))) | trimSuffix "-" }}
      {{- end -}}
    {{- end }}
  {{- end -}}
{{- end -}}

{{- define "kubecraft.overlay-volumeMounts" }}
  {{- range .overlays }}
    {{- $ol_ref := ternary . (dict $.Values.app.env .) (kindIs "map" .) -}}
    {{- $ol_name := get $ol_ref $.Values.app.env }}
    {{- $ol := get $.Values.overlays (toString $ol_name) | default dict -}}
    {{- if or (not (hasKey $ol_ref $.Values.app.env)) (not (or (kindIs "bool" $ol_name) (hasKey $.Values.overlays $ol_name))) -}}
      {{- required (printf "Overlay not found: %s for %s" $ol_ref $.Values.app.env) nil -}}
    {{- end -}}
    {{- if eq "volume" $ol.type }}
      {{- if $ol.hostPath }}
- mountPath: {{ $ol.mountPath | default $ol.hostPath }}
  name: {{ $ol_name }}
  readOnly: {{ ternary $ol.readOnly true (kindIs "bool" $ol.readOnly) | toString }}
      {{- else if $ol.fromSecretRef }}
- mountPath: {{ $ol.mountPath }}
  name: {{ $ol_name }}
  readOnly: {{ ternary $ol.readOnly true (kindIs "bool" $ol.readOnly) | toString }}
      {{- else if  and $ol.secret (kindIs "map" $ol.items) }}
- mountPath: {{ $ol.mountPath }}
  name: {{ $ol_name }}
  readOnly: {{ ternary $ol.readOnly true (kindIs "bool" $ol.readOnly) | toString }}
      {{- end -}}
    {{- end }}
  {{- end -}}
{{- end -}}
