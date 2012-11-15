create table v_%SERVICE% (
   id_ver               smallint                       not null,
   ver_value            varchar(50)                    not null,
   ver_date             TIMESTAMP                      not null,
   ver_number           int                            default 0 not null,
   ver_comment          varchar(255),
   constraint PK_V_%SERVICE% primary key (id_ver)
)
;

create unique index u_%SERVICE%__ on v_%SERVICE% (
ver_value ASC
)
;




create table u_%SERVICE% (
   id_common_tile       smallint                       not null,
   id_common_type       smallint                       not null,
   common_size          int                            not null,
   common_body          BLOB sub_type binary,
   constraint PK_U_%SERVICE% primary key (id_common_tile)
)
;

create index u_%SERVICE%_idx on u_%SERVICE% (
id_common_type ASC,
common_size ASC
)
;




create table %DIV%%ZOOM%%HEAD%_%SERVICE% (
   x                    numeric                        not null,
   y                    numeric                        not null,
   id_ver               smallint                       not null,
   tile_size            int                            default 0 not null,
   id_contenttype       smallint                       not null,
   load_date            TIMESTAMP                      default CURRENT_TIMESTAMP not null,
   tile_body            BLOB sub_type binary,
   constraint PK_%DIV%%ZOOM%%HEAD%_%SERVICE% primary key (x, y, id_ver)
)
;

create index SK_%DIV%%ZOOM%%HEAD%_%SERVICE% on %DIV%%ZOOM%%HEAD%_%SERVICE% (
x ASC,
y ASC,
id_ver ASC,
tile_size ASC
)
;

