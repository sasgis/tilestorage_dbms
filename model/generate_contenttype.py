# -*- coding: utf-8 -*-

data = [
    (1, 'image/png'),
    (2, 'image/jpeg'),
    (3, 'image/jpg'),
    (4, 'image/gif'),
    (5, 'image/tiff'),
    (6, 'image/svg+xml'),
    (7, 'image/vnd.microsoft.icon'),
    (8, 'image/jp2'),
    (9, 'image/bmp'),
    (10, 'image/webp'),

    (65, 'application/vnd.google-earth.kml+xml'),
    (66, 'application/gpx+xml'),
    (67, 'application/vnd.google-earth.kmz'),
    (68, 'application/xml'),
    (69, 'application/json'),
    (70, 'application/geo+json'),
    (71, 'application/vnd.sas.wikimapia.kml+xml'),
    (72, 'application/vnd.sas.wikimapia.kmz'),
    (73, 'application/vnd.sas.wikimapia.txt'),

    (91, 'text/html'),
    (92, 'text/plain')
]

# Sybase ASA
with open('ASA.txt', 'w', encoding='utf-8', newline='\r\n') as f:
    for item_id, content_type in data:
        f.write(f"""INSERT INTO Z_CONTENTTYPE (id_contenttype, contenttype_text) ON EXISTING SKIP VALUES
({item_id}, '{content_type}')
;

""")

# Sybase ASE, Microsoft SQL Server
with open('ASE_MS.txt', 'w', encoding='utf-8', newline='\r\n') as f:
    for item_id, content_type in data:
        f.write(f"""if not exists(select 1 from Z_CONTENTTYPE where id_contenttype={item_id})
begin
  insert into Z_CONTENTTYPE (id_contenttype, contenttype_text)
  values ({item_id}, '{content_type}')
end
go

""")

# MimerSQL
with open('MMR.txt', 'w', encoding='utf-8', newline='\r\n') as f:
    for item_id, content_type in data:
        f.write(f"""begin
if not exists(select 1 from Z_CONTENTTYPE where id_contenttype={item_id})
then
  insert into Z_CONTENTTYPE (id_contenttype, contenttype_text)
  values ({item_id}, '{content_type}');
end if;
end
;

""") 

# MySQL
with open('MY.txt', 'w', encoding='utf-8', newline='\r\n') as f:
    value_strings = []
    for item_id, content_type in data:
        value_strings.append(f"({item_id}, '{content_type}')")

    f.write(',\n'.join(value_strings))

# DB2, Informix, Oracle   
with open('DB2_IFX_ORA.txt', 'w', encoding='utf-8', newline='\r\n') as f:
    select_statements = []
    for item_id, content_type in data:
        select_statements.append(f"select {item_id} as id, '{content_type}' as name from dual")
        
    f.write('\nunion all\n'.join(select_statements))
    
# FireBird   
with open('FB.txt', 'w', encoding='utf-8', newline='\r\n') as f:
    select_statements = []
    for item_id, content_type in data:
        select_statements.append(f"select {item_id} as id, '{content_type}' as name from rdb$database")
        
    f.write('\nunion all\n'.join(select_statements))
    
# PostgreSQL
with open('PG.txt', 'w', encoding='utf-8', newline='\r\n') as f:
    for item_id, content_type in data:
        f.write(f"""do $$
begin
if not exists(select 1 from Z_CONTENTTYPE where id_contenttype={item_id})
then
  insert into Z_CONTENTTYPE (id_contenttype, contenttype_text)
  values ({item_id}, '{content_type}');
end if;
end;
$$
;

""")
