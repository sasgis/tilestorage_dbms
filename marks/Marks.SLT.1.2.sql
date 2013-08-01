create table IF NOT EXISTS g_showplugin (
   id_showplugin INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
   p_id1   UNSIGNED BIG INT NOT NULL,
   p_id2   UNSIGNED BIG INT NOT NULL,
   p_file  NVARCHAR NOT NULL
)
;

create unique index IF NOT EXISTS g_showplugin_id_uniq on g_showplugin (p_id1, p_id2)
;

create unique index IF NOT EXISTS g_showplugin_file_uniq on g_showplugin (p_file)
;


create table IF NOT EXISTS g_showcat (
   id_category   INTEGER NOT NULL CONSTRAINT g_showcat2g_category REFERENCES g_category (id_category) ON DELETE CASCADE,
   id_showplugin INTEGER NOT NULL CONSTRAINT g_showcat2g_showplugin REFERENCES g_showplugin (id_showplugin) ON DELETE CASCADE,
   p_flags       INT,
   constraint PK_G_SHOWCAT primary key (id_category, id_showplugin)
)
;

create index IF NOT EXISTS g_showcat2g_showplugin_fk on g_showcat (id_showplugin)
;




create table IF NOT EXISTS g_link (
   id_link     INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
   id_owner    INTEGER NOT NULL CONSTRAINT g_link2g_user REFERENCES g_user (id_user) ON DELETE RESTRICT,
   id_category INTEGER NOT NULL CONSTRAINT g_link2g_category REFERENCES g_category (id_category) ON DELETE CASCADE,
   id_mark     INTEGER NOT NULL CONSTRAINT g_link2m_mark REFERENCES m_mark (id_mark) ON DELETE CASCADE,
   l_status    INT NOT NULL DEFAULT 0
)
;

create unique index IF NOT EXISTS g_link_uniq on g_link (id_category, id_mark)
;

create index IF NOT EXISTS g_link2g_user_fk on g_link (id_owner)
;

create index IF NOT EXISTS g_link2m_mark_fk on g_link (id_mark)
;


create table IF NOT EXISTS v_link (
   id_user    INTEGER NOT NULL CONSTRAINT v_link2g_user REFERENCES g_user (id_user) ON DELETE CASCADE,
   id_link    INTEGER NOT NULL CONSTRAINT v_link2g_link REFERENCES g_link (id_link) ON DELETE CASCADE,
   l_status   INT NOT NULL DEFAULT 0,
   s_visible  TINYINT,
   constraint PK_V_LINK primary key (id_user, id_link)
)
;

create index IF NOT EXISTS v_link2g_link_fk on v_link (id_link)
;





create table IF NOT EXISTS a_param (
   id_param    INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
   id_owner    INTEGER NOT NULL CONSTRAINT a_param2g_user REFERENCES g_user (id_user) ON DELETE RESTRICT,
   a_code      INT NOT NULL,
   a_descript  NVARCHAR NOT NULL,
   a_status    INT NOT NULL DEFAULT 0,
   a_usage     INT NOT NULL DEFAULT 0,
   a_gener     INT NOT NULL DEFAULT 0,
   a_guide     INT NOT NULL DEFAULT 0,
   a_min       INT,
   a_max       INT,
   a_def       INT
)
;

create unique index IF NOT EXISTS a_param_uniq on a_param (a_code)
;

create index IF NOT EXISTS a_param2g_user_fk on a_param (id_owner)
;


create table IF NOT EXISTS a_item (
   id_item     INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
   id_param    INTEGER NOT NULL CONSTRAINT a_item2a_param REFERENCES a_param (id_param) ON DELETE CASCADE,
   i_code      INT NOT NULL,
   i_descript  NVARCHAR,
   i_flags     INT
)
;

create index IF NOT EXISTS a_item2a_param_fk on a_item (id_param)
;

create unique index IF NOT EXISTS a_item_uniq on a_item (i_code, id_param)
;




create table IF NOT EXISTS g_param (
   id_param    INTEGER NOT NULL CONSTRAINT g_param2a_param REFERENCES a_param (id_param) ON DELETE RESTRICT,
   id_category INTEGER NOT NULL CONSTRAINT g_param2g_category REFERENCES g_category (id_category) ON DELETE CASCADE,
   id_item     INTEGER NULL CONSTRAINT g_param2a_item REFERENCES a_item (id_item) ON DELETE RESTRICT,
   a_value     INT,
   constraint PK_G_PARAM primary key (id_param, id_category)
)
;

create index IF NOT EXISTS g_param2g_category_fk on g_param (id_category)
;

create index IF NOT EXISTS g_param2a_item_fk on g_param (id_item)
;





create table IF NOT EXISTS m_param (
   id_param    INTEGER NOT NULL CONSTRAINT m_param2a_param REFERENCES a_param (id_param) ON DELETE RESTRICT,
   id_mark     INTEGER NOT NULL CONSTRAINT m_param2m_mark REFERENCES m_mark (id_mark) ON DELETE CASCADE,
   id_item     INTEGER NULL CONSTRAINT m_param2a_item REFERENCES a_item (id_item) ON DELETE RESTRICT,
   a_value     INT,
   constraint PK_M_PARAM primary key (id_param, id_mark)
)
;

create index IF NOT EXISTS m_param2m_mark_fk on m_param (id_mark)
;

create index IF NOT EXISTS m_param2a_item_fk on m_param (id_item)
;




create table IF NOT EXISTS l_param (
   id_param    INTEGER NOT NULL CONSTRAINT l_param2a_param REFERENCES a_param (id_param) ON DELETE RESTRICT,
   id_link     INTEGER NOT NULL CONSTRAINT l_param2g_link REFERENCES g_link (id_link) ON DELETE CASCADE,
   id_item     INTEGER NULL CONSTRAINT l_param2a_item REFERENCES a_item (id_item) ON DELETE RESTRICT,
   a_value     INT,
   constraint PK_L_PARAM primary key (id_param, id_link)
)
;

create index IF NOT EXISTS l_param2g_link_fk on l_param (id_link)
;

create index IF NOT EXISTS l_param2a_item_fk on l_param (id_item)
;




UPDATE g_version
SET id_version = 2
WHERE id_version = 1
;

