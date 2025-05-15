{{- define "kubecraft.metadata-labels" -}}
  {{- $app_name := include "kubecraft.app-fullname" $ }}
labels:
  app/name: {{ $app_name }}
  app/subset: {{ $.Values.app.subset }}
  app/realm: {{ $.Values.app.env }}
{{- end -}}

{{- define "kubecraft.pod-template" }}
metadata:
  {{- include "kubecraft.metadata-labels" $ | indent 2 }}
containers:
- image: {{ include "kubecraft.app-image" $ }}
  name: app
  {{- if .command }}
  command:
    {{- .command | toYaml | nindent 2 }}
  {{- end }}
  env:
  - name: REALM_CONTEXT_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.labels["app/realm"]
  {{- include "kubecraft.app-env-vars" . | indent 2 }}
  {{- $ol_env_vars := include "kubecraft.overlay-env-vars" . | fromYaml }}
  {{- include "kubecraft.app-env-vars" $ol_env_vars | indent 2 }}
  {{- $ol_env_from := include "kubecraft.overlay-env-from" . | fromYaml }}
  {{- if or .envFrom $ol_env_from.envFrom }}
  envFrom:
    {{- include "kubecraft.app-env-from" $ol_env_from | indent 2 }}
    {{- include "kubecraft.app-env-from" . | indent 2 }}
  {{- end }}
  {{- $resources := get ($.Values.resources | default dict) (default .scope .resources) }}
  {{- if $resources }}
    {{- with default $resources (get $resources $.Values.app.env) }}
  resources:
      {{- dict "requests" .requests "limits" .limits | toYaml | nindent 4 }}
    {{- end }}
  {{- else if .resources }}
    {{- required (printf "Resources from scope '%s' not found" .resources) nil }}
  {{- end }}
  {{- if and .probes (index $.Values.probes .probes) }}
    {{- $probes := (index $.Values.probes .probes) }}
    {{- if or $probes.liveness $probes.default }}
  livenessProbe:
      {{- $probes.liveness | default $probes.default | toYaml | nindent 4 }}
    {{- end }}
    {{- if or $probes.readiness $probes.default }}
  readinessProbe:
      {{- $probes.readiness | default $probes.default | toYaml | nindent 4 }}
    {{- end }}
    {{- if $probes.startup }}
  startupProbe:
      {{- $probes.startup | default $probes.default | toYaml | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- if .servicePorts }}
  ports:
    {{- range $portName, $portValue := .servicePorts }}
  - containerPort: {{ $portValue }}
    name: {{ regexReplaceAll "/[^/]+$" $portName "" }}
    protocol: {{ ternary "UDP" "TCP" (hasSuffix "/UDP" $portName) }}
    {{- end }}
  {{- end }}
{{- end -}}
