{{- define "app.fullname" -}}
  {{- if .Values.fullname }}
    {{- printf "%s" .Values.fullname }}
  {{- else }}
    {{- $suf := (ternary (printf "-%s" .root.Values.app.subset) "" (ne "main" .root.Values.app.subset)) }}
    {{- printf "%s-%s%s" (default .root.Release.Name .root.Values.app.name) .scope $suf }}
  {{- end }}
{{- end -}}

{{- define "app.namespace" -}}
  {{- printf "%s" (default .Release.Namespace .Values.app.namespace) }}
{{- end -}}

{{- define "app.image" -}}
  {{- if .Values.image }}
    {{- printf "%s" .Values.image }}
  {{- else }}
    {{- printf "%s%s:%s" .root.Values.image.registry .root.Values.image.name .root.Values.image.tag }}
  {{- end }}
{{- end -}}

{{- define "app.env-vars" -}}
  {{- range $key, $value := .env }}
- name: {{ $key }}
    {{- if kindIs "string" $value }}
  value: {{ $value | quote }}
    {{- else if $value.fromFieldRef }}
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: {{ $value.fromFieldRef }}
    {{- else }}
      {{- $value | toYaml | nindent 2 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "app.env-from" -}}
  {{- range $value := .envFrom }}
    {{- $key := (index (keys $value) 0) }}
    {{- if kindIs "string" (get $value $key) }}
- {{ $key }}:
    name: {{ get $value $key }}
    {{- else }}
- {{ $key }}:
    {{- get $value $key | toYaml | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}
