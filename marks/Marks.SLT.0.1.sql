create table IF NOT EXISTS g_version (
   id_version INTEGER PRIMARY KEY NOT NULL
)
;




create table IF NOT EXISTS g_option (
   id_option    INTEGER PRIMARY KEY NOT NULL,
   option_value INT NOT NULL
)
;

insert OR IGNORE into g_option (id_option, option_value)
values (1, 0)
;

insert OR IGNORE into g_option (id_option, option_value)
values (2, 1)
;

insert OR IGNORE into g_option (id_option, option_value)
values (3, 0)
;

insert OR IGNORE into g_option (id_option, option_value)
values (4, 0)
;

insert OR IGNORE into g_option (id_option, option_value)
values (5, 1)
;




create table IF NOT EXISTS g_user (
   id_user INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
   u_name  NVARCHAR NOT NULL,
   u_status INT NOT NULL DEFAULT 0
)
;

create unique index IF NOT EXISTS g_user_uniq on g_user (u_name)
;

insert OR IGNORE into g_user (id_user, u_name)
values (0, '')
;




create table IF NOT EXISTS g_image (
   id_image INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
   i_name  NVARCHAR NOT NULL
)
;

create unique index IF NOT EXISTS g_image_uniq on g_image (i_name)
;




create table IF NOT EXISTS g_category (
   id_category INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
   id_owner    INTEGER NOT NULL CONSTRAINT g_category2g_user REFERENCES g_user (id_user) ON DELETE RESTRICT,
   c_status    INT NOT NULL DEFAULT 0,
   c_name      NVARCHAR NOT NULL
)
;

create unique index IF NOT EXISTS g_category_uniq on g_category (c_name)
;

create index IF NOT EXISTS g_category2g_user_fk on g_category (id_owner)
;




create table IF NOT EXISTS m_mark (
   id_mark      INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
   id_owner     INTEGER NOT NULL CONSTRAINT m_mark2g_user REFERENCES g_user (id_user) ON DELETE RESTRICT,
   o_status     INT NOT NULL DEFAULT 0,
   o_name       NVARCHAR NOT NULL,
   id_category  INTEGER NOT NULL CONSTRAINT m_mark2g_category REFERENCES g_category (id_category) ON DELETE CASCADE
)
;

create index IF NOT EXISTS m_mark2g_user_fk on m_mark (id_owner)
;

create index IF NOT EXISTS m_mark2g_category_fk on m_mark (id_category)
;




create table IF NOT EXISTS m_descript (
   id_mark INTEGER NOT NULL CONSTRAINT m_descript2m_mark REFERENCES m_mark (id_mark) ON DELETE CASCADE,
   d_type  SMALLINT NOT NULL,
   d_text  TEXT,
   constraint PK_M_DESCRIPT primary key (id_mark, d_type)
)
;




create table IF NOT EXISTS m_point (
   id_mark   INTEGER PRIMARY KEY NOT NULL CONSTRAINT m_point2m_mark REFERENCES m_mark (id_mark) ON DELETE CASCADE,
   id_image  INTEGER CONSTRAINT m_point2g_image REFERENCES g_image (id_image) ON DELETE SET NULL,
   m_lon     INT NOT NULL,
   m_lat     INT NOT NULL
)
;

create index IF NOT EXISTS m_point2g_image_fk on m_point (id_image)
;

create index IF NOT EXISTS m_point_coord_idx on m_point (m_lon, m_lat)
;




create table IF NOT EXISTS m_polyline (
   id_mark   INTEGER PRIMARY KEY NOT NULL CONSTRAINT m_polyline2m_mark REFERENCES m_mark (id_mark) ON DELETE CASCADE,
   min_lon   INT NOT NULL,
   min_lat   INT NOT NULL,
   max_lon   INT NOT NULL,
   max_lat   INT NOT NULL,
   sub_count SMALLINT NOT NULL
)
;

create index IF NOT EXISTS m_polyline_coord_min on m_polyline (min_lon, min_lat)
;

create index IF NOT EXISTS m_polyline_coord_max on m_polyline (max_lon, max_lat)
;




create table IF NOT EXISTS i_polyline (
   id_mark       INTEGER NOT NULL CONSTRAINT i_polyline2m_polyline REFERENCES m_polyline (id_mark) ON DELETE CASCADE,
   npp           SMALLINT DEFAULT 0 NOT NULL,
   min_lon       INT NOT NULL,
   min_lat       INT NOT NULL,
   max_lon       INT NOT NULL,
   max_lat       INT NOT NULL,
   lonlat_type   SMALLINT DEFAULT 0 NOT NULL,
   lonlat_list   BLOB,
   constraint PK_I_POLYLINE primary key (id_mark, npp)
)
;

