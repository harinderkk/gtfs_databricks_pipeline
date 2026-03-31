# bc_transit dbt Project

Transformation layer on top of the Databricks Gold layer for the BC Transit GTFS pipeline.



## What this does

The Databricks notebooks (1–5) produce three Gold tables in `bc_transit_ws.gold`:
- `fact_trip_schedule` — every scheduled stop visit, enriched with route/stop/calendar info
- `live_positions` — real-time vehicle positions enriched with route context (appended ~3x/day)
- `dim_date` — date dimension

This dbt project adds a **marts** layer (`bc_transit_ws.marts.*`) with three analytical models:

| Model | Description |
|---|---|
| `mart_route_reliability` | Route Reliability Index — weighted coverage score per route |
| `mart_live_vehicle_map` | Latest GPS position per active vehicle (2-hr window) |
| `mart_scheduled_service_summary` | Static route catalogue with trip counts and service days |




## Project structure

```
models/
  staging/
    sources.yml          ← declares bc_transit_ws.gold.* as dbt sources
  marts/
    mart_route_reliability.sql
    mart_live_vehicle_map.sql
    mart_scheduled_service_summary.sql
    schema.yml           ← model docs + tests
```




## Setup

### 1. Install dbt-databricks

```bash
pip install dbt-databricks
```

### 2. Configure connection

Copy `profiles.yml` to `~/.dbt/profiles.yml` (or let dbt Cloud manage it), then set environment variables:

```bash
export DBT_DATABRICKS_HOST="adb-xxxx.azuredatabricks.net"
export DBT_DATABRICKS_HTTP_PATH="/sql/1.0/warehouses/xxxx"
export DBT_DATABRICKS_TOKEN="dapi..."
```

In dbt Cloud, enter these directly in the connection settings screen.

### 3. Test connection

```bash
dbt debug
```

### 4. Run

```bash
dbt run                  # build all mart tables
dbt test                 # run schema tests
dbt docs generate        # generate lineage docs
dbt docs serve           # view docs locally
```

To run a single model:
```bash
dbt run --select mart_route_reliability
```

## Reliability Score methodology

`mart_route_reliability` computes a weighted composite per route:

```
reliability_score = (peak_coverage  × 0.40)
                  + (offpeak_coverage × 0.35)
                  + (weekend_coverage × 0.25)
```

Coverage per bucket = `observed_trips_per_day / scheduled_trips_per_day × 100`, capped at 100.

Time buckets:
- **weekday_peak**: hours 7, 8, 16, 17, 18
- **weekday_offpeak**: all other weekday hours
- **weekend**: Saturday or Sunday

## Databricks SQL Dashboard

After `dbt run`, connect Databricks SQL to:
- `bc_transit_ws.marts.mart_route_reliability` → bar chart, reliability leaderboard
- `bc_transit_ws.marts.mart_live_vehicle_map` → map tile (lat/lon columns)
- `bc_transit_ws.marts.mart_scheduled_service_summary` → route filter / catalogue panel