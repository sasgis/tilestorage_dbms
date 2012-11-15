/*==============================================================*/
/* Table: t_all_sql                                             */
/*==============================================================*/
-- allow to use select * from dual
create view DUAL as select @@version as ENGINE_VERSION
go
-- end of script

create table t_all_sql (
   object_name          sysname                        not null,
   object_operation     char(1)                        not null
         constraint CKC_OBJECT_OPERATION_T_ALL_SQ check (object_operation in ('C','S','I','U','D')),
   index_sql            smallint                       not null,
   skip_sql             char(1)                        default '0' not null,
   ignore_errors        char(1)                        default '1' not null,
   object_sql           text                           null,
   constraint PK_T_ALL_SQL primary key (object_name, object_operation, index_sql)
)
lock datarows
go



/*==============================================================*/
/* Table: c_contenttype                                         */
/*==============================================================*/
create table c_contenttype (
   id_contenttype       smallint                       not null,
   contenttype_text     varchar(50)                    not null,
   constraint PK_C_CONTENTTYPE primary key (id_contenttype)
)
lock datarows
go

if not exists(select 1 from c_contenttype where id_contenttype=1)
begin
  insert into c_contenttype (id_contenttype, contenttype_text)
  values (1, 'image/png')
end
go

if not exists(select 1 from c_contenttype where id_contenttype=2)
begin
  insert into c_contenttype (id_contenttype, contenttype_text)
  values (2, 'image/jpeg')
end
go

if not exists(select 1 from c_contenttype where id_contenttype=3)
begin
  insert into c_contenttype (id_contenttype, contenttype_text)
  values (3, 'image/jp2')
end
go

if not exists(select 1 from c_contenttype where id_contenttype=4)
begin
  insert into c_contenttype (id_contenttype, contenttype_text)
  values (4, 'image/gif')
end
go

if not exists(select 1 from c_contenttype where id_contenttype=5)
begin
  insert into c_contenttype (id_contenttype, contenttype_text)
  values (5, 'image/tiff')
end
go

if not exists(select 1 from c_contenttype where id_contenttype=6)
begin
  insert into c_contenttype (id_contenttype, contenttype_text)
  values (6, 'image/svg+xml')
end
go

if not exists(select 1 from c_contenttype where id_contenttype=7)
begin
  insert into c_contenttype (id_contenttype, contenttype_text)
  values (7, 'image/vnd.microsoft.icon')
end
go


if not exists(select 1 from c_contenttype where id_contenttype=65)
begin
  insert into c_contenttype (id_contenttype, contenttype_text)
  values (65, 'application/vnd.google-earth.kml+xml')
end
go

if not exists(select 1 from c_contenttype where id_contenttype=66)
begin
  insert into c_contenttype (id_contenttype, contenttype_text)
  values (66, 'application/gpx+xml')
end
go

if not exists(select 1 from c_contenttype where id_contenttype=67)
begin
  insert into c_contenttype (id_contenttype, contenttype_text)
  values (67, 'application/vnd.google-earth.kmz')
end
go

if not exists(select 1 from c_contenttype where id_contenttype=68)
begin
  insert into c_contenttype (id_contenttype, contenttype_text)
  values (68, 'application/xml')
end
go


if not exists(select 1 from c_contenttype where id_contenttype=91)
begin
  insert into c_contenttype (id_contenttype, contenttype_text)
  values (91, 'text/html')
end
go

if not exists(select 1 from c_contenttype where id_contenttype=92)
begin
  insert into c_contenttype (id_contenttype, contenttype_text)
  values (92, 'text/plain')
end
go


/*==============================================================*/
/* Index: c_contenttype_uniq                                    */
/*==============================================================*/
create unique index c_contenttype_uniq on c_contenttype (
contenttype_text ASC
)
go



/*==============================================================*/
/* Table: t_options                                             */
/*==============================================================*/
create table t_options (
   id_option            int                            not null,
   option_descript      varchar(255)                   not null,
   option_value         int                            not null,
   constraint PK_T_OPTIONS primary key (id_option)
)
lock datarows
go

if not exists(select 1 from t_options where id_option=1)
begin
  insert into t_options (id_option,option_descript,option_value)
  values (1, 'Autocreate services', 0)
end
go

if not exists(select 1 from t_options where id_option=2)
begin
  insert into t_options (id_option,option_descript,option_value)
  values (2, 'Autocreate versions', 0)
end
go

if not exists(select 1 from t_options where id_option=3)
begin
  insert into t_options (id_option,option_descript,option_value)
  values (3, 'Keep TILE for TNE', 0)
end
go




/*==============================================================*/
/* Table: t_div_mode                                            */
/*==============================================================*/
create table t_div_mode (
   id_div_mode          char(1)                        not null,
   div_mode_name        varchar(30)                    not null,
   div_mask_width       smallint                       not null,
   constraint PK_T_DIV_MODE primary key (id_div_mode)
)
lock datarows
go

