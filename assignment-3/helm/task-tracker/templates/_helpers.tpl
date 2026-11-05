{{/*
_helpers.tpl - named templates shared by every file in templates/.
Files whose names begin with "_" never produce Kubernetes objects.
Every name is prefixed with the chart name because named templates are global.
*/}}

{{/* task-tracker.name: chart name, or nameOverride. */}}
{{- define "task-tracker.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
task-tracker.fullname: base name of every object, truncated to 63 characters
(DNS label limit). If the release name already contains the chart name, the
release name is used alone ("task-tracker", not "task-tracker-task-tracker").
*/}}
{{- define "task-tracker.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/* task-tracker.chart: "<name>-<version>" for the helm.sh/chart label ("+" is not allowed in labels). */}}
{{- define "task-tracker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* task-tracker.environment: required - no object renders without it. */}}
{{- define "task-tracker.environment" -}}
{{- required "environment must be set (dev, staging or prod)" .Values.environment }}
{{- end }}

{{/*
task-tracker.selectorLabels: the STABLE labels selectors use. Never add a
changing label (version, chart) here - Deployment.spec.selector is immutable.
Call with (dict "ctx" $ "component" "backend").
*/}}
{{- define "task-tracker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "task-tracker.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
{{- with .component }}
app.kubernetes.io/component: {{ . }}
{{- end }}
{{- end }}

{{/* task-tracker.labels: the full recommended label set for every object. */}}
{{- define "task-tracker.labels" -}}
helm.sh/chart: {{ include "task-tracker.chart" .ctx }}
{{ include "task-tracker.selectorLabels" . }}
app.kubernetes.io/version: {{ .ctx.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
app.kubernetes.io/part-of: task-tracker
dso202/environment: {{ include "task-tracker.environment" .ctx | quote }}
{{- end }}

{{/*
task-tracker.image: "<registry>/dso202-<tier>:<tag>". Call with (dict "ctx" $ "tier" "backend").
App tiers use image.tag; the database uses database.image.tag, so an
application upgrade can never replace the PostgreSQL image by accident.
Both fall back to .Chart.AppVersion.
*/}}
{{- define "task-tracker.image" -}}
{{- $tag := .ctx.Values.image.tag }}
{{- if eq .tier "db" }}{{ $tag = .ctx.Values.database.image.tag }}{{ end }}
{{- printf "%s/dso202-%s:%s" .ctx.Values.image.registry .tier ($tag | default .ctx.Chart.AppVersion) }}
{{- end }}

{{/* Object names. */}}
{{- define "task-tracker.dbName" -}}{{ include "task-tracker.fullname" . }}-db{{- end }}
{{- define "task-tracker.backendName" -}}{{ include "task-tracker.fullname" . }}-backend{{- end }}
{{- define "task-tracker.frontendName" -}}{{ include "task-tracker.fullname" . }}-frontend{{- end }}
{{- define "task-tracker.configName" -}}{{ include "task-tracker.fullname" . }}-config{{- end }}

{{/* Secret holding the DB credentials: the user's existing one, or the chart's own. */}}
{{- define "task-tracker.secretName" -}}
{{- if .Values.database.auth.existingSecret }}
{{- .Values.database.auth.existingSecret }}
{{- else }}
{{- include "task-tracker.fullname" . }}-db-credentials
{{- end }}
{{- end }}
