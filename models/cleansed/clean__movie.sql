with source_raw_movie as (
    select id, seq_id, title, year, rating from {{ source('raw', 'movie') }}
),

final as (
    select * from source_raw_movie
)

select * from final
