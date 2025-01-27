{{/* vim: set filetype=mustache: */}}

{{/* Expand the name of the chart. */}}
{{- define "kyverno.name" -}}
{{- default "kyverno" .Values.kyverno.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kyverno.fullname" -}}
{{- if .Values.kyverno.fullnameOverride -}}
{{- .Values.kyverno.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "kyverno" .Values.kyverno.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Create chart name and version as used by the chart label. */}}
{{- define "kyverno.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Helm required labels */}}
{{- define "kyverno.labels" -}}
app.kubernetes.io/component: kyverno
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/name: {{ template "kyverno.name" . }}
app.kubernetes.io/part-of: {{ template "kyverno.name" . }}
app.kubernetes.io/version: "{{ .Chart.Version }}"
helm.sh/chart: {{ template "kyverno.chart" . }}
{{- if .Values.kyverno.customLabels }}
{{ toYaml .Values.kyverno.customLabels }}
{{- end }}
{{- end -}}

{{/* Helm required labels */}}
{{- define "kyverno.test-labels" -}}
app.kubernetes.io/component: kyverno
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/name: {{ template "kyverno.name" . }}-test
app.kubernetes.io/part-of: {{ template "kyverno.name" . }}
app.kubernetes.io/version: "{{ .Chart.Version }}"
helm.sh/chart: {{ template "kyverno.chart" . }}
{{- end -}}

{{/* matchLabels */}}
{{- define "kyverno.matchLabels" -}}
app.kubernetes.io/name: {{ template "kyverno.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Get the config map name. */}}
{{- define "kyverno.configMapName" -}}
{{- printf "%s" (default (include "kyverno.fullname" .) .Values.kyverno.config.existingConfig) -}}
{{- end -}}

{{/* Get the metrics config map name. */}}
{{- define "kyverno.metricsConfigMapName" -}}
{{- printf "%s" (default (printf "%s-metrics" (include "kyverno.fullname" .)) .Values.kyverno.config.existingMetricsConfig) -}}
{{- end -}}

{{/* Get the namespace name. */}}
{{- define "junkkyverno.namespace" -}}
{{- if .Values.kyverno.namespace -}}
    {{- .Values.kyverno.namespace -}}
{{- else -}}
    {{- .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/* Create the name of the service to use */}}
{{- define "kyverno.serviceName" -}}
{{- printf "%s-svc" (include "kyverno.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Create the name of the service account to use */}}
{{- define "kyverno.serviceAccountName" -}}
{{- if .Values.kyverno.rbac.serviceAccount.create -}}
    {{ default (include "kyverno.fullname" .) .Values.kyverno.rbac.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.kyverno.rbac.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/* Create the default PodDisruptionBudget to use */}}
{{- define "podDisruptionBudget.spec" -}}
{{- if and .Values.kyverno.podDisruptionBudget.minAvailable .Values.kyverno.podDisruptionBudget.maxUnavailable }}
{{- fail "Cannot set both .Values.kyverno.podDisruptionBudget.minAvailable and .Values.kyverno.podDisruptionBudget.maxUnavailable" -}}
{{- end }}
{{- if not .Values.kyverno.podDisruptionBudget.maxUnavailable }}
minAvailable: {{ default 1 .Values.kyverno.podDisruptionBudget.minAvailable }}
{{- end }}
{{- if .Values.kyverno.podDisruptionBudget.maxUnavailable }}
maxUnavailable: {{ .Values.kyverno.podDisruptionBudget.maxUnavailable }}
{{- end }}
{{- end }}

{{- define "kyverno.securityContext" -}}
{{- if semverCompare "<1.19" .Capabilities.KubeVersion.Version }}
{{ toYaml (omit .Values.kyverno.securityContext "seccompProfile") }}
{{- else }}
{{ toYaml .Values.kyverno.securityContext }}
{{- end }}
{{- end }}

{{- define "kyverno.testSecurityContext" -}}
{{- if semverCompare "<1.19" .Capabilities.KubeVersion.Version }}
{{ toYaml (omit .Values.kyverno.testSecurityContext "seccompProfile") }}
{{- else }}
{{ toYaml .Values.kyverno.testSecurityContext }}
{{- end }}
{{- end }}

{{- define "kyverno.imagePullSecret" }}
{{- printf "{\"auths\":{\"%s\":{\"auth\":\"%s\"}}}" .registry (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}


{{- define "kyverno.resourceFilters" -}}
{{- $resourceFilters := .Values.kyverno.config.resourceFilters }}
{{- if .Values.kyverno.excludeKyvernoNamespace }}
  {{- $resourceFilters = prepend .Values.kyverno.config.resourceFilters (printf "[*,%s,*]" (include "kyverno.namespace" .)) }}
{{- end }}
{{- range $exclude := .Values.kyverno.resourceFiltersExcludeNamespaces }}
  {{- range $filter := $resourceFilters }}
    {{- if (contains (printf ",%s," $exclude) $filter) }}
      {{- $resourceFilters = without $resourceFilters $filter }}
    {{- end }}
  {{- end }}
{{- end }}
{{- tpl (join "" $resourceFilters) . }}
{{- end }}

{{- define "kyverno.webhooks" -}}
{{- $excludeDefault := dict "key" "kubernetes.io/metadata.name" "operator" "NotIn" "values" (list (include "kyverno.namespace" .)) }}
{{- $newWebhook := list }}
{{- range $webhook := .Values.kyverno.config.webhooks }}
  {{- $namespaceSelector := default dict $webhook.namespaceSelector }}
  {{- $matchExpressions := default list $namespaceSelector.matchExpressions }}
  {{- $newNamespaceSelector := dict "matchLabels" $namespaceSelector.matchLabels "matchExpressions" (append $matchExpressions $excludeDefault) }}
  {{- $newWebhook = append $newWebhook (merge (omit $webhook "namespaceSelector") (dict "namespaceSelector" $newNamespaceSelector)) }}
{{- end }}
{{- $newWebhook | toJson }}
{{- end }}
