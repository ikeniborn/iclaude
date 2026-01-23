#!/usr/bin/env node

/**
 * Token Metrics Collector - Track TOON token savings across workflows
 *
 * Collects and analyzes token savings metrics from architecture-documentation workflows.
 * Generates reports, tracks historical data, and provides recommendations.
 *
 * @module token-metrics-collector
 * @version 1.0.0
 */

import { jsonToToon, calculateTokenSavings } from './toon-converter.mjs';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * Metrics data structure
 */
class TokenMetrics {
  constructor() {
    this.timestamp = new Date().toISOString();
    this.projectName = '';
    this.workflowName = '';
    this.componentsStats = null;
    this.graphStats = null;
    this.dataFlowStats = null;
    this.qualityAttributesStats = null;
    this.totalStats = null;
  }

  /**
   * Add components metrics
   */
  addComponents(components) {
    const data = { components };
    this.componentsStats = calculateTokenSavings(data);
    this.componentsStats.count = components.length;
    return this;
  }

  /**
   * Add dependency graph metrics
   */
  addDependencyGraph(nodes, edges) {
    const data = { dependency_graph: { nodes, edges } };
    this.graphStats = calculateTokenSavings(data);
    this.graphStats.nodeCount = nodes.length;
    this.graphStats.edgeCount = edges.length;
    return this;
  }

  /**
   * Add data flow metrics
   */
  addDataFlow(dataFlow) {
    const data = { data_flow: dataFlow };
    this.dataFlowStats = calculateTokenSavings(data);
    this.dataFlowStats.stepCount = dataFlow.steps?.length || 0;
    return this;
  }

  /**
   * Add quality attributes metrics
   */
  addQualityAttributes(attributes) {
    const data = { quality_attributes: attributes };
    this.qualityAttributesStats = calculateTokenSavings(data);
    this.qualityAttributesStats.count = attributes.length;
    return this;
  }

  /**
   * Calculate total metrics
   */
  calculateTotal() {
    const allStats = [
      this.componentsStats,
      this.graphStats,
      this.dataFlowStats,
      this.qualityAttributesStats
    ].filter(Boolean);

    if (allStats.length === 0) {
      throw new Error('No metrics data available');
    }

    const totalJsonTokens = allStats.reduce((sum, stat) => sum + stat.jsonTokens, 0);
    const totalToonTokens = allStats.reduce((sum, stat) => sum + stat.toonTokens, 0);
    const totalSavedTokens = totalJsonTokens - totalToonTokens;
    const totalSavedPercent = ((totalSavedTokens / totalJsonTokens) * 100).toFixed(1) + '%';

    this.totalStats = {
      jsonTokens: totalJsonTokens,
      toonTokens: totalToonTokens,
      savedTokens: totalSavedTokens,
      savedPercent: totalSavedPercent,
      jsonSize: allStats.reduce((sum, stat) => sum + stat.jsonSize, 0),
      toonSize: allStats.reduce((sum, stat) => sum + stat.toonSize, 0)
    };

    return this;
  }

  /**
   * Calculate API cost savings
   * @param {number} apiPricePer1K - Price per 1K tokens (default: $0.03 for Claude Opus 4.5)
   * @param {number} runsPerMonth - Workflow runs per month
   */
  calculateCostSavings(apiPricePer1K = 0.03, runsPerMonth = 100) {
    if (!this.totalStats) {
      this.calculateTotal();
    }

    const savedTokensPerRun = this.totalStats.savedTokens;
    const monthlySavedTokens = savedTokensPerRun * runsPerMonth;
    const monthlyCostSaved = (monthlySavedTokens / 1000) * apiPricePer1K;
    const annualCostSaved = monthlyCostSaved * 12;

    return {
      apiPricePer1K,
      runsPerMonth,
      savedTokensPerRun,
      monthlySavedTokens,
      monthlyCostSaved: monthlyCostSaved.toFixed(2),
      annualCostSaved: annualCostSaved.toFixed(2)
    };
  }

