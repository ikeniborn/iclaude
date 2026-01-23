# Token Savings Monitoring Guide

## Overview

This guide explains how to monitor and track **token savings** achieved by TOON format in production workflows using the **Token Metrics Collector**.

**Use cases:**
- Track real-world token savings across multiple workflows
- Generate cost savings reports for management
- Identify optimization opportunities
- Monitor trends over time

---

## Quick Start

### 1. Collect Metrics from Workflow

```bash
cd skills/architecture-documentation/converters

# Collect metrics from architecture data
node token-metrics-collector.mjs collect ../examples/structured-output-example.json
```

**Output:**
```
✓ Metrics saved to history: ../examples/.metrics-history.json
  Total entries: 1

✓ Metrics collected successfully:
  Total YAML tokens: 1852
  Total TOON tokens: 1068
  Token savings: 42.3%
```

---

### 2. Generate Report

```bash
# Generate detailed report
node token-metrics-collector.mjs report ../examples/structured-output-example.json
```

**Output:**
```markdown
# Token Savings Report

**Generated:** 2026-01-23T18:00:00Z
**Project:** iclaude
**Workflow:** architecture-documentation

---

## Summary

| Metric | Value |
|--------|-------|
| **Total YAML Tokens** | 1852 |
| **Total TOON Tokens** | 1068 |
| **Absolute Savings** | 784 tokens |
| **Percentage Savings** | 42.3% |
| **API Cost Saved** | $2.35 / month |

---

## Data Breakdown

### Components

| Format | Tokens | Size (bytes) | Count | Savings |
|--------|--------|--------------|-------|---------|
| YAML/JSON | 406 | 1624 | 6 | - |
| TOON | 248 | 992 | 6 | 38.9% |

### Dependency Graph

| Format | Tokens | Size (bytes) | Nodes | Edges | Savings |
|--------|--------|--------------|-------|-------|---------|
| YAML/JSON | 223 | 890 | 6 | 7 | - |
| TOON | 114 | 456 | 6 | 7 | 48.9% |

---

## Cost Savings

**Assumptions:**
- API pricing: $0.03 per 1K tokens
- Workflow runs per month: 100

**Monthly savings:**
- Tokens saved per run: 784
- Total monthly savings: 78,400 tokens
- **Cost savings: $2.35 / month**

**Annual savings:**
- **$28.20 / year**

---

## Recommendations

✓ **Good savings** (30% < 42.3% < 50%)

**Analysis:**
- Mixed data types (components + graphs)
- Standard dataset size
- Expected performance for TOON

**Action:** Maintain current TOON usage.
```

---

### 3. View Historical Metrics

```bash
# Show last 10 workflow runs
node token-metrics-collector.mjs history
```

**Output:**
```
Historical Metrics (10 entries):

2026-01-20: iclaude - 742 tokens saved (41.2%)
2026-01-21: iclaude - 798 tokens saved (43.1%)
2026-01-22: iclaude - 765 tokens saved (40.8%)
2026-01-23: iclaude - 784 tokens saved (42.3%)
```

---

### 4. Generate Trend Report

```bash
# Generate trend analysis
node token-metrics-collector.mjs trend
```

**Output:**
```markdown
# Token Savings Trend Report

**Generated:** 2026-01-23T18:05:00Z
**Historical Data:** 10 workflow runs

---

## Trend Analysis

| Date | Project | Components | Dependencies | Total Savings | Percentage |
|------|---------|------------|--------------|---------------|------------|
| 2026-01-20 | iclaude | 6 | 7 | 742 | 41.2% |
| 2026-01-21 | iclaude | 6 | 7 | 798 | 43.1% |
| 2026-01-22 | iclaude | 6 | 7 | 765 | 40.8% |
| 2026-01-23 | iclaude | 6 | 7 | 784 | 42.3% |

---

## Statistics

| Metric | Value |
|--------|-------|
| **Average Token Savings** | 772 tokens |
| **Average Percentage Savings** | 41.9% |
| **Total Workflow Runs** | 10 |
| **Best Savings** | 43.1% |
| **Worst Savings** | 40.8% |
```

---

## Integration with Architecture Workflow

### Automatic Metrics Collection

**Add to Step 10** (Generate Structured Output) in architecture-documentation workflow:

