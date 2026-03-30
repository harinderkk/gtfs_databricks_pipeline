with reliability as (
    select * from {{ source('gold', 'route_reliability_index') }}
),

live as (
    select * from {{ ref('stg_live_positions') }}
    where fetch_window != 'other'
),

vehicle_counts as (
    select
        route_name,
        fetch_window,
        day_type,
        count(distinct vehicle_id)  as unique_vehicles_observed,
        count(distinct trip_id)     as unique_trips_observed
    from live
    group by route_name, fetch_window, day_type
),

peak_vehicles as (
    select
        route_name,
        max(case when fetch_window = '7am'  then unique_vehicles_observed end) as vehicles_7am,
        max(case when fetch_window = '12pm' then unique_vehicles_observed end) as vehicles_12pm,
        max(case when fetch_window = '5pm'  then unique_vehicles_observed end) as vehicles_5pm
    from vehicle_counts
    group by route_name
),

final as (
    select
        r.route_name,
        r.route_long_name,
        r.morning_7am_pct,
        r.midday_12pm_pct,
        r.evening_5pm_pct,
        r.trip_observation_rate,
        p.vehicles_7am,
        p.vehicles_12pm,
        p.vehicles_5pm,
        case
            when r.trip_observation_rate >= 65 then 'High'
            when r.trip_observation_rate >= 55 then 'Medium'
            else 'Low'
        end as observation_tier,
        rank() over (order by r.trip_observation_rate desc) as reliability_rank
    from reliability r
    left join peak_vehicles p on r.route_name = p.route_name
)

select * from final
order by trip_observation_rate desc