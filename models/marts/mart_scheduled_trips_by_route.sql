{{
    config(
        materialized='table',
        schema='gold',
        database='bc_transit_ws',
        description='Scheduled trips per route broken down by day type and fetch window. Shows frequency rank and stops served.'
    )
}}

with schedule as (
    select * from {{ ref('stg_fact_trip_schedule') }}
    where fetch_window != 'other'
),

route_summary as (
    select
        route_name,
        route_long_name,
        day_type,
        fetch_window,
        count(distinct trip_id)                     as unique_trips_scheduled,
        count(distinct stop_id)                     as unique_stops_served,
        min(arrival_time)                           as first_departure,
        max(arrival_time)                           as last_departure
    from schedule
    group by route_name, route_long_name, day_type, fetch_window
),

with_totals as (
    select
        route_name,
        route_long_name,
        day_type,
        fetch_window,
        unique_trips_scheduled,
        unique_stops_served,
        first_departure,
        last_departure,
        sum(unique_trips_scheduled) over (
            partition by route_name, day_type
        ) as total_daily_trips,
        rank() over (
            order by unique_trips_scheduled desc
        ) as frequency_rank
    from route_summary
)

select * from with_totals
order by unique_trips_scheduled desc