  /**
   * Generate markdown report
   */
  generateReport(options = {}) {
    const {
      apiPricePer1K = 0.03,
      runsPerMonth = 100,
      includeHistory = false
    } = options;

    if (!this.totalStats) {
      this.calculateTotal();
    }

    const costSavings = this.calculateCostSavings(apiPricePer1K, runsPerMonth);

    let report = `# Token Savings Report

**Generated:** ${this.timestamp}
**Project:** ${this.projectName || 'Unknown'}
**Workflow:** ${this.workflowName || 'architecture-documentation'}

---

## Summary

| Metric | Value |
|--------|-------|
| **Total YAML Tokens** | ${this.totalStats.jsonTokens} |
| **Total TOON Tokens** | ${this.totalStats.toonTokens} |
| **Absolute Savings** | ${this.totalStats.savedTokens} tokens |
| **Percentage Savings** | ${this.totalStats.savedPercent} |
| **API Cost Saved** | $${costSavings.monthlyCostSaved} / month |

---

## Data Breakdown
`;

    // Components
    if (this.componentsStats) {
      report += `
### Components

| Format | Tokens | Size (bytes) | Count | Savings |
|--------|--------|--------------|-------|---------|
| YAML/JSON | ${this.componentsStats.jsonTokens} | ${this.componentsStats.jsonSize} | ${this.componentsStats.count} | - |
| TOON | ${this.componentsStats.toonTokens} | ${this.componentsStats.toonSize} | ${this.componentsStats.count} | ${this.componentsStats.savedPercent} |

`;
    }

    // Dependency Graph
    if (this.graphStats) {
      report += `
### Dependency Graph

| Format | Tokens | Size (bytes) | Nodes | Edges | Savings |
|--------|--------|--------------|-------|-------|---------|
| YAML/JSON | ${this.graphStats.jsonTokens} | ${this.graphStats.jsonSize} | ${this.graphStats.nodeCount} | ${this.graphStats.edgeCount} | - |
| TOON | ${this.graphStats.toonTokens} | ${this.graphStats.toonSize} | ${this.graphStats.nodeCount} | ${this.graphStats.edgeCount} | ${this.graphStats.savedPercent} |

`;
    }

    // Data Flow
    if (this.dataFlowStats) {
      report += `
### Data Flow

| Format | Tokens | Size (bytes) | Steps | Savings |
|--------|--------|--------------|-------|---------|
| YAML/JSON | ${this.dataFlowStats.jsonTokens} | ${this.dataFlowStats.jsonSize} | ${this.dataFlowStats.stepCount} | - |
| TOON | ${this.dataFlowStats.toonTokens} | ${this.dataFlowStats.toonSize} | ${this.dataFlowStats.stepCount} | ${this.dataFlowStats.savedPercent} |

`;
    }

    // Quality Attributes
    if (this.qualityAttributesStats) {
      report += `
### Quality Attributes

| Format | Tokens | Size (bytes) | Count | Savings |
|--------|--------|--------------|-------|---------|
| YAML/JSON | ${this.qualityAttributesStats.jsonTokens} | ${this.qualityAttributesStats.jsonSize} | ${this.qualityAttributesStats.count} | - |
| TOON | ${this.qualityAttributesStats.toonTokens} | ${this.qualityAttributesStats.toonSize} | ${this.qualityAttributesStats.count} | ${this.qualityAttributesStats.savedPercent} |

`;
    }

    // Cost Savings
    report += `
---

## Cost Savings

**Assumptions:**
- API pricing: $${costSavings.apiPricePer1K} per 1K tokens
- Workflow runs per month: ${costSavings.runsPerMonth}

**Monthly savings:**
- Tokens saved per run: ${costSavings.savedTokensPerRun}
- Total monthly savings: ${costSavings.monthlySavedTokens} tokens
- **Cost savings: $${costSavings.monthlyCostSaved} / month**

**Annual savings:**
- **$${costSavings.annualCostSaved} / year**

---

## Recommendations
`;

    const savingsPercent = parseFloat(this.totalStats.savedPercent);

    if (savingsPercent < 30) {
      report += `
⚠️ **Low savings** (${this.totalStats.savedPercent} < 30%)

**Possible reasons:**
- Small dataset (< 10 components)
- Deeply nested metadata (> 3 levels)
- Irregular schema (mixed data types)

**Action:** Consider using YAML-only for this dataset.
`;
    } else if (savingsPercent > 50) {
      report += `
✅ **Excellent savings** (${this.totalStats.savedPercent} > 50%)

**Analysis:**
- Tabular data with consistent schema
- Large dataset (${this.componentsStats?.count || 0} components)
- Nested graph structures benefit from TOON

**Action:** Continue using TOON for similar workflows.
`;
    } else {
      report += `
✓ **Good savings** (30% < ${this.totalStats.savedPercent} < 50%)

**Analysis:**
- Mixed data types (components + graphs)
- Standard dataset size
- Expected performance for TOON

**Action:** Maintain current TOON usage.
`;
    }

    report += `
---

**Report generated by:** architecture-documentation v1.2.0
**TOON library:** @toon-format/toon@2.1.0
**Converter:** toon-converter.mjs v1.0.0
`;

    return report;
  }

