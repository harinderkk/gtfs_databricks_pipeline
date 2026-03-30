with source as (
    select * from {{ source('gold', 'live_positions') }}
),

renamed as (
    select
        vehicle_id,
        trip_id,
        route_name,
        route_long_name,
        latitude,
        longitude,
        current_status,
        ingestion_timestamp,
        convert_timezone('UTC', 'America/Vancouver', ingestion_timestamp) as pacific_timestamp,
        date(convert_timezone('UTC', 'America/Vancouver', ingestion_timestamp)) as observation_date,
        hour(convert_timezone('UTC', 'America/Vancouver', ingestion_timestamp)) as observation_hour,
        dayofweek(convert_timezone('UTC', 'America/Vancouver', ingestion_timestamp)) as day_of_week,
        case
            when dayofweek(convert_timezone('UTC', 'America/Vancouver', ingestion_timestamp)) in (1,7) then 'weekend'
            else 'weekday'
        end as day_type,
        case
            when hour(convert_timezone('UTC', 'America/Vancouver', ingestion_timestamp)) = 7 then '7am'
            when hour(convert_timezone('UTC', 'America/Vancouver', ingestion_timestamp)) = 12 then '12pm'
            when hour(convert_timezone('UTC', 'America/Vancouver', ingestion_timestamp)) = 17 then '5pm'
            else 'other'
        end as fetch_window
    from source
)

select * from renamed