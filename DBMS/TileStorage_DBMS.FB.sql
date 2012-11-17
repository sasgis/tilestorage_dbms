create view DUAL as select 'FIREBIRD' as ENGINETYPE, rdb$get_context('SYSTEM','ENGINE_VERSION') as ENGINE_VERSION from rdb$database
;

create table Z_ALL_SQL (
   object_name          varchar(31)                    not null,
   object_oper          char(1)                        not null
         constraint CKC_OBJECT_OPER_Z_ALL_SQL check (object_oper in ('C','S','I','U','D')),
   index_sql            smallint                       not null,
   skip_sql             char(1)                        default '0' not null,
   ignore_errors        char(1)                        default '1' not null,
   object_sql           BLOB sub_type 1,
   constraint PK_Z_ALL_SQL primary key (object_name, object_oper, index_sql)
)
;



create table Z_CONTENTTYPE (
   id_contenttype       smallint                       not null,
   contenttype_text     varchar(50)                    not null,
   constraint PK_Z_CONTENTTYPE primary key (id_contenttype)
)
;

execute block as
begin
if (not exists(select 1 from Z_CONTENTTYPE where id_contenttype=1))
then
  insert into Z_CONTENTTYPE (id_contenttype, contenttype_text)
  values (1, 'image/png');
end
end
;

execute block as
begin
if (not exists(select 1 from Z_CONTENTTYPE where id_contenttype=2))
then
  insert into Z_CONTENTTYPE (id_contenttype, contenttype_text)
  values (2, 'image/jpeg');
end
end
;

execute block as
begin
if (not exists(select 1 from Z_CONTENTTYPE where id_contenttype=3))
then
  insert into Z_CONTENTTYPE (id_contenttype, contenttype_text)
  values (3, 'image/jpg');
end
end
;

execute block as
begin
if (not exists(select 1 from Z_CONTENTTYPE where id_contenttype=4))
then
  insert into Z_CONTENTTYPE (id_contenttype, contenttype_text)
  values (4, 'image/gif');
end
end
;

execute block as
begin
if (not exists(select 1 from Z_CONTENTTYPE where id_contenttype=5))
then
  insert into Z_CONTENTTYPE (id_contenttype, contenttype_text)
  values (5, 'image/tiff');
end
end
;

execute block as
begin
if (not exists(select 1 from Z_CONTENTTYPE where id_contenttype=6))
then
  insert into Z_CONTENTTYPE (id_contenttype, contenttype_text)
  values (6, 'image/svg+xml');
end
end
;

execute block as
begin
if (not exists(select 1 from Z_CONTENTTYPE where id_contenttype=7))
then
  insert into Z_CONTENTTYPE (id_contenttype, contenttype_text)
  values (7, 'image/vnd.microsoft.icon');
end
end
;

execute block as
begin
if (not exists(select 1 from Z_CONTENTTYPE where id_contenttype=8))
then
  insert into Z_CONTENTTYPE (id_contenttype, contenttype_text)
  values (8, 'image/jp2');
end
end
;


execute block as
begin
if (not exists(select 1 from Z_CONTENTTYPE where id_contenttype=65))
then
  insert into Z_CONTENTTYPE (id_contenttype, contenttype_text)
  values (65, 'application/vnd.google-earth.kml+xml');
end
end
;

execute block as
begin
if (not exists(select 1 from Z_CONTENTTYPE where id_contenttype=66))
then
  insert into Z_CONTENTTYPE (id_contenttype, contenttype_text)
  values (66, 'application/gpx+xml');
end
end
;

execute block as
begin
if (not exists(select 1 from Z_CONTENTTYPE where id_contenttype=67))
then
  insert into Z_CONTENTTYPE (id_contenttype, contenttype_text)
  values (67, 'application/vnd.google-earth.kmz');
end
end
;

execute block as
begin
if (not exists(select 1 from Z_CONTENTTYPE where id_contenttype=68))
then
  insert into Z_CONTENTTYPE (id_contenttype, contenttype_text)
  values (68, 'application/xml');
end
end
;


execute block as
begin
if (not exists(select 1 from Z_CONTENTTYPE where id_contenttype=91))
then
  insert into Z_CONTENTTYPE (id_contenttype, contenttype_text)
  values (91, 'text/html');
end
end
;

execute block as
begin
if (not exists(select 1 from Z_CONTENTTYPE where id_contenttype=92))
then
  insert into Z_CONTENTTYPE (id_contenttype, contenttype_text)
  values (92, 'text/plain');
end
end
;


create unique index Z_CONTENTTYPE_UNIQ on Z_CONTENTTYPE (
contenttype_text ASC
)
;



create table Z_OPTIONS (
   id_option            int                            not null,
   option_descript      varchar(255)                   not null,
   option_value         int                            not null,
   constraint PK_Z_OPTIONS primary key (id_option)
)
;

execute block as
begin
if (not exists(select 1 from Z_OPTIONS where id_option=1))
then
  insert into Z_OPTIONS (id_option,option_descript,option_value)
  values (1, 'Autocreate services', 0);
end
end
;

execute block as
begin
if (not exists(select 1 from Z_OPTIONS where id_option=2))
then
  insert into Z_OPTIONS (id_option,option_descript,option_value)
  values (2, 'Autocreate versions', 0);
end
end
;

execute block as
begin
if (not exists(select 1 from Z_OPTIONS where id_option=3))
then
  insert into Z_OPTIONS (id_option,option_descript,option_value)
  values (3, 'Keep TILE for TNE', 0);