create index IF NOT EXISTS i_polyline_coord_min on i_polyline (min_lon, min_lat)
;

create index IF NOT EXISTS i_polyline_coord_max on i_polyline (max_lon, max_lat)
;




create table IF NOT EXISTS m_polygon (
   id_mark   INTEGER PRIMARY KEY NOT NULL CONSTRAINT m_polygon2m_mark REFERENCES m_mark (id_mark) ON DELETE CASCADE,
   min_lon   INT NOT NULL,
   min_lat   INT NOT NULL,
   max_lon   INT NOT NULL,
   max_lat   INT NOT NULL,
   sub_count SMALLINT NOT NULL
)
;

create index IF NOT EXISTS m_polygon_coord_min on m_polygon (min_lon, min_lat)
;

create index IF NOT EXISTS m_polygon_coord_max on m_polygon (max_lon, max_lat)
;




create table IF NOT EXISTS m_polyouter (
   id_mark      INTEGER NOT NULL CONSTRAINT m_polyouter2m_polygon REFERENCES m_polygon (id_mark) ON DELETE CASCADE,
   npp          SMALLINT NOT NULL,
   min_lon      INT NOT NULL,
   min_lat      INT NOT NULL,
   max_lon      INT NOT NULL,
   max_lat      INT NOT NULL,
   lonlat_type  SMALLINT DEFAULT 0 NOT NULL,
   lonlat_list  BLOB,
   constraint PK_M_POLYOUTER primary key (id_mark, npp)
)
;

create index IF NOT EXISTS m_polyouter_coord_min on m_polyouter (min_lon, min_lat)
;

create index IF NOT EXISTS m_polyouter_coord_max on m_polyouter (max_lon, max_lat)
;




create table IF NOT EXISTS m_polyinner (
   id_mark      INTEGER NOT NULL,
   npp_outer    SMALLINT NOT NULL,
   npp_inner    SMALLINT NOT NULL,
   lonlat_type  SMALLINT DEFAULT 0 NOT NULL,
   lonlat_list  BLOB,
   constraint PK_M_POLYINNER primary key (id_mark, npp_outer, npp_inner),
   constraint m_polyinner2m_polyouter FOREIGN KEY (id_mark, npp_outer) REFERENCES m_polyouter (id_mark, npp)  ON DELETE CASCADE
)
;





create table IF NOT EXISTS g_show_pt (
   id_show_pt   INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
   text_color   INT,
   shadow_color INT,
   font_size    SMALLINT,
   icon_size    SMALLINT
)
;

create table IF NOT EXISTS g_show_pl (
   id_show_pl      INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
   line_color      INT,
   line_type       INT,
   line_width      SMALLINT,
   line_direction  SMALLINT
)
;

create table IF NOT EXISTS g_show_pg (
   id_show_pg      INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
   fill_color      INT,
   fill_type       INT,
   fill_width      SMALLINT,
   fill_direction  SMALLINT
)
;




create table IF NOT EXISTS v_category (
   id_user      INTEGER NOT NULL CONSTRAINT v_category2g_user REFERENCES g_user (id_user) ON DELETE CASCADE,
   id_category  INTEGER NOT NULL CONSTRAINT v_category2g_category REFERENCES g_category (id_category) ON DELETE CASCADE,
   v_status     INT DEFAULT 0 NOT NULL,
   v_visible    TINYINT,
   min_zoom     TINYINT,
   max_zoom     TINYINT,
   constraint PK_V_CATEGORY primary key (id_user, id_category)
)
;

create index IF NOT EXISTS v_category2g_category_fk on v_category (id_category)
;




create table IF NOT EXISTS v_mark (
   id_user      INTEGER NOT NULL CONSTRAINT v_mark2g_user REFERENCES g_user (id_user) ON DELETE CASCADE,
   id_mark      INTEGER NOT NULL CONSTRAINT v_mark2m_mark REFERENCES m_mark (id_mark) ON DELETE CASCADE,
   m_status     INT DEFAULT 0 NOT NULL,
   m_visible    TINYINT,
   constraint PK_V_MARK primary key (id_user, id_mark)
)
;

create index IF NOT EXISTS v_mark2m_mark_fk on v_mark (id_mark)
;




create table IF NOT EXISTS m_show_pt (
   id_user      INTEGER NOT NULL CONSTRAINT m_show_pt2g_user REFERENCES g_user (id_user) ON DELETE CASCADE,
   id_mark      INTEGER NOT NULL CONSTRAINT m_show_pt2m_point REFERENCES m_point (id_mark) ON DELETE CASCADE,
   id_show_pt   INTEGER NOT NULL CONSTRAINT m_show_pt2g_show_pt REFERENCES g_show_pt (id_show_pt) ON DELETE CASCADE,
   constraint PK_M_SHOW_PT primary key (id_user, id_mark)
)
;

