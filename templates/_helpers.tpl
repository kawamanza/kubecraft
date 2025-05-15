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
    {{- $ol_name := get (ternary . (dict $.Values.app.env .) (kindIs "map" .)) $.Values.app.env | default (toString .) -}}
    {{- $ol := get $.Values.overlays $ol_name -}}
    {{- if not $ol -}}
      {{- required (printf "Overlay not found: '%s' for %s" $ol_name $.Values.app.env) $ol -}}
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
    {{- $ol_name := get (ternary . (dict $.Values.app.env .) (kindIs "map" .)) $.Values.app.env | default (toString .) -}}
    {{- $ol := get $.Values.overlays $ol_name -}}
    {{- if not $ol -}}
      {{- required (printf "Overlay not found: '%s' for %s" $ol_name $.Values.app.env) $ol -}}
    {{- end -}}
    {{- if eq "env-vars" $ol.type -}}
      {{- $scope := mustMergeOverwrite (deepCopy $ol) (dict "Values" $.Values "Release" $.Release "scope" $ol_name) -}}
      {{- $template_name := ternary "%s" "%s-env-vars" (kindIs "string" $ol.fullname) }}
- configMapRef: {{ printf $template_name (include "kubecraft.app-fullname" $scope) }}
    {{- end -}}
  {{- end -}}
{{- end -}}
