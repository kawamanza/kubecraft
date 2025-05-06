{{- define "kubecraft.app-fullname" -}}
  {{- if .fullname }}
    {{- printf "%s" .fullname }}
  {{- else }}
    {{- $suf := (ternary (printf "-%s" $.Values.app.subset) "" (ne "main" $.Values.app.subset)) }}
    {{- printf "%s-%s%s" (default $.Release.Name $.Values.app.name) .scope $suf }}
  {{- end }}
{{- end -}}

{{- define "kubecraft.app-namespace" -}}
  {{- printf "%s" (default $.Release.Namespace $.Values.app.namespace) }}
{{- end -}}

{{- define "kubecraft.app-image" -}}
  {{- if .image }}
    {{- printf "%s" .image }}
  {{- else }}
    {{- printf "%s%s:%s" $.Values.image.registry $.Values.image.name $.Values.image.tag }}
  {{- end }}
{{- end -}}

{{- define "kubecraft.app-env-vars" -}}
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
      {{- $value | toYaml | indent 2 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "kubecraft.app-env-from" -}}
  {{- range $value := .envFrom }}
    {{- $key := (index (keys $value) 0) }}
    {{- if kindIs "string" (get $value $key) }}
- {{ $key }}:
    name: {{ get $value $key }}
    {{- else }}
- {{ $key }}:
    {{- get $value $key | toYaml | indent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}