end
end
;




create table Z_DIV_MODE (
   id_div_mode          char(1)                        not null,
   div_mode_name        varchar(30)                    not null,
   div_mask_width       smallint                       not null,
   constraint PK_Z_DIV_MODE primary key (id_div_mode)
)
;

execute block as
begin
if (not exists(select 1 from Z_DIV_MODE where id_div_mode='Z'))
then
  insert into Z_DIV_MODE (id_div_mode,div_mode_name,div_mask_width)
  values ('Z','All-in-One',0);
end
end
;

execute block as
begin
if (not exists(select 1 from Z_DIV_MODE where id_div_mode='I'))
then
  insert into Z_DIV_MODE (id_div_mode,div_mode_name,div_mask_width)
  values ('I','Based on 1024',10);
end
end
;

execute block as
begin
if (not exists(select 1 from Z_DIV_MODE where id_div_mode='J'))
then
  insert into Z_DIV_MODE (id_div_mode,div_mode_name,div_mask_width)
  values ('J','Based on 2048',11);
end
end
;

execute block as
begin
if (not exists(select 1 from Z_DIV_MODE where id_div_mode='K'))
then
  insert into Z_DIV_MODE (id_div_mode,div_mode_name,div_mask_width)
  values ('K','Based on 4096',12);
end
end
;

execute block as
begin
if (not exists(select 1 from Z_DIV_MODE where id_div_mode='L'))
then
  insert into Z_DIV_MODE (id_div_mode,div_mode_name,div_mask_width)
  values ('L','Based on 8192',13);
end
end
;

execute block as
begin
if (not exists(select 1 from Z_DIV_MODE where id_div_mode='M'))
then
  insert into Z_DIV_MODE (id_div_mode,div_mode_name,div_mask_width)
  values ('M','Based on 16384',14);
end
end
;

execute block as
begin
if (not exists(select 1 from Z_DIV_MODE where id_div_mode='N'))
then
  insert into Z_DIV_MODE (id_div_mode,div_mode_name,div_mask_width)
  values ('N','Based on 32768',15);
end
end
;

create unique index Z_DIV_MODE_UNIQ on Z_DIV_MODE (
div_mode_name ASC
)
;





create table Z_VER_COMP (
   id_ver_comp          char(1)                        not null,
   ver_comp_field       varchar(30)                    not null,
   ver_comp_name        varchar(30)                    not null,
   constraint PK_Z_VER_COMP primary key (id_ver_comp)
)
;

execute block as
begin
if (not exists(select 1 from Z_VER_COMP where id_ver_comp='0'))
then
  insert into Z_VER_COMP (id_ver_comp,ver_comp_field,ver_comp_name)
  values ('0','-','No');
end
end
;

execute block as
begin
if (not exists(select 1 from Z_VER_COMP where id_ver_comp='I'))
then
  insert into Z_VER_COMP (id_ver_comp,ver_comp_field,ver_comp_name)
  values ('I','id_ver','By id');
end
end
;

execute block as
begin
if (not exists(select 1 from Z_VER_COMP where id_ver_comp='V'))
then
  insert into Z_VER_COMP (id_ver_comp,ver_comp_field,ver_comp_name)
  values ('V','ver_value','By value');
end
end
;

execute block as
begin
if (not exists(select 1 from Z_VER_COMP where id_ver_comp='D'))
then
  insert into Z_VER_COMP (id_ver_comp,ver_comp_field,ver_comp_name)
  values ('D','ver_date','By date');
end
end
;

execute block as
begin
if (not exists(select 1 from Z_VER_COMP where id_ver_comp='N'))
then
  insert into Z_VER_COMP (id_ver_comp,ver_comp_field,ver_comp_name)
  values ('N','ver_number','By number');
end
end
;

create unique index Z_VER_COMP_F_UNIQ on Z_VER_COMP (
ver_comp_field ASC
)
;

create unique index Z_VER_COMP_N_UNIQ on Z_VER_COMP (
ver_comp_name ASC
)
;





create table Z_SERVICE (
   id_service           smallint                       not null,
   service_code         varchar(20)                    not null,
   service_name         varchar(50)                    not null,
   id_contenttype       smallint                       not null,
   id_ver_comp          char(1)                        default '0' not null,
   id_div_mode          char(1)                        default 'I' not null,
   work_mode            char(1)                        default '0' not null
         constraint CKC_WORK_MODE_Z_SERVICE check (work_mode in ('0','S','R')),
   use_common_tiles     char(1)                        default '0' not null,
   constraint PK_Z_SERVICE primary key (id_service)
)
;

create unique index Z_SERVICE_C_UNIQ on Z_SERVICE (
service_code ASC
)
;

create unique index Z_SERVICE_N_UNIQ on Z_SERVICE (
service_name ASC
)
;

alter table Z_SERVICE
   add constraint FK_Z_SERVICE2Z_CONTENTTYPE foreign key (id_contenttype)
      references Z_CONTENTTYPE (id_contenttype)
;

alter table Z_SERVICE
   add constraint FK_Z_SERVICE2Z_DIV_MODE foreign key (id_div_mode)
      references Z_DIV_MODE (id_div_mode)
;

alter table Z_SERVICE
   add constraint FK_Z_SERVICE2Z_VER_COMP foreign key (id_ver_comp)
      references Z_VER_COMP (id_ver_comp)
;


