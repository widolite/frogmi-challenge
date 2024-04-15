create database earthquake
    with owner postgres;

create table public.features
(
    external_id varchar not null
        constraint features_pk_2
            unique,
    id          serial
        constraint features_pk
            primary key,
    magnitude   numeric,
    place       varchar not null,
    time        varchar,
    tsunami     boolean,
    magtype     varchar not null,
    title       varchar not null,
    longitude   numeric,
    latitude    numeric,
    url         varchar not null
);

alter table public.features
    owner to postgres;

create table public.comments
(
    id          serial
        constraint comments_pk
            primary key,
    text        text    not null,
    feauture_id integer not null
        constraint comments_features_id_fk
            references public.features
            deferrable initially deferred
);

alter table public.comments
    owner to postgres;