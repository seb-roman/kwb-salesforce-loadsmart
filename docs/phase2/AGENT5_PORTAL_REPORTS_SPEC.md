# KWB Shipper Portal — Advanced Reports Specification

**Agent:** Agent 5  
**Date:** April 2, 2026  
**Focus:** 5 key business reports for shipper analytics

---

## Reports Overview

| Report | Purpose | Metric | Chart Type |
|--------|---------|--------|-----------|
| **On-Time Delivery %** | Compliance tracking | % on-time deliveries | Line chart (trend over time) |
| **Cost Per Mile** | Economics analysis | $/mile by load | Bar chart + table (by shipper, date range) |
| **Equipment Utilization** | Asset efficiency | Loads by equipment type | Pie chart + donut chart |
| **Top Routes** | Volume analysis | Loads by route (origin-destination) | Bar chart (top 10) |
| **Cost Trend** | Financial planning | MTD vs. prior month | Line chart (stacked by expense type) |

All reports:
- ✅ Filterable by date range, shipper, carrier, equipment type
- ✅ Exportable to PDF (with company logo + branding)
- ✅ Real-time data from Salesforce
- ✅ WCAG AA accessible
- ✅ Mobile responsive (375px to 1920px)

---

## Report 1: On-Time Delivery %

### Description
Shows percentage of loads delivered on time (actual delivery <= estimated delivery + 1 hour).

### Data Sources
```
Load__c:
  - Estimated_Delivery_DateTime__c
  - Actual_Delivery_DateTime__c (from POD__c.Pod_DateTime__c)
  - Status__c = 'DELIVERED'
  - Shipper_Account__c
```

### Formula
```
On_Time_Count = COUNT(loads where Actual_Delivery <= Estimated_Delivery + 1 hour)
Total_Count = COUNT(all completed loads in date range)
On_Time_Percentage = (On_Time_Count / Total_Count) * 100
```

### Visualization

```jsx
// Component: OnTimeDeliveryReport.jsx

export function OnTimeDeliveryReport({ shipperId, dateFrom, dateTo }) {
  const [data, setData] = useState([]);
  const [overallOnTime, setOverallOnTime] = useState(0);

  useEffect(() => {
    fetchOnTimeData(shipperId, dateFrom, dateTo).then(result => {
      setData(result.dailyData);
      setOverallOnTime(result.overallPercentage);
    });
  }, [shipperId, dateFrom, dateTo]);

  return (
    <div className="report-container">
      <h2>On-Time Delivery Performance</h2>

      {/* Key Metric Card */}
      <div className="metric-card large">
        <h3>Overall On-Time %</h3>
        <p className={`metric-value ${overallOnTime >= 95 ? 'success' : overallOnTime >= 90 ? 'warning' : 'danger'}`}>
          {overallOnTime.toFixed(1)}%
        </p>
        <p className="metric-label">
          {overallOnTime >= 95 ? '✓ Excellent' : overallOnTime >= 90 ? '⚠ Good' : '✗ Needs Improvement'}
        </p>
      </div>

      {/* Trend Chart */}
      <div className="chart-container">
        <h3>On-Time Delivery Trend</h3>
        <LineChart
          data={data}
          xKey="date"
          yKey="onTimePercentage"
          options={{
            yAxis: { domain: [0, 100] },
            tooltip: { 
              formatter: (value) => `${value.toFixed(1)}%`,
              contentStyle: { background: '#f9f9f9' }
            },
            grid: { top: '3%', bottom: '10%' }
          }}
        />
      </div>

      {/* Details Table */}
      <div className="table-container">
        <h3>Daily Breakdown</h3>
        <table className="report-table">
          <thead>
            <tr>
              <th>Date</th>
              <th>Total Deliveries</th>
              <th>On-Time</th>
              <th>Late</th>
              <th>On-Time %</th>
            </tr>
          </thead>
          <tbody>
            {data.map(row => (
              <tr key={row.date}>
                <td>{formatDate(row.date)}</td>
                <td>{row.totalDeliveries}</td>
                <td className="success">{row.onTimeCount}</td>
                <td className="danger">{row.lateCount}</td>
                <td className={row.onTimePercentage >= 95 ? 'success' : 'danger'}>
                  {row.onTimePercentage.toFixed(1)}%
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Export Button */}
      <button onClick={() => exportReportPDF('OnTimeDelivery')} className="btn-export">
        📥 Export PDF
      </button>
    </div>
  );
}

// Data Fetching
async function fetchOnTimeData(shipperId, dateFrom, dateTo) {
  const query = `
    SELECT 
      DATE(Actual_Delivery_DateTime__c) as delivery_date,
      COUNT(Id) as total_count,
      COUNT(
        CASE WHEN Actual_Delivery_DateTime__c <= 
          Estimated_Delivery_DateTime__c + 1:00:00 
        THEN 1 END
      ) as on_time_count
    FROM Load__c
    WHERE Shipper_Account__c = '${shipperId}'
      AND Status__c = 'DELIVERED'
      AND Actual_Delivery_DateTime__c >= ${dateFrom}
      AND Actual_Delivery_DateTime__c <= ${dateTo}
    GROUP BY DATE(Actual_Delivery_DateTime__c)
    ORDER BY delivery_date ASC
  `;

  const result = await soqlQuery(query);
  
  const dailyData = result.records.map(row => ({
    date: row.delivery_date,
    totalDeliveries: row.total_count,
    onTimeCount: row.on_time_count,
    lateCount: row.total_count - row.on_time_count,
    onTimePercentage: (row.on_time_count / row.total_count) * 100
  }));

  const totalOnTime = dailyData.reduce((sum, d) => sum + d.onTimeCount, 0);
  const totalDeliveries = dailyData.reduce((sum, d) => sum + d.totalDeliveries, 0);
  const overallPercentage = (totalOnTime / totalDeliveries) * 100;

  return { dailyData, overallPercentage };
}
```

