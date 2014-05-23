select * from pg_class where relname = 'apiario';

select * from pg_attribute where attname in ('nom_apicul', 'num_colmei') 

select * from pg_type

select attname, format_type(a.atttypid, a.atttypmod)
from pg_attribute a join pg_class b on (a.attrelid = b.relfilenode) where b.relname = 'apiario' and a.attstattarget = -1;

SElect cast('2343' as double precision) as number


SELECT pg_relation_filepath(oid), relpages FROM pg_class WHERE relname = 'apiario';

SELECT * FROM information_schema.columns


-- Calcular tamanho ocupado pelas tabelas (para ver se vale a pena guardar apenas as colunas alteradas, ou não)
SELECT t.oid, n.nspname as schema_name, relname::char(35) as Table_Name,
     pg_size_pretty(pg_total_relation_size(t.oid))::VARCHAR(15) as Total_Table_Size
FROM pg_class as t JOIN pg_catalog.pg_namespace n ON n.oid = t.relnamespace
WHERE relname like '%_bk'

