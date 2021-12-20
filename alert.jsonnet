local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local elasticsearch = grafana.elasticsearch;
local row = grafana.row;
local annotation = grafana.annotation;
local alertlistPanel = grafana.alertlist;
local link = grafana.link;
local countries = import 'vars/countries.jsonnet';
local global = import 'vars/global.jsonnet';
local pspLogsDatasource = 'Holmes prd sre-payments';

local addMarket(market, pm) = graphPanel.new(
    title = 'dashboard for test alerting',
    nullPointMode = "null as zero",
    datasource = pspLogsDatasource,
    fill = 1,
    sort='decreasing',
    legend_rightSide=true,
    legend_values=true,
    legend_show=true,
    legend_total=true,
    legend_alignAsTable=true,
    legend_sort='current',
    legend_sortDesc=true,
    legend_hideEmpty=true,
    legend_hideZero=true,
).addTarget(
    elasticsearch.target(
      query = 'message.MerchantAccount:"' + market.name + '" AND message.PAYMETHOD:"' + pm + '" AND message.Source:ADYEN AND message.AdyenEventCode:"CANCEL_OR_REFUND" AND message.MerchantRef:("Reason*" OR "Refund/cancel missing order") AND NOT message.Metadata_ishypeorder:* AND NOT message.ShopperInteraction:"POS"',
      timeField = '@timestamp',
      metrics = [{ field: 'message.PSPReference.keyword', id: '1', meta: {}, settings: {}, type: 'cardinality' }],
      bucketAggs=[{ field: '@timestamp', id: '2', settings: { interval: '10m', min_doc_count: 0, trimEdges: 0 }, type: 'date_histogram' }],
    )
).addAlert(
   name = 'Test-reversal dashboard',
   executionErrorState = 'keep_state',
   frequency = '10m',
   forDuration = '10m',
   handler = 1,
   alertRuleTags={
     "Team": "Payments_SRE",
     "metric": "reversal" 
   },
   notifications = [
       {
         "uid": global.notificationsChannels.orgSRE.paymentsSRE.uid
       } 
   ]
).addCondition(
    grafana.alertCondition.new(
       evaluatorParams = 4,
       evaluatorType = 'gt',
       queryRefId = 'A',
       queryTimeEnd = 'now',
       queryTimeStart = '20m'
    )
)
+ (import 'vars/extra-options.jsonnet');

dashboard.new(
  title = 'test-sre(vijay)',
  editable = true,
  tags = ['ADYEN', 'payments', 'sre'],
  time_from = 'now-1d',
).addAnnotation(
  annotation.datasource(
    datasource = '-- Grafana --',
    name = 'chk-api-release',
    tags = ['chkapi', 'release', 'production'],
    iconColor = '#B877D9',
    type = 'tags'
  )
).addRow(
    row.new(
       title="all-market"
    ).addPanels(
      [ 
         addMarket(market, pm) { gridPos: { h: 8, w: 24, x:0, y:0} },
         for market in countries.countries if (market.psp=="adyen" && (market.channel=="app" || market.channel=="both"))
         for pm in market.paymentMethods if std.member(countries.creditCardPaymentMethods,pm)
      ]
    )
)