if not exists(select 1 from t_div_mode where id_div_mode='Z')
begin
  insert into t_div_mode (id_div_mode,div_mode_name,div_mask_width)
  values ('Z','All-in-One',0)
end
go

if not exists(select 1 from t_div_mode where id_div_mode='F')
begin
  insert into t_div_mode (id_div_mode,div_mode_name,div_mask_width)
  values ('F','Based on 1024',10)
end
go

if not exists(select 1 from t_div_mode where id_div_mode='G')
begin
  insert into t_div_mode (id_div_mode,div_mode_name,div_mask_width)
  values ('G','Based on 2048',11)
end
go

if not exists(select 1 from t_div_mode where id_div_mode='H')
begin
  insert into t_div_mode (id_div_mode,div_mode_name,div_mask_width)
  values ('H','Based on 4096',12)
end
go

if not exists(select 1 from t_div_mode where id_div_mode='I')
begin
  insert into t_div_mode (id_div_mode,div_mode_name,div_mask_width)
  values ('I','Based on 8192',13)
end
go

if not exists(select 1 from t_div_mode where id_div_mode='J')
begin
  insert into t_div_mode (id_div_mode,div_mode_name,div_mask_width)
  values ('J','Based on 16384',14)
end
go

if not exists(select 1 from t_div_mode where id_div_mode='K')
begin
  insert into t_div_mode (id_div_mode,div_mode_name,div_mask_width)
  values ('K','Based on 32768',15)
end
go

/*==============================================================*/
/* Index: div_mode_name_uniq                                    */
/*==============================================================*/
create unique index div_mode_name_uniq on t_div_mode (
div_mode_name ASC
)
go





/*==============================================================*/
/* Table: t_ver_comp                                            */
/*==============================================================*/
create table t_ver_comp (
   id_ver_comp          char(1)                        not null,
   ver_comp_field       varchar(30)                    not null,
   ver_comp_name        varchar(30)                    not null,
   constraint PK_T_VER_COMP primary key (id_ver_comp)
)
lock datarows
go

if not exists(select 1 from t_ver_comp where id_ver_comp='0')
begin
  insert into t_ver_comp (id_ver_comp,ver_comp_field,ver_comp_name)
  values ('0','-','No')
end
go

if not exists(select 1 from t_ver_comp where id_ver_comp='I')
begin
  insert into t_ver_comp (id_ver_comp,ver_comp_field,ver_comp_name)
  values ('I','id_ver','By id')
end
go

if not exists(select 1 from t_ver_comp where id_ver_comp='A')
begin
  insert into t_ver_comp (id_ver_comp,ver_comp_field,ver_comp_name)
  values ('V','ver_value','By value')
end
go

if not exists(select 1 from t_ver_comp where id_ver_comp='D')
begin
  insert into t_ver_comp (id_ver_comp,ver_comp_field,ver_comp_name)
  values ('D','ver_date','By date')
end
go

if not exists(select 1 from t_ver_comp where id_ver_comp='D')
begin
  insert into t_ver_comp (id_ver_comp,ver_comp_field,ver_comp_name)
  values ('N','ver_number','By number')
end
go

/*==============================================================*/
/* Index: t_ver_comp_field_uniq                                 */
/*==============================================================*/
create unique index t_ver_comp_field_uniq on t_ver_comp (
ver_comp_field ASC
)
go

/*==============================================================*/
/* Index: t_ver_comp_name_uniq                                  */
/*==============================================================*/
create unique index t_ver_comp_name_uniq on t_ver_comp (
ver_comp_name ASC
)
go





/*==============================================================*/
/* Table: t_service                                             */
/*==============================================================*/
create table t_service (
   id_service           smallint                       not null,
   service_code         varchar(20)                    not null,
   service_name         varchar(50)                    not null,
   id_contenttype       smallint                       not null,
   id_ver_comp          char(1)                        default '0' not null,
   id_div_mode          char(1)                        default 'F' not null,
   work_mode            char(1)                        default '0' not null
         constraint CKC_WORK_MODE_T_SERVICE check (work_mode in ('0','S','R')),
   use_common_tiles     char(1)                        default '0' not null,
   constraint PK_T_SERVICE primary key (id_service)
)
lock datarows
go

/*==============================================================*/
/* Index: service_code_uniq                                     */
/*==============================================================*/
create unique index service_code_uniq on t_service (
service_code ASC
)
go

/*==============================================================*/
/* Index: service_name_uniq                                     */
/*==============================================================*/
create unique index service_name_uniq on t_service (
service_name ASC
)
go

alter table t_service
   add constraint fk_t_service2c_contenttype foreign key (id_contenttype)
      references c_contenttype (id_contenttype)
go

alter table t_service
   add constraint fk_t_service2t_div_mode foreign key (id_div_mode)
      references t_div_mode (id_div_mode)
go

alter table t_service
   add constraint fk_t_service2t_ver_comp foreign key (id_ver_comp)
      references t_ver_comp (id_ver_comp)
go