```javascript
import { TokenMetrics } from './converters/token-metrics-collector.mjs';

// After generating TOON in Step 6b
const metrics = new TokenMetrics();
metrics.projectName = project_context.project_name;
metrics.workflowName = 'architecture-documentation';

// Add all data
metrics.addComponents(components);
metrics.addDependencyGraph(nodes, edges);

if (dataFlow) {
  metrics.addDataFlow(dataFlow);
}

if (qualityAttributes) {
  metrics.addQualityAttributes(qualityAttributes);
}

// Calculate and save
metrics.calculateTotal();
metrics.saveToHistory();

// Add to structured output
structuredOutput.architecture_documentation.formats.toon.metrics = {
  total_savings: metrics.totalStats.savedPercent,
  absolute_savings: metrics.totalStats.savedTokens,
  cost_saved_monthly: metrics.calculateCostSavings().monthlyCostSaved
};
```

**Enhanced Structured Output:**
```json
{
  "architecture_documentation": {
    "formats": {
      "toon": {
        "components_toon": "...",
        "dependency_graph_toon": "...",
        "token_savings": "42.3%",
        "size_comparison": "YAML: 1852 tokens, TOON: 1068 tokens",
        "metrics": {
          "total_savings": "42.3%",
          "absolute_savings": 784,
          "cost_saved_monthly": "$2.35"
        }
      }
    }
  }
}
```

---

## Programmatic Usage

### Collect Metrics in Code

```javascript
import { TokenMetrics } from './converters/token-metrics-collector.mjs';

// Create metrics instance
const metrics = new TokenMetrics();
metrics.projectName = 'my-project';
metrics.workflowName = 'architecture-documentation';

// Add data
const components = [
  { id: 'foo', name: 'Foo', type: 'module', path: 'foo.js', description: 'Foo module', layer: 'business' },
  { id: 'bar', name: 'Bar', type: 'module', path: 'bar.js', description: 'Bar module', layer: 'data' }
];

const nodes = [
  { id: 'foo', label: 'Foo', type: 'component', layer: 'business' },
  { id: 'bar', label: 'Bar', type: 'component', layer: 'data' }
];

const edges = [
  { from: 'foo', to: 'bar', type: 'required', description: 'Uses Bar' }
];

metrics.addComponents(components);
metrics.addDependencyGraph(nodes, edges);
metrics.calculateTotal();

// Get statistics
console.log(`Token savings: ${metrics.totalStats.savedPercent}`);
console.log(`Saved tokens: ${metrics.totalStats.savedTokens}`);

// Calculate cost savings
const costSavings = metrics.calculateCostSavings(0.03, 100);
console.log(`Monthly cost saved: $${costSavings.monthlyCostSaved}`);

// Generate report
const report = metrics.generateReport({
  apiPricePer1K: 0.03,
  runsPerMonth: 100
});

console.log(report);

// Save to history
metrics.saveToHistory();
```

---

### Load and Analyze History

```javascript
import { loadHistory, generateTrendReport } from './converters/token-metrics-collector.mjs';

// Load historical data
const history = loadHistory();

console.log(`Total workflow runs: ${history.length}`);

// Calculate average savings
const avgSavings = history.reduce((sum, e) => sum + (e.total?.savedTokens || 0), 0) / history.length;
const avgPercent = history.reduce((sum, e) => sum + parseFloat(e.total?.savedPercent || '0'), 0) / history.length;

console.log(`Average token savings: ${avgSavings.toFixed(0)} tokens`);
console.log(`Average percentage: ${avgPercent.toFixed(1)}%`);

// Generate trend report
const trendReport = generateTrendReport(history);
console.log(trendReport);
```

---

## Dashboard Integration

### Metrics API Endpoint

**Create REST API** for metrics dashboard:

```javascript
// metrics-api.mjs
import express from 'express';
import { loadHistory } from './token-metrics-collector.mjs';

const app = express();

// Get latest metrics
app.get('/api/metrics/latest', (req, res) => {
  const history = loadHistory();
  const latest = history[history.length - 1];
  res.json(latest);
});

// Get historical metrics
app.get('/api/metrics/history', (req, res) => {
  const history = loadHistory();
  res.json(history);
});

// Get summary statistics
app.get('/api/metrics/summary', (req, res) => {
  const history = loadHistory();

  const totalRuns = history.length;
  const avgSavings = history.reduce((sum, e) => sum + (e.total?.savedTokens || 0), 0) / totalRuns;
  const avgPercent = history.reduce((sum, e) => sum + parseFloat(e.total?.savedPercent || '0'), 0) / totalRuns;
  const bestSavings = Math.max(...history.map(e => parseFloat(e.total?.savedPercent || '0')));

  res.json({
    totalRuns,
    avgSavings: avgSavings.toFixed(0),
    avgPercent: avgPercent.toFixed(1) + '%',
    bestSavings: bestSavings.toFixed(1) + '%'
  });
});

app.listen(3000, () => {
  console.log('Metrics API running on http://localhost:3000');
});
```

