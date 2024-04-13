-- we don't know how to generate root <with-no-name> (class Root) :(
create table features
(
    external_id varchar not null
        constraint features_pk_2
            unique,
    id serial not null
        constraint features_pk
            primary key,
    magnitude numeric,
    place varchar not null,
    time varchar,
    tsunami boolean,
    magtype varchar not null,
    title varchar not null,
    longitude numeric,
    latitude numeric,
    url varchar not null
);

alter table features owner to postgres;

create table comments
(
    id serial not null
        constraint comments_pk
            primary key,
    text text not null,
    feauture_id integer not null
        constraint comments_features_id_fk
            references features
            deferrable initially deferred
);

alter table comments owner to postgres;