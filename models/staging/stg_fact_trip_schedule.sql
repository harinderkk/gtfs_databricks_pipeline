with source as (
    select * from {{ source('gold', 'fact_trip_schedule') }}
),

renamed as (
    select
        trip_id,
        route_short_name_display as route_name,
        route_long_name,
        arrival_time,
        stop_id,
        stop_name,
        cast(substr(arrival_time, 1, 2) as integer) as scheduled_hour,
        cast(substr(arrival_time, 4, 2) as integer) as scheduled_minute,
        case
            when hour(arrival_time) = 7 then '7am'
            when hour(arrival_time) = 12 then '12pm'
            when hour(arrival_time) = 17 then '5pm'
            else 'other'
        end as fetch_window,
        case
            when saturday = 1 or sunday = 1 then 'weekend'
            else 'weekday'
        end as day_type,
        monday,
        tuesday,
        wednesday,
        thursday,
        friday,
        saturday,
        sunday
    from source
    where arrival_time is not null
    and cast(substr(arrival_time, 1, 2) as integer) < 24
)

select * from renamed