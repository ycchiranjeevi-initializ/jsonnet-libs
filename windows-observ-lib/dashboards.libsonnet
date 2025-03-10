local g = import './g.libsonnet';
local logslib = import 'github.com/grafana/jsonnet-libs/logs-lib/logs/main.libsonnet';
{
  local root = self,
  new(this):
    local prefix = this.config.dashboardNamePrefix;
    local links = this.grafana.links;
    local tags = this.config.dashboardTags;
    local uid = g.util.string.slugify(this.config.uid);
    local vars = this.grafana.variables;
    local annotations = this.grafana.annotations;
    local refresh = this.config.dashboardRefresh;
    local period = this.config.dashboardPeriod;
    local timezone = this.config.dashboardTimezone;
    local panels = this.grafana.panels;
    local stat = g.panel.stat;
    {
      fleet:
        local title = prefix + 'Windows fleet overview';
        g.dashboard.new(title)
        + g.dashboard.withPanels(
          g.util.grid.wrapPanels(
            [
              // g.panel.row.new("Overview"),
              panels.fleetOverviewTable { gridPos+: { w: 24, h: 16 } },
              panels.cpuUsageTopk { gridPos+: { w: 24 } },
              panels.memotyUsageTopKPercent { gridPos+: { w: 24 } },
              panels.diskIOutilPercentTopK { gridPos+: { w: 12 } },
              panels.diskUsagePercentTopK { gridPos+: { w: 12 } },
              panels.networkErrorsAndDroppedPerSecTopK { gridPos+: { w: 24 } },
            ], 12, 7
          )
        )
        // hide link to self
        + root.applyCommon(vars.multiInstance, uid + '-fleet', tags, links { backToFleet+:: {}, backToOverview+:: {} }, annotations, timezone, refresh, period),
      overview: g.dashboard.new(prefix + 'Windows overview')
                + g.dashboard.withPanels(
                  g.util.grid.wrapPanels(
                    [
                      g.panel.row.new('Overview'),
                      panels.uptime,
                      panels.hostname,
                      panels.osVersion,
                      panels.osInfo,
                      panels.cpuCount,
                      panels.memoryTotalBytes,
                      panels.memoryPageTotalBytes,
                      panels.diskTotalC,
                      g.panel.row.new('CPU'),
                      panels.cpuUsageStat { gridPos+: { w: 6, h: 6 } },
                      panels.cpuUsageTs { gridPos+: { w: 18, h: 6 } },
                      g.panel.row.new('Memory'),
                      panels.memoryUsageStatPercent { gridPos+: { w: 6, h: 6 } },
                      panels.memoryUsageTsBytes { gridPos+: { w: 18, h: 6 } },
                      g.panel.row.new('Disk'),
                      panels.diskIOBytesPerSec { gridPos+: { w: 12, h: 8 } },
                      panels.diskUsage { gridPos+: { w: 12, h: 8 } },
                      g.panel.row.new('Network'),
                      panels.networkUsagePerSec { gridPos+: { w: 12, h: 8 } },
                      panels.networkErrorsAndDroppedPerSec { gridPos+: { w: 12, h: 8 } },
                    ], 6, 2
                  )
                )
                + root.applyCommon(vars.singleInstance, uid + '-overview', tags, links { backToOverview+:: {} }, annotations, timezone, refresh, period),

      // add TODO advanced memory dashboard (must enable memory collector)
      // memory:

      system: g.dashboard.new(prefix + 'Windows CPU and system')
              + g.dashboard.withPanels(
                g.util.grid.wrapPanels(
                  [
                    g.panel.row.new('System'),
                    panels.cpuUsageStat { gridPos+: { w: 6, h: 6 } },
                    panels.cpuUsageTs { gridPos+: { w: 9, h: 6 } },
                    panels.cpuUsageByMode { gridPos+: { w: 9, h: 6 } },
                    panels.cpuQueue,
                    panels.systemContextSwitchesAndInterrupts,
                    // panels.systemThreads,
                    // panels.systemExceptions,
                    g.panel.row.new('Time'),
                    panels.osTimezone { gridPos+: { w: 3, h: 4 } },
                    panels.timeNtpStatus { gridPos+: { x: 0, y: 0, w: 21, h: 4 } },
                    panels.timeNtpDelay { gridPos+: { w: 24, h: 7 } },
                  ], 12, 7
                )
              )
              + root.applyCommon(vars.singleInstance, uid + '-system', tags, links, annotations, timezone, refresh, period),

      disks: g.dashboard.new(prefix + 'Windows disks and filesystems')
             + g.dashboard.withPanels(
               g.util.grid.wrapPanels(
                 [
                   g.panel.row.new('Disk'),
                   panels.diskFreeTs,
                   panels.diskUsage,
                   panels.diskIOBytesPerSec,
                   panels.diskIOps,
                   panels.diskIOWaitTime,
                   panels.diskQueue,
                 ], 12, 8
               )
             )
             + root.applyCommon(vars.singleInstance, uid + '-disks', tags, links, annotations, timezone, refresh, period),
    }
    +
    if this.config.enableLokiLogs
    then
      {
        logs:
          logslib.new(
            prefix + 'Windows logs',
            datasourceName=this.grafana.variables.datasources.loki.name,
            datasourceRegex=this.grafana.variables.datasources.loki.regex,
            filterSelector=this.config.filteringSelector,
            labels=this.config.groupLabels + this.config.instanceLabels + this.config.extraLogLabels,
            formatParser='json',
            showLogsVolume=this.config.showLogsVolume,
            logsVolumeGroupBy=this.config.logsVolumeGroupBy,
            extraFilters=this.config.logsExtraFilters
          )
          {
            dashboards+:
              {
                logs+:
                  // reference to self, already generated variables, to keep them, but apply other common data in applyCommon
                  root.applyCommon(super.logs.templating.list, uid=uid + '-logs', tags=tags, links=links, annotations=annotations, timezone=timezone, refresh=refresh, period=period),
              },
            panels+:
              {
                // modify log panel
                logs+:
                  g.panel.logs.options.withEnableLogDetails(true)
                  + g.panel.logs.options.withShowTime(false)
                  + g.panel.logs.options.withWrapLogMessage(false),
              },
            variables+: {
              // add prometheus datasource for annotations processing
              toArray+: [
                this.grafana.variables.datasources.prometheus { hide: 2 },
              ],
            },
          }.dashboards.logs,
      }
    else {},
  applyCommon(vars, uid, tags, links, annotations, timezone, refresh, period):
    g.dashboard.withTags(tags)
    + g.dashboard.withUid(uid)
    + g.dashboard.withLinks(std.objectValues(links))
    + g.dashboard.withTimezone(timezone)
    + g.dashboard.withRefresh(refresh)
    + g.dashboard.time.withFrom(period)
    + g.dashboard.withVariables(vars)
    + g.dashboard.withAnnotations(std.objectValues(annotations)),
}
