{{- define "kubecraft.pod-template" -}}
  {{- $app_name := include "kubecraft.app-fullname" $ }}
metadata:
  labels:
    app/name: {{ $app_name }}
    app/subset: {{ $.Values.app.subset }}
    app/realm: {{ $.Values.app.env }}
containers:
- image: {{ include "kubecraft.app-image" $ }}
  name: app
  env:
  - name: REALM_CONTEXT_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.labels["app/realm"]
  {{- if .env }}
    {{- include "kubecraft.app-env-vars" . | indent 2 }}
  {{- end }}
  {{- $ol_env_vars := include "kubecraft.overlay-env-from" . | fromYaml }}
  {{- if or .envFrom $ol_env_vars.envFrom }}
  envFrom:
    {{- include "kubecraft.app-env-from" . | indent 2 }}
    {{- include "kubecraft.app-env-from" $ol_env_vars | indent 2 }}
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
