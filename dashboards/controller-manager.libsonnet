local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local singlestat = grafana.singlestat;

{
  grafanaDashboards+:: {
    [if $._config.dashboards.controller_manager_enabled then 'controller-manager.json']:
      local upCount =
        singlestat.new(
          'Up',
          datasource='$datasource',
          span=2,
          valueName='min',
        )
        .addTarget(prometheus.target('sum(up{%(clusterLabel)s="$cluster", %(kubeControllerManagerSelector)s})' % $._config));

      local workQueueAddRate =
        graphPanel.new(
          'Work Queue Add Rate',
          datasource='$datasource',
          span=10,
          format='ops',
          legend_show=true,
          legend_values=true,
          legend_current=true,
          legend_alignAsTable=true,
          legend_rightSide=true,
        )
        .addTarget(prometheus.target('sum(rate(workqueue_adds_total{%(clusterLabel)s="$cluster", %(kubeControllerManagerSelector)s, instance=~"$instance"}[5m])) by (%(clusterLabel)s, instance, name)' % $._config, legendFormat='{{%(clusterLabel)s}} {{instance}} {{name}}' % $._config));

      local workQueueDepth =
        graphPanel.new(
          'Work Queue Depth',
          datasource='$datasource',
          span=12,
          min=0,
          format='short',
          legend_show=true,
          legend_values=true,
          legend_current=true,
          legend_alignAsTable=true,
          legend_rightSide=true,
        )
        .addTarget(prometheus.target('sum(rate(workqueue_depth{%(clusterLabel)s="$cluster", %(kubeControllerManagerSelector)s, instance=~"$instance"}[5m])) by (%(clusterLabel)s, instance, name)' % $._config, legendFormat='{{%(clusterLabel)s}} {{instance}} {{name}}' % $._config));

      local workQueueLatency =
        graphPanel.new(
          'Work Queue Latency',
          datasource='$datasource',
          span=12,
          format='s',
          legend_show=true,
          legend_values=true,
          legend_current=true,
          legend_alignAsTable=true,
          legend_rightSide=true,
        )
        .addTarget(prometheus.target('histogram_quantile(0.99, sum(rate(workqueue_queue_duration_seconds_bucket{%(clusterLabel)s="$cluster", %(kubeControllerManagerSelector)s, instance=~"$instance"}[5m])) by (%(clusterLabel)s, instance, name, le))' % $._config, legendFormat='{{%(clusterLabel)s}} {{instance}} {{name}}' % $._config));

      local rpcRate =
        graphPanel.new(
          'Kube API Request Rate',
          datasource='$datasource',
          span=4,
          format='ops',
        )
        .addTarget(prometheus.target('sum(rate(rest_client_requests_total{%(kubeControllerManagerSelector)s, instance=~"$instance",code=~"2.."}[5m]))' % $._config, legendFormat='2xx'))
        .addTarget(prometheus.target('sum(rate(rest_client_requests_total{%(kubeControllerManagerSelector)s, instance=~"$instance",code=~"3.."}[5m]))' % $._config, legendFormat='3xx'))
        .addTarget(prometheus.target('sum(rate(rest_client_requests_total{%(kubeControllerManagerSelector)s, instance=~"$instance",code=~"4.."}[5m]))' % $._config, legendFormat='4xx'))
        .addTarget(prometheus.target('sum(rate(rest_client_requests_total{%(kubeControllerManagerSelector)s, instance=~"$instance",code=~"5.."}[5m]))' % $._config, legendFormat='5xx'));

      local postRequestLatency =
        graphPanel.new(
          'Post Request Latency 99th Quantile',
          datasource='$datasource',
          span=8,
          format='s',
          min=0,
        )
        .addTarget(prometheus.target('histogram_quantile(0.99, sum(rate(rest_client_request_duration_seconds_bucket{%(clusterLabel)s="$cluster", %(kubeControllerManagerSelector)s, instance=~"$instance", verb="POST"}[5m])) by (verb, url, le))' % $._config, legendFormat='{{verb}} {{url}}'));

      local getRequestLatency =
        graphPanel.new(
          'Get Request Latency 99th Quantile',
          datasource='$datasource',
          span=12,
          format='s',
          min=0,
          legend_show=true,
          legend_values=true,
          legend_current=true,
          legend_alignAsTable=true,
          legend_rightSide=true,
        )
        .addTarget(prometheus.target('histogram_quantile(0.99, sum(rate(rest_client_request_duration_seconds_bucket{%(clusterLabel)s="$cluster", %(kubeControllerManagerSelector)s, instance=~"$instance", verb="GET"}[5m])) by (verb, url, le))' % $._config, legendFormat='{{verb}} {{url}}'));

      local memory =
        graphPanel.new(
          'Memory',
          datasource='$datasource',
          span=4,
          format='bytes',
        )
        .addTarget(prometheus.target('process_resident_memory_bytes{%(clusterLabel)s="$cluster", %(kubeControllerManagerSelector)s,instance=~"$instance"}' % $._config, legendFormat='{{instance}}'));

      local cpu =
        graphPanel.new(
          'CPU usage',
          datasource='$datasource',
          span=4,
          format='short',
          min=0,
        )
        .addTarget(prometheus.target('rate(process_cpu_seconds_total{%(clusterLabel)s="$cluster", %(kubeControllerManagerSelector)s,instance=~"$instance"}[5m])' % $._config, legendFormat='{{instance}}'));

      local goroutines =
        graphPanel.new(
          'Goroutines',
          datasource='$datasource',
          span=4,
          format='short',
        )
        .addTarget(prometheus.target('go_goroutines{%(clusterLabel)s="$cluster", %(kubeControllerManagerSelector)s,instance=~"$instance"}' % $._config, legendFormat='{{instance}}'));


      dashboard.new(
        '%(dashboardNamePrefix)sController Manager' % $._config.grafanaK8s,
        time_from='now-1h',
        uid=($._config.grafanaDashboardIDs['controller-manager.json']),
        tags=($._config.grafanaK8s.dashboardTags),
      ).addTemplate(
        {
          current: {
            text: 'default',
            value: 'default',
          },
          hide: 0,
          label: null,
          name: 'datasource',
          options: [],
          query: 'prometheus',
          refresh: 1,
          regex: '',
          type: 'datasource',
        },
      )
      .addTemplate(
        template.new(
          'cluster',
          '$datasource',
          'label_values(kube_pod_info, %(clusterLabel)s)' % $._config,
          label='cluster',
          refresh='time',
          hide=if $._config.showMultiCluster then '' else 'variable',
          sort=1,
        )
      )
      .addTemplate(
        template.new(
          'instance',
          '$datasource',
          'label_values(process_cpu_seconds_total{%(clusterLabel)s="$cluster", %(kubeControllerManagerSelector)s}, instance)' % $._config,
          refresh='time',
          includeAll=true,
          sort=1,
        )
      )
      .addRow(
        row.new()
        .addPanel(upCount)
        .addPanel(workQueueAddRate)
      ).addRow(
        row.new()
        .addPanel(workQueueDepth)
      ).addRow(
        row.new()
        .addPanel(workQueueLatency)
      ).addRow(
        row.new()
        .addPanel(rpcRate)
        .addPanel(postRequestLatency)
      ).addRow(
        row.new()
        .addPanel(getRequestLatency)
      ).addRow(
        row.new()
        .addPanel(memory)
        .addPanel(cpu)
        .addPanel(goroutines)
      ) + { refresh: $._config.grafanaK8s.refresh },
  },
}