---

## Report 2: Cost Per Mile

### Description
Shows transportation cost efficiency (total cost ÷ distance in miles).

### Data Sources
```
Load__c:
  - Shipper_Rate__c (revenue)
  - Distance__c (calculated from origin → destination)
  - Carrier__c
  - Status__c = 'DELIVERED'

Calculation: Cost_Per_Mile = Shipper_Rate__c / Distance__c
```

### Visualization

```jsx
// Component: CostPerMileReport.jsx

export function CostPerMileReport({ shipperId, dateFrom, dateTo, filterBy = 'load' }) {
  const [data, setData] = useState([]);
  const [avgCostPerMile, setAvgCostPerMile] = useState(0);

  useEffect(() => {
    fetchCostPerMileData(shipperId, dateFrom, dateTo, filterBy).then(result => {
      setData(result.loads);
      setAvgCostPerMile(result.average);
    });
  }, [shipperId, dateFrom, dateTo, filterBy]);

  return (
    <div className="report-container">
      <h2>Cost Per Mile Analysis</h2>

      {/* Key Metric */}
      <div className="metric-card">
        <h3>Average Cost/Mile</h3>
        <p className="metric-value">${avgCostPerMile.toFixed(2)}</p>
      </div>

      {/* Filter */}
      <div className="filter-group">
        <label>Group By:</label>
        <select value={filterBy} onChange={(e) => setFilterBy(e.target.value)}>
          <option value="load">By Load</option>
          <option value="carrier">By Carrier</option>
          <option value="equipment">By Equipment Type</option>
        </select>
      </div>

      {/* Bar Chart */}
      <div className="chart-container">
        <h3>Cost Per Mile Distribution</h3>
        {filterBy === 'load' ? (
          <BarChart
            data={data}
            xKey="loadName"
            yKey="costPerMile"
            options={{
              tooltip: {
                formatter: (value) => `$${value.toFixed(2)}/mi`
              }
            }}
          />
        ) : (
          <BarChart
            data={data}
            xKey="category"
            yKey="costPerMile"
            options={{
              tooltip: {
                formatter: (value) => `$${value.toFixed(2)}/mi`
              }
            }}
          />
        )}
      </div>

      {/* Details Table */}
      <div className="table-container">
        <h3>Cost Breakdown</h3>
        <table className="report-table">
          <thead>
            <tr>
              <th>Load #</th>
              <th>Distance (mi)</th>
              <th>Shipper Rate</th>
              <th>Cost/Mile</th>
              <th>Carrier</th>
            </tr>
          </thead>
          <tbody>
            {data.map(row => (
              <tr key={row.loadId}>
                <td>{row.loadName}</td>
                <td>{row.distance.toFixed(0)} mi</td>
                <td>${row.shipper_rate.toFixed(2)}</td>
                <td>${row.costPerMile.toFixed(2)}</td>
                <td>{row.carrier}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <button onClick={() => exportReportPDF('CostPerMile')} className="btn-export">
        📥 Export PDF
      </button>
    </div>
  );
}

// Data Fetching
async function fetchCostPerMileData(shipperId, dateFrom, dateTo, groupBy) {
  const query = `
    SELECT 
      Id, Name, Shipper_Rate__c, Distance__c,
      Carrier__r.Name, Equipment_Type__c, Actual_Delivery_DateTime__c
    FROM Load__c
    WHERE Shipper_Account__c = '${shipperId}'
      AND Status__c = 'DELIVERED'
      AND Actual_Delivery_DateTime__c >= ${dateFrom}
      AND Actual_Delivery_DateTime__c <= ${dateTo}
      AND Distance__c > 0
    ORDER BY Actual_Delivery_DateTime__c DESC
  `;

  const result = await soqlQuery(query);

  const loads = result.records.map(row => ({
    loadId: row.Id,
    loadName: row.Name,
    distance: row.Distance__c,
    shipper_rate: row.Shipper_Rate__c,
    costPerMile: row.Shipper_Rate__c / row.Distance__c,
    carrier: row.Carrier__r?.Name,
    equipmentType: row.Equipment_Type__c
  }));

  const totalCost = loads.reduce((sum, l) => sum + l.shipper_rate, 0);
  const totalMiles = loads.reduce((sum, l) => sum + l.distance, 0);
  const average = totalCost / totalMiles;

  return { loads, average };
}
```