  /**
   * Export metrics as JSON
   */
  toJSON() {
    return {
      timestamp: this.timestamp,
      projectName: this.projectName,
      workflowName: this.workflowName,
      components: this.componentsStats,
      dependencyGraph: this.graphStats,
      dataFlow: this.dataFlowStats,
      qualityAttributes: this.qualityAttributesStats,
      total: this.totalStats
    };
  }

  /**
   * Save metrics to history file
   */
  saveToHistory(historyFile = '../examples/.metrics-history.json') {
    const historyPath = resolve(__dirname, historyFile);
    const historyDir = dirname(historyPath);

    // Create directory if not exists
    if (!existsSync(historyDir)) {
      mkdirSync(historyDir, { recursive: true });
    }

    let history = [];

    // Load existing history
    if (existsSync(historyPath)) {
      const historyContent = readFileSync(historyPath, 'utf8');
      history = JSON.parse(historyContent);
    }

    // Append new metrics
    history.push(this.toJSON());

    // Keep last 50 entries
    if (history.length > 50) {
      history = history.slice(-50);
    }

    // Save updated history
    writeFileSync(historyPath, JSON.stringify(history, null, 2));

    console.log(`✓ Metrics saved to history: ${historyPath}`);
    console.log(`  Total entries: ${history.length}`);

    return historyPath;
  }
}

/**
 * Load metrics from history file
 */
function loadHistory(historyFile = '../examples/.metrics-history.json') {
  const historyPath = resolve(__dirname, historyFile);

  if (!existsSync(historyPath)) {
    return [];
  }

  const historyContent = readFileSync(historyPath, 'utf8');
  return JSON.parse(historyContent);
}

/**
 * Generate trend report from history
 */
function generateTrendReport(history) {
  if (history.length === 0) {
    return 'No historical data available';
  }

  let report = `# Token Savings Trend Report

**Generated:** ${new Date().toISOString()}
**Historical Data:** ${history.length} workflow runs

---

## Trend Analysis

| Date | Project | Components | Dependencies | Total Savings | Percentage |
|------|---------|------------|--------------|---------------|------------|
`;

  for (const entry of history) {
    const date = entry.timestamp.split('T')[0];
    const componentCount = entry.components?.count || 0;
    const dependencyCount = entry.dependencyGraph?.edgeCount || 0;
    const totalSavings = entry.total?.savedTokens || 0;
    const percentage = entry.total?.savedPercent || '0%';

    report += `| ${date} | ${entry.projectName} | ${componentCount} | ${dependencyCount} | ${totalSavings} | ${percentage} |\n`;
  }

  // Calculate averages
  const avgSavings = history.reduce((sum, e) => sum + (e.total?.savedTokens || 0), 0) / history.length;
  const avgPercent = history.reduce((sum, e) => sum + parseFloat(e.total?.savedPercent || '0'), 0) / history.length;

  report += `
---

## Statistics

| Metric | Value |
|--------|-------|
| **Average Token Savings** | ${avgSavings.toFixed(0)} tokens |
| **Average Percentage Savings** | ${avgPercent.toFixed(1)}% |
| **Total Workflow Runs** | ${history.length} |
| **Best Savings** | ${Math.max(...history.map(e => parseFloat(e.total?.savedPercent || '0'))).toFixed(1)}% |
| **Worst Savings** | ${Math.min(...history.map(e => parseFloat(e.total?.savedPercent || '0'))).toFixed(1)}% |

---

**Generated by:** token-metrics-collector.mjs v1.0.0
`;

  return report;
}

