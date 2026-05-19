# TransLink GTFS Real-Time Data Pipeline

An end-to-end data engineering project on Azure Databricks that ingests TransLink's
live GTFS Real-Time feed, processes it through a medallion architecture, and analyzes
bus on-time performance for Metro Vancouver's transit network.

Built over 8 weeks. 43M+ vehicle GPS observations collected; ~21M used for the
on-time analysis across 200+ bus routes.

---

## What this project does

TransLink (Metro Vancouver's transit authority) publishes a live GTFS Real-Time feed
of every bus's GPS position. This pipeline:

1. Decodes the binary Protobuf feed from TransLink's API
2. Lands it through a Bronze -> Silver -> Gold medallion architecture on Delta Lake
3. Joins live vehicle positions to the static GTFS schedule
4. Computes on-time performance by matching GPS positions to scheduled stop
   locations using geographic distance
5. Surfaces the results through dbt models and Databricks SQL dashboards

---

## Architecture

```
STATIC GTFS (schedule)
  google_transit.zip
      |
      v
  Bronze (raw .txt) -> Silver (cleaned) -> Gold (fact_trip_schedule, dim tables)
      |                                          |
      |                                          |
REAL-TIME GTFS (live positions)                  |
  TransLink API (Protobuf)                        |
      |                                          |
      v                                          v
  Bronze RT -> Silver RT (streaming) -> Gold (live_positions)
                                               |
                                               v
                              ANALYTICS (on-time performance,
                                         delay hotspots, bunching,
                                         headway analysis)
                                               |
                                               v
                              dbt marts + Databricks SQL dashboards
```

Orchestrated by a Databricks Workflow running 3x daily (7am / 12pm / 5pm Pacific)
with service principal authentication.

---

## Tech stack

| Layer            | Technology                                              |
|------------------|---------------------------------------------------------|
| Cloud            | Microsoft Azure                                         |
| Compute          | Azure Databricks                                        |
| Storage          | Azure Data Lake Storage Gen2                            |
| Processing       | PySpark, Spark Structured Streaming                     |
| Storage format   | Delta Lake                                              |
| Governance       | Unity Catalog (catalogs, schemas, volumes)              |
| Orchestration    | Databricks Workflows                                    |
| Auth             | Azure AD service principal, Databricks Secrets          |
| Transformation   | dbt (staging + mart models)                             |
| Visualization    | Databricks SQL dashboards                               |
| Source format    | GTFS Static (.txt) and GTFS Real-Time (Protobuf)        |

---

## Pipeline notebooks

| Notebook | Purpose                                                          |
|----------|------------------------------------------------------------------|
| 01       | Ingest static GTFS .txt files to Bronze                          |
| 02       | Clean and standardize static data to Silver                      |
| 03       | Build Gold dimensional/fact tables (fact_trip_schedule)          |
| 04       | Decode Protobuf real-time feed; Bronze + Silver streaming        |
| 05       | Stream-to-batch join enriching live positions to Gold            |
| 06       | Route network activity profile (vehicles deployed per route)     |
| 07       | On-time performance, delay hotspots, bunching, headway analysis  |

---

## Key findings

**Reliability decays through the day.**
Buses run close to schedule in the morning and drift further behind as the day
progresses. Average deviation from scheduled arrival time:

| Time window     | Avg minutes off schedule |
|-----------------|--------------------------|
| Morning (7am)   | ~2.5 min                 |
| Midday (12pm)   | ~2.7 min                 |
| Evening (5pm)   | ~4.2 min                 |

The same routes and buses run further behind schedule as the day goes on, with
delays compounding across trips.

**Specific delay hotspots.**
Individual stops with chronic delays were identified, including corridors in
Surrey (88 Ave), Richmond (No. 6 Rd), and Vancouver (Main St), where a notable
share of buses arrive several minutes behind schedule.

**Bus bunching.**
The 099 B-Line (UBC / Commercial-Broadway) -- Metro Vancouver's busiest bus route --
shows the highest bunching rate: roughly 1 in 5 buses arrives within 2 minutes of
the previous bus on the same route.

**Headway vs schedule adherence are different things.**
High-frequency routes like the B-Line track their scheduled *headway* closely,
even while individual buses drift from their *scheduled times*. For frequent
routes, headway consistency matters more to riders than exact schedule adherence.

---

## Methodology

**On-time definition.** A bus is counted as on-time if it arrives between 1 minute
early and 5 minutes late relative to the scheduled time -- the standard asymmetric
window used in transit on-time reporting (early departures are penalized more
heavily because riders who arrive on time miss them).

**GPS-to-stop matching.** On-time performance is derived by computing the Haversine
distance between each live GPS observation and each scheduled stop location, then
taking the closest observation per trip/stop/date within a 50-metre radius. The
timestamp of that observation is treated as the actual arrival time.

**Outlier filtering.** Observations with an absolute delay greater than 60 minutes
are excluded as GTFS trip_id reassignment artifacts rather than genuine delays.

**GTFS versioning.** GTFS trip_ids change each time TransLink publishes a new
schedule version. The on-time analysis covers March 16 - April 19, 2026, matched
against the concurrent GTFS schedule version. Raw vehicle positions were collected
through May 9 (43M observations total); positions outside the schedule's validity
window are retained in the Gold layer but excluded from schedule-dependent metrics.

---

## Scope and limitations

This analysis is built entirely from TransLink's public GTFS feeds -- the static
schedule and the real-time vehicle position stream. It is an observational study
of *what the data shows*, not an explanation of *why*.

- **Causes are not modeled.** The pipeline measures when and where buses deviate
  from schedule. It does not attribute those deviations to any cause. Weather,
  traffic congestion, road construction, special events, ridership surges,
  operator factors, and mechanical issues are all outside the scope of this data.
- **Sampling, not continuous monitoring.** Data was collected in scheduled windows
  (around 7am, 12pm, 5pm), not continuously across all hours. Findings describe
  those windows, not the full service day.
- **GPS-derived arrival times.** Actual arrival is inferred from the closest GPS
  observation to a stop, not from a confirmed door-open event. A 50-metre matching
  radius is used as an approximation.
- **Single schedule version.** The on-time analysis is matched against one GTFS
  schedule version and covers a six-week window.

The findings should be read as a data-engineering demonstration and an exploratory
look at observed patterns, not as an official assessment of TransLink service.

---

## Data scale

- 43M+ raw vehicle GPS observations collected
- ~21M observations within the on-time analysis window
- ~1.3M individual stop arrivals matched and scored
- 200+ bus routes analyzed
- 6-week core analysis window (March-April 2026)

---

## dbt models

The dbt project demonstrates the staging-to-mart transformation pattern -- building
analytical marts on top of the Gold layer with Unity Catalog lineage. It was
developed during the project as an introduction to dbt; the final analytical
results are produced in the pipeline notebooks.

---

## Repository structure

```
gtfs_databricks_pipeline/
|-- gtfs_pipeline/    Databricks notebooks (pipeline source)
|-- models/           dbt models (staging + marts)
|-- dbt_project.yml   dbt project config
|-- workflows/        Databricks job definition / screenshot
|-- dashboards/       Dashboard screenshots
+-- README.md
```

---

## Notes

This is a personal portfolio project built to learn production data engineering
patterns on Azure Databricks. It uses TransLink's publicly available open data.
It is not affiliated with or endorsed by TransLink.