---

## Report 3: Equipment Utilization

### Description
Shows distribution of loads by equipment type (53ft van, flatbed, etc.).

### Data Sources
```
Load__c:
  - Equipment_Type__c
  - Status__c = 'DELIVERED'
  - Shipper_Account__c
```

### Visualization

```jsx
// Component: EquipmentUtilizationReport.jsx

export function EquipmentUtilizationReport({ shipperId, dateFrom, dateTo }) {
  const [data, setData] = useState([]);
  const [totalLoads, setTotalLoads] = useState(0);

  useEffect(() => {
    fetchEquipmentData(shipperId, dateFrom, dateTo).then(result => {
      setData(result.equipmentData);
      setTotalLoads(result.totalLoads);
    });
  }, [shipperId, dateFrom, dateTo]);

  return (
    <div className="report-container">
      <h2>Equipment Utilization</h2>

      {/* Key Metric */}
      <div className="metric-card">
        <h3>Total Loads</h3>
        <p className="metric-value">{totalLoads}</p>
      </div>

      {/* Pie Chart */}
      <div className="chart-container">
        <PieChart
          data={data}
          dataKey="count"
          nameKey="equipment"
          options={{
            tooltip: {
              formatter: (value) => `${value} loads`,
              labelFormatter: (label) => label
            }
          }}
        />
      </div>

      {/* Table */}
      <div className="table-container">
        <h3>Equipment Breakdown</h3>
        <table className="report-table">
          <thead>
            <tr>
              <th>Equipment Type</th>
              <th>Count</th>
              <th>% of Total</th>
              <th>Avg Cost/Mile</th>
            </tr>
          </thead>
          <tbody>
            {data.map(row => (
              <tr key={row.equipment}>
                <td>{row.equipment}</td>
                <td>{row.count}</td>
                <td>{((row.count / totalLoads) * 100).toFixed(1)}%</td>
                <td>${row.avgCostPerMile.toFixed(2)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <button onClick={() => exportReportPDF('EquipmentUtilization')} className="btn-export">
        📥 Export PDF
      </button>
    </div>
  );
}

// Data Fetching
async function fetchEquipmentData(shipperId, dateFrom, dateTo) {
  const query = `
    SELECT 
      Equipment_Type__c,
      COUNT(Id) as load_count,
      AVG(Shipper_Rate__c / Distance__c) as avg_cost_per_mile
    FROM Load__c
    WHERE Shipper_Account__c = '${shipperId}'
      AND Status__c = 'DELIVERED'
      AND Actual_Delivery_DateTime__c >= ${dateFrom}
      AND Actual_Delivery_DateTime__c <= ${dateTo}
    GROUP BY Equipment_Type__c
    ORDER BY load_count DESC
  `;

  const result = await soqlQuery(query);

  const equipmentData = result.records.map(row => ({
    equipment: row.Equipment_Type__c || 'Unknown',
    count: row.load_count,
    avgCostPerMile: row.avg_cost_per_mile || 0
  }));

  const totalLoads = equipmentData.reduce((sum, d) => sum + d.count, 0);

  return { equipmentData, totalLoads };
}
```

---

## Report 4: Top Routes

### Description
Shows top 10 routes by load volume (origin-destination combinations).

### Data Sources
```
Load__c:
  - Pickup_City__c, Pickup_State__c
  - Delivery_City__c, Delivery_State__c
  - Status__c = 'DELIVERED'
  - Shipper_Account__c
```

