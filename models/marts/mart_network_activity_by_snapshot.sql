{{
    config(
        materialized='table',
        schema='gold',
        description='Latest known position for every active vehicle. Deduplicated to one row per vehicle_id using the most recent ingestion_timestamp. Intended as the data source for a live vehicle map dashboard.'
    )
}}

/*
  Produces one row per vehicle showing its most recent GPS position, route, and status.
  Filters to positions ingested within the last 2 hours so the map reflects
  only vehicles that are currently (or very recently) in service.
*/

with latest_per_vehicle as (
    select
        vehicle_id,
        max(ingestion_timestamp) as latest_timestamp
    from {{ source('gold', 'live_positions') }}
    -- Rolling 2-hour window — keeps the map fresh without old ghost vehicles
    where ingestion_timestamp >= timestampadd(hour, -2, current_timestamp())
    group by vehicle_id
)

select
    lp.vehicle_id,
    lp.trip_id,
    lp.route_name,
    lp.route_long_name,
    lp.trip_headsign,
    lp.latitude,
    lp.longitude,
    lp.bearing,
    lp.current_status,
    lp.ingestion_timestamp                   as last_seen_at,
    lp.gold_processed_at,
    current_timestamp()                      as dbt_updated_at
from {{ source('gold', 'live_positions') }} lp
inner join latest_per_vehicle lpv
    on  lp.vehicle_id        = lpv.vehicle_id
    and lp.ingestion_timestamp = lpv.latest_timestamp