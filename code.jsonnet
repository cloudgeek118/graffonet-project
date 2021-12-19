local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local elasticsearch = grafana.elasticsearch;
local row = grafana.row;
local annotation = grafana.annotation;
local alertlistPanel = grafana.alertlist;
local link = grafana.link;
local pspLogsDatasource = 'Holmes prd sre-payments';
dashboard.new(
  title = '61.00',
  editable = true,
  tags = ['ACI', 'payments', 'sre'],
  time_from = 'now-6h',
  schemaVersion=27,
).addAnnotation(
  annotation.datasource(
    datasource = '-- Grafana --',
    name = 'chk-api-release',
    tags = ['chkapi', 'release', 'production'],
    iconColor = '#B877D9',
    type = 'tags'
  )
).addTemplate(
  template.new(
    name = 'market',
    datasource = pspLogsDatasource,
    query = '{"find": "terms", "field": "message.ChannelName.keyword","query":"message.ChannelName:*"}',
    label = 'Market',
    regex = '',
    refresh = 1,
    allValues = '',
    includeAll = true,
    multi = true,
  )
).addTemplate(
  template.new(
    name = 'method',
    datasource = pspLogsDatasource,
    query = '{"find": "terms", "field": "message.PAYMETHOD.keyword","query":"message.PAYMETHOD:*"}',
    label = 'Payment Method',
    regex = '',
    refresh = 1,
    allValues = '',
    includeAll = true,
    multi = true,
  )
).addTemplate(
  template.new(
    name = 'error',
    datasource = pspLogsDatasource,
    query = '{"find": "terms", "field": "message.AcquirerResponseDescription.keyword","query":"message.Source:ACI AND message.PSPResponse:(100* OR 700* OR 800* OR 900*) AND NOT message.AcquirerResponse:PENDING"}',
    label = 'Error Description (Error panels only)',
    regex = '',
    refresh = 1,
    allValues = '',
    includeAll = true,
    multi = true,
  )
).addTemplate(
  template.new(
    name = 'reversal',
    datasource = pspLogsDatasource,
    query = '{"find": "terms", "field": "message.merchantMemo.keyword","query":"message.merchantMemo:*"}',
    label = 'Reversal Reason (Successful Auto-reversal only)',
    regex = '',
    refresh = 1,
    allValues = '',
    includeAll = true,
    multi = true,
  )
).addPanel(
    row.new(
        title = "General view - $market"
    )
  , { h: 1, w: 24, x: 0, y: 0 }
).addPanel(
  graphPanel.new(
    title = 'Authorisations, Reversals & Declines - $market',
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
      query = 'message.ChannelName:$market AND message.PAYMETHOD:$method AND message.Source:ACI AND message.PSPResponse:("000.000.000" OR "000.400.060" OR  "000.400.090") AND message.ResponseType:("PA" OR "DB")',
      timeField = '@timestamp',
      metrics = [{ field: 'message.MerchantRef.keyword', id: '1', meta: {}, settings: {}, type: 'cardinality' }],
      bucketAggs=[{ field: '@timestamp', id: '2', settings: { interval: '5m', min_doc_count: 0, trimEdges: 0 }, type: 'date_histogram' }],
      alias='Successfull Authorized'
    )
  ).addTarget(
    elasticsearch.target(
      query = 'message.ChannelName:$market AND message.PAYMETHOD:$method AND message.Source:ACI AND message.PSPResponse:("000.000.000" OR "000.600.000") AND (message.ResponseType:(RV OR RF) AND message.merchantMemo:*) AND NOT (message.merchantMemo:CANCELLATION OR message.merchantMemo:FRAUDULENT_ADDRESS)',
      timeField = '@timestamp',
      metrics = [{ field: 'message.MerchantRef.keyword', id: '1', meta: {}, settings: {}, type: 'cardinality' }],
      bucketAggs=[{ field: '@timestamp', id: '2', settings: { interval: '5m', min_doc_count: 0, trimEdges: 0 }, type: 'date_histogram' }],
      alias='Successful Reversals'
    )
  ).addTarget(
    elasticsearch.target(
      query = 'message.ChannelName:$market AND message.PAYMETHOD:$method AND message.Source:"ACI" AND message.ResponseType:"FZ" AND message.PSPResponse:(100.400.3* OR "100.400.500")',
      timeField = '@timestamp',
      metrics = [{ field: 'message.MerchantRef.keyword', id: '1', meta: {}, settings: {}, type: 'cardinality' }],
      bucketAggs=[{ field: '@timestamp', id: '2', settings: { interval: '5m', min_doc_count: 0, trimEdges: 0 }, type: 'date_histogram' }],
      alias='Risk Declines Feedzai'
    )
  ).addTarget(
    elasticsearch.target(
      query = 'message.ChannelName:$market AND message.PAYMETHOD:$method AND message.Source:ACI AND message.ResponseType:("PA" OR "DB") AND message.PSPResponse:(100.100.* OR "100.350.100" OR "100.380.401" OR "100.390.112" OR "100.550.300" OR "100.800.501" OR 200.100.* OR "300.100.100" OR "500.100.201" OR "600.200.500" OR "700.100.600" OR 700.400.* OR 700.500.* OR 800.100.* OR "800.500.110" OR "800.700.100" OR "800.800.202" OR "800.900.300" OR "999.999.999")',
      timeField = '@timestamp',
      metrics = [{ field: 'message.MerchantRef.keyword', id: '1', meta: {}, settings: {}, type: 'cardinality' }],
      bucketAggs=[{ field: '@timestamp', id: '2', settings: { interval: '5m', min_doc_count: 0, trimEdges: 0 }, type: 'date_histogram' }],
      alias='Bank Declines'
    )
  ).addTarget(
    elasticsearch.target(
      query = 'message.ChannelName:$market AND message.PAYMETHOD:$method AND message.Source:ACI AND ((message.ResponseType:RV) OR (message.ResponseType:RF AND message.merchantMemo:*)) AND NOT message.PSPResponse:("000.000.000" OR "000.600.000" OR "700.400.300" OR "100.350.100" OR "900.100.202")',
      timeField = '@timestamp',
      metrics = [{ field: 'message.MerchantRef.keyword', id: '1', meta: {}, settings: {}, type: 'cardinality' }],
      bucketAggs=[{ field: '@timestamp', id: '2', settings: { interval: '5m', min_doc_count: 0, trimEdges: 0 }, type: 'date_histogram' }],
      alias='Issues processing Reversal'
    )
  ).addTarget(
    elasticsearch.target(
      query = 'message.ChannelName:$market AND message.PAYMETHOD:$method AND message.Source:"ACI" AND message.ResponseType:"FO" AND message.PSPResponse:(100.400.3* OR "100.400.500")',
      timeField = '@timestamp',
      metrics = [{ field: 'message.MerchantRef.keyword', id: '1', meta: {}, settings: {}, type: 'cardinality' }],
      bucketAggs=[{ field: '@timestamp', id: '2', settings: { interval: '5m', min_doc_count: 0, trimEdges: 0 }, type: 'date_histogram' }],
      alias='Risk Declines Forter',
    )
  )
  , { h: 10, w: 16, x: 0, y: 0}
)