### Visualization

```jsx
// Component: TopRoutesReport.jsx

export function TopRoutesReport({ shipperId, dateFrom, dateTo }) {
  const [data, setData] = useState([]);

  useEffect(() => {
    fetchTopRoutes(shipperId, dateFrom, dateTo).then(setData);
  }, [shipperId, dateFrom, dateTo]);

  return (
    <div className="report-container">
      <h2>Top Routes (by Volume)</h2>

      {/* Bar Chart */}
      <div className="chart-container">
        <BarChart
          data={data}
          xKey="route"
          yKey="count"
          options={{
            tooltip: {
              formatter: (value) => `${value} loads`
            }
          }}
        />
      </div>

      {/* Table */}
      <div className="table-container">
        <h3>Top 10 Routes</h3>
        <table className="report-table">
          <thead>
            <tr>
              <th>Route</th>
              <th>Loads</th>
              <th>Avg Distance</th>
              <th>Avg Cost/Mile</th>
              <th>On-Time %</th>
            </tr>
          </thead>
          <tbody>
            {data.map((row, index) => (
              <tr key={index}>
                <td>{row.route}</td>
                <td>{row.count}</td>
                <td>{row.avgDistance.toFixed(0)} mi</td>
                <td>${row.avgCostPerMile.toFixed(2)}</td>
                <td className={row.onTimePercentage >= 95 ? 'success' : 'danger'}>
                  {row.onTimePercentage.toFixed(1)}%
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <button onClick={() => exportReportPDF('TopRoutes')} className="btn-export">
        📥 Export PDF
      </button>
    </div>
  );
}

// Data Fetching
async function fetchTopRoutes(shipperId, dateFrom, dateTo) {
  const query = `
    SELECT 
      Pickup_City__c, Pickup_State__c,
      Delivery_City__c, Delivery_State__c,
      COUNT(Id) as load_count,
      AVG(Distance__c) as avg_distance,
      AVG(Shipper_Rate__c / Distance__c) as avg_cost_per_mile
    FROM Load__c
    WHERE Shipper_Account__c = '${shipperId}'
      AND Status__c = 'DELIVERED'
      AND Actual_Delivery_DateTime__c >= ${dateFrom}
      AND Actual_Delivery_DateTime__c <= ${dateTo}
    GROUP BY Pickup_City__c, Pickup_State__c, Delivery_City__c, Delivery_State__c
    ORDER BY load_count DESC
    LIMIT 10
  `;

  const result = await soqlQuery(query);

  const routes = result.records.map(row => ({
    route: `${row.Pickup_City__c}, ${row.Pickup_State__c} → ${row.Delivery_City__c}, ${row.Delivery_State__c}`,
    count: row.load_count,
    avgDistance: row.avg_distance,
    avgCostPerMile: row.avg_cost_per_mile,
    onTimePercentage: 95 // TODO: Calculate from actual vs. estimated
  }));

  return routes;
}
```

---

## Report 5: Cost Trend (MTD vs. Prior Month)

### Description
Financial performance comparison: month-to-date vs. prior month.

### Data Sources
```
Load__c:
  - Shipper_Rate__c
  - Status__c = 'DELIVERED'
  - Actual_Delivery_DateTime__c
  - Shipper_Account__c
```

### Visualization