create index IF NOT EXISTS m_show_pt2m_point_fk on m_show_pt (id_mark)
;

create index IF NOT EXISTS m_show_pt2g_show_pt_fk on m_show_pt (id_show_pt)
;




create table IF NOT EXISTS m_show_pl (
   id_user      INTEGER NOT NULL CONSTRAINT m_show_pl2g_user REFERENCES g_user (id_user) ON DELETE CASCADE,
   id_mark      INTEGER NOT NULL CONSTRAINT m_show_pl2m_polyline REFERENCES m_polyline (id_mark) ON DELETE CASCADE,
   id_show_pl   INTEGER NOT NULL CONSTRAINT m_show_pl2g_show_pl REFERENCES g_show_pl (id_show_pl) ON DELETE CASCADE,
   constraint PK_M_SHOW_PL primary key (id_user, id_mark)
)
;

create index IF NOT EXISTS m_show_pl2m_polyline_fk on m_show_pl (id_mark)
;

create index IF NOT EXISTS m_show_pl2g_show_pl_fk on m_show_pl (id_show_pl)
;




create table IF NOT EXISTS m_show_pg (
   id_user      INTEGER NOT NULL CONSTRAINT m_show_pg2g_user REFERENCES g_user (id_user) ON DELETE CASCADE,
   id_mark      INTEGER NOT NULL CONSTRAINT m_show_pg2m_polygon REFERENCES m_polygon (id_mark) ON DELETE CASCADE,
   id_show_pg   INTEGER CONSTRAINT m_show_pg2g_show_pg REFERENCES g_show_pg (id_show_pg) ON DELETE CASCADE,
   id_show_pl   INTEGER CONSTRAINT m_show_pg2g_show_pl REFERENCES g_show_pl (id_show_pl) ON DELETE CASCADE,
   constraint PK_M_SHOW_PG primary key (id_user, id_mark)
)
;

create index IF NOT EXISTS m_show_pg2m_polygon_fk on m_show_pg (id_mark)
;

create index IF NOT EXISTS m_show_pg2g_show_pg_fk on m_show_pg (id_show_pg)
;

create index IF NOT EXISTS m_show_pg2g_show_pl_fk on m_show_pg (id_show_pl)
;




create table IF NOT EXISTS m_show_cg (
   id_user      INTEGER NOT NULL CONSTRAINT m_show_cg2g_user REFERENCES g_user (id_user) ON DELETE CASCADE,
   id_category  INTEGER NOT NULL CONSTRAINT m_show_cg2g_category REFERENCES g_category (id_category) ON DELETE CASCADE,
   id_show_pg   INTEGER CONSTRAINT m_show_cg2g_show_pg REFERENCES g_show_pg (id_show_pg) ON DELETE CASCADE,
   id_show_pl   INTEGER CONSTRAINT m_show_cg2g_show_pl REFERENCES g_show_pl (id_show_pl) ON DELETE CASCADE,
   id_show_pt   INTEGER CONSTRAINT m_show_cg2g_show_pt REFERENCES g_show_pt (id_show_pt) ON DELETE CASCADE,
   constraint PK_M_SHOW_CG primary key (id_user, id_category)
)
;

create index IF NOT EXISTS m_show_cg2g_category_fk on m_show_cg (id_category)
;

create index IF NOT EXISTS m_show_cg2g_show_pg_fk on m_show_cg (id_show_pg)
;

create index IF NOT EXISTS m_show_cg2g_show_pl_fk on m_show_cg (id_show_pl)
;

create index IF NOT EXISTS m_show_cg2g_show_pt_fk on m_show_cg (id_show_pt)
;






create table IF NOT EXISTS g_log1 (
   id_logger    INTEGER NOT NULL,
   id_table     INTEGER NOT NULL,
   id_row       INTEGER NOT NULL,
   oper_type    TINYINT DEFAULT 0 NOT NULL,
   oper_moment  INTEGER NOT NULL DEFAULT (strftime('%s','now'))
)
;

create index IF NOT EXISTS g_log1_moment_idx on g_log1 (oper_moment,id_logger)
;

create table IF NOT EXISTS g_log2 (
   id_logger    INTEGER NOT NULL,
   id_table     INTEGER NOT NULL,
   id_row       INTEGER NOT NULL,
   id_sub       SMALLINT NOT NULL,
   oper_type    TINYINT DEFAULT 0 NOT NULL,
   oper_moment  INTEGER NOT NULL DEFAULT (strftime('%s','now'))
)
;

create index IF NOT EXISTS g_log2_moment_idx on g_log2 (oper_moment,id_logger)
;





insert OR IGNORE into g_version (id_version)
values (1)
;