// Export all functions
export {
  TokenMetrics,
  loadHistory,
  generateTrendReport
};

// CLI mode
if (import.meta.url === `file://${process.argv[1]}`) {
  const args = process.argv.slice(2);
  const command = args[0];

  if (!command || command === '--help' || command === '-h') {
    console.log(`
Token Metrics Collector CLI
Usage: node token-metrics-collector.mjs <command> [options]

Commands:
  collect <data.json>       Collect metrics from architecture data
  report <data.json>        Generate report from architecture data
  history                   Show historical metrics
  trend                     Generate trend report from history

Examples:
  node token-metrics-collector.mjs collect ../examples/structured-output-example.json
  node token-metrics-collector.mjs report ../examples/structured-output-example.json
  node token-metrics-collector.mjs history
  node token-metrics-collector.mjs trend
    `);
    process.exit(0);
  }

  try {
    switch (command) {
      case 'collect': {
        const dataFile = args[1];
        if (!dataFile) {
          console.error('Error: Data file required');
          process.exit(1);
        }

        const dataContent = readFileSync(dataFile, 'utf8');
        const data = JSON.parse(dataContent);

        const metrics = new TokenMetrics();
        metrics.projectName = 'iclaude';
        metrics.workflowName = 'architecture-documentation';

        // Extract data from structured output
        if (data.architecture_documentation?.formats?.toon) {
          // Already in TOON format - parse back to get components
          console.log('⚠ Data already in TOON format - metrics already calculated');
          console.log('Token savings:', data.architecture_documentation.formats.toon.token_savings);
          process.exit(0);
        }

        // Collect metrics
        if (data.architecture?.components) {
          metrics.addComponents(data.architecture.components);
        }

        if (data.architecture?.dependency_graph) {
          const { nodes, edges } = data.architecture.dependency_graph;
          metrics.addDependencyGraph(nodes, edges);
        }

        metrics.calculateTotal();

        // Save to history
        metrics.saveToHistory();

        console.log('\n✓ Metrics collected successfully:');
        console.log(`  Total YAML tokens: ${metrics.totalStats.jsonTokens}`);
        console.log(`  Total TOON tokens: ${metrics.totalStats.toonTokens}`);
        console.log(`  Token savings: ${metrics.totalStats.savedPercent}`);

        break;
      }

      case 'report': {
        const dataFile = args[1];
        if (!dataFile) {
          console.error('Error: Data file required');
          process.exit(1);
        }

        const dataContent = readFileSync(dataFile, 'utf8');
        const data = JSON.parse(dataContent);

        const metrics = new TokenMetrics();
        metrics.projectName = 'iclaude';
        metrics.workflowName = 'architecture-documentation';

        // Collect metrics (same as above)
        if (data.architecture?.components) {
          metrics.addComponents(data.architecture.components);
        }

        if (data.architecture?.dependency_graph) {
          const { nodes, edges } = data.architecture.dependency_graph;
          metrics.addDependencyGraph(nodes, edges);
        }

        metrics.calculateTotal();

        // Generate and display report
        const report = metrics.generateReport();
        console.log(report);

        break;
      }

      case 'history': {
        const history = loadHistory();

        if (history.length === 0) {
          console.log('No historical data available');
          process.exit(0);
        }

        console.log(`\nHistorical Metrics (${history.length} entries):\n`);

        for (const entry of history.slice(-10)) {
          const date = entry.timestamp.split('T')[0];
          const savings = entry.total?.savedPercent || '0%';
          const tokens = entry.total?.savedTokens || 0;

          console.log(`${date}: ${entry.projectName} - ${tokens} tokens saved (${savings})`);
        }

        break;
      }

      case 'trend': {
        const history = loadHistory();
        const trendReport = generateTrendReport(history);
        console.log(trendReport);
        break;
      }

      default:
        console.error(`Unknown command: ${command}`);
        process.exit(1);
    }
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}