```jsx
// Component: CostTrendReport.jsx

export function CostTrendReport({ shipperId }) {
  const [data, setData] = useState(null);
  const [currentMonth, setCurrentMonth] = useState(new Date());

  useEffect(() => {
    const monthStart = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), 1);
    const monthEnd = new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1, 0);
    const priorMonthStart = new Date(currentMonth.getFullYear(), currentMonth.getMonth() - 1, 1);
    const priorMonthEnd = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), 0);

    fetchCostTrendData(shipperId, monthStart, monthEnd, priorMonthStart, priorMonthEnd)
      .then(setData);
  }, [shipperId, currentMonth]);

  if (!data) return <div>Loading...</div>;

  return (
    <div className="report-container">
      <h2>Cost Trend Analysis</h2>

      <div className="month-selector">
        <button onClick={() => setCurrentMonth(new Date(currentMonth.getFullYear(), currentMonth.getMonth() - 1))}>
          ← Previous
        </button>
        <span>{formatMonth(currentMonth)}</span>
        <button onClick={() => setCurrentMonth(new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1))}>
          Next →
        </button>
      </div>

      {/* Comparison Cards */}
      <div className="comparison-cards">
        <div className="card">
          <h3>Month-to-Date</h3>
          <p className="metric-value">${data.mtdTotal.toFixed(2)}</p>
          <p className="metric-label">
            {data.mtdLoads} loads
          </p>
        </div>
        <div className="card">
          <h3>Prior Month</h3>
          <p className="metric-value">${data.priorMonthTotal.toFixed(2)}</p>
          <p className="metric-label">
            {data.priorMonthLoads} loads
          </p>
        </div>
        <div className={`card ${data.variance < 0 ? 'positive' : 'negative'}`}>
          <h3>Variance</h3>
          <p className="metric-value">{data.variance > 0 ? '+' : ''}{data.variance.toFixed(2)}%</p>
          <p className="metric-label">
            {data.variance < 0 ? '⬇ Improved' : '⬆ Increased'}
          </p>
        </div>
      </div>

      {/* Line Chart */}
      <div className="chart-container">
        <LineChart
          data={data.dailyData}
          xKey="date"
          yKey1="mtdCost"
          yKey2="priorCost"
          options={{
            tooltip: {
              formatter: (value) => `$${value.toFixed(2)}`
            }
          }}
        />
      </div>

      {/* Breakdown Table */}
      <div className="table-container">
        <h3>Daily Comparison</h3>
        <table className="report-table">
          <thead>
            <tr>
              <th>Date</th>
              <th>MTD Cost</th>
              <th>Prior Cost</th>
              <th>Variance</th>
            </tr>
          </thead>
          <tbody>
            {data.dailyData.map(row => (
              <tr key={row.date}>
                <td>{formatDate(row.date)}</td>
                <td>${row.mtdCost.toFixed(2)}</td>
                <td>${row.priorCost.toFixed(2)}</td>
                <td className={row.variance < 0 ? 'success' : 'danger'}>
                  {row.variance > 0 ? '+' : ''}{row.variance.toFixed(2)}%
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <button onClick={() => exportReportPDF('CostTrend')} className="btn-export">
        📥 Export PDF
      </button>
    </div>
  );
}
```

---

## PDF Export Functionality

```jsx
// Utility: exportReportPDF.js

import jsPDF from 'jspdf';
import html2canvas from 'html2canvas';

export async function exportReportPDF(reportName, chartElement) {
  // Create PDF document
  const pdf = new jsPDF({
    orientation: 'portrait',
    unit: 'mm',
    format: 'a4'
  });

  // Add header
  pdf.setFillColor(41, 128, 185);
  pdf.rect(0, 0, 210, 20, 'F');
  pdf.setTextColor(255, 255, 255);
  pdf.setFontSize(16);
  pdf.text('KWB Logistics', 10, 12);
  pdf.text(reportName, 10, 18);

  // Add date
  pdf.setTextColor(0, 0, 0);
  pdf.setFontSize(10);
  pdf.text(`Generated: ${new Date().toLocaleDateString()}`, 10, 25);

  // Add chart image
  if (chartElement) {
    const canvas = await html2canvas(chartElement);
    const imgData = canvas.toDataURL('image/png');
    pdf.addImage(imgData, 'PNG', 10, 35, 190, 100);
  }

  // Add footer
  pdf.setFontSize(8);
  pdf.setTextColor(128, 128, 128);
  pdf.text('Confidential - For Shipper Use Only', 10, 285);
  pdf.text(`Page 1 of 1`, 180, 285);

  // Save
  pdf.save(`${reportName}_${new Date().toISOString().split('T')[0]}.pdf`);
}
```

---

## Testing Checklist

- [ ] On-Time Delivery: Calculate correctly, display trend
- [ ] Cost Per Mile: Group by load/carrier/equipment
- [ ] Equipment Utilization: Pie chart accurate percentages
- [ ] Top Routes: Correct filtering, top 10 only
- [ ] Cost Trend: MTD vs. prior month comparison correct
- [ ] Filters: Date range, shipper, carrier filtering works
- [ ] PDF Export: PDF generated with all data, proper formatting
- [ ] Performance: Reports load < 3 sec
- [ ] Accessibility: WCAG AA, keyboard navigation
- [ ] Mobile: Responsive on 375px width

---

## Success Criteria

✅ All 5 reports generate data correctly  
✅ Charts render accurately (line, bar, pie)  
✅ Filters work (date, shipper, carrier, equipment)  
✅ PDF export includes company branding  
✅ All calculations match expectations  
✅ Mobile responsive (375px to 1920px)  
✅ WCAG AA accessibility  
✅ Load times < 3 seconds  