**Usage:**
```bash
# Start API server
node metrics-api.mjs

# Query endpoints
curl http://localhost:3000/api/metrics/latest
curl http://localhost:3000/api/metrics/history
curl http://localhost:3000/api/metrics/summary
```

---

### Grafana Dashboard

**Data Source:** Prometheus + Node Exporter

**Metrics to track:**
- `toon_token_savings_percent` - Percentage savings per workflow
- `toon_token_savings_absolute` - Absolute token savings
- `toon_cost_saved_monthly` - Monthly cost savings ($)
- `toon_workflow_runs_total` - Total workflow runs

**Example Prometheus config:**
```yaml
scrape_configs:
  - job_name: 'toon-metrics'
    static_configs:
      - targets: ['localhost:3000']
```

**Grafana panels:**
1. **Token Savings Trend** (line chart)
2. **Cost Savings** (gauge)
3. **Average Savings** (stat panel)
4. **Workflow Runs** (counter)

---

## Alerting

### Set Up Alerts for Low Savings

**Scenario:** Alert when token savings drop below 30%

```javascript
import { loadHistory } from './converters/token-metrics-collector.mjs';

function checkLowSavings(threshold = 30) {
  const history = loadHistory();
  const latest = history[history.length - 1];

  const savingsPercent = parseFloat(latest.total?.savedPercent || '0');

  if (savingsPercent < threshold) {
    console.warn(`⚠️ ALERT: Token savings below threshold!`);
    console.warn(`  Current: ${savingsPercent}%`);
    console.warn(`  Threshold: ${threshold}%`);
    console.warn(`  Project: ${latest.projectName}`);

    // Send alert (email, Slack, etc.)
    sendAlert({
      title: 'Low Token Savings',
      message: `Token savings dropped to ${savingsPercent}% (threshold: ${threshold}%)`,
      project: latest.projectName,
      severity: 'warning'
    });
  } else {
    console.log(`✓ Token savings: ${savingsPercent}% (above threshold: ${threshold}%)`);
  }
}

// Run check
checkLowSavings(30);
```

**Cron job** (run after each workflow):
```bash
# Check savings after workflow completes
*/30 * * * * cd /path/to/skills/architecture-documentation/converters && node check-low-savings.mjs
```

---

## Best Practices

### 1. Collect Metrics Consistently

**Always collect metrics** after architecture-documentation workflow:
```javascript
// Add to Step 10 (structured output generation)
metrics.saveToHistory();
```

### 2. Set Realistic Cost Assumptions

**Adjust API pricing** based on actual costs:
```javascript
// Claude Opus 4.5: $0.03 per 1K input tokens
const costSavings = metrics.calculateCostSavings(0.03, 100);

// Claude Sonnet 4.5: $0.003 per 1K input tokens
const costSavingsSonnet = metrics.calculateCostSavings(0.003, 100);
```

### 3. Monitor Trends Over Time

**Track changes** in token savings:
- If savings increase → Datasets getting larger (good for TOON)
- If savings decrease → Datasets becoming more nested (consider YAML)

### 4. Generate Monthly Reports

**Automate reporting** for management:
```bash
# Generate monthly report (cron job)
0 0 1 * * cd /path/to/converters && node token-metrics-collector.mjs trend > /reports/toon-savings-$(date +\%Y-\%m).md
```

---

## Troubleshooting

### Issue: "No historical data available"

**Cause:** Metrics history file not created yet

**Solution:**
```bash
# Collect metrics manually
node token-metrics-collector.mjs collect ../examples/structured-output-example.json
```

---

### Issue: "Metrics file format invalid"

**Cause:** Corrupted `.metrics-history.json`

**Solution:**
```bash
# Backup and reset history
mv ../examples/.metrics-history.json ../examples/.metrics-history.json.bak
echo '[]' > ../examples/.metrics-history.json
```

---

### Issue: "Token savings calculation mismatch"

**Cause:** Incorrect data format

**Solution:**
```javascript
// Validate data structure
const data = { components: [...] };
const stats = calculateTokenSavings(data);

console.log('JSON tokens:', stats.jsonTokens);
console.log('TOON tokens:', stats.toonTokens);
console.log('Savings:', stats.savedPercent);
```

---

## Conclusion

Token Savings Monitoring provides:
- ✅ **Real-time tracking** of TOON token savings
- ✅ **Historical trends** for optimization
- ✅ **Cost savings reports** for management
- ✅ **Alerting** for anomalies

**Next Steps:**
1. Integrate metrics collection into architecture-documentation workflow
2. Set up automated reporting (monthly/quarterly)
3. Configure alerts for low savings (< 30%)
4. Share reports with team/management

---

**Created:** 2026-01-23
**Version:** 1.0.0
**Tools:** token-metrics-collector.mjs v1.0.0
