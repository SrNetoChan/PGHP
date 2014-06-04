select * from pg_class order by relname where relname IN ('usos','PGHP','PGHP_') ;
select * from pg_namespace


select * from pg_attribute where attrelid = 140128 attname in ('nom_apicul', 'num_colmei') 

select * from pg_type

select c.nspname, b.relname, a.attname, format_type(a.atttypid, a.atttypmod)
from pg_attribute a join pg_class b on (a.attrelid = b.relfilenode) join pg_namespace c on (c.oid = b.relnamespace )
where b.relname = 'usos' and a.attstattarget = -1;

-- CRIAR Função para obter tipo de attributo de input

 

SElect cast('2343' as double precision) as number


SELECT pg_relation_filepath(oid), relpages FROM pg_class WHERE relname = 'apiario';

SELECT * FROM information_schema.columns


-- Calcular tamanho ocupado pelas tabelas (para ver se vale a pena guardar apenas as colunas alteradas, ou não)
SELECT t.oid, n.nspname as schema_name, relname::char(35) as Table_Name,
     pg_size_pretty(pg_total_relation_size(t.oid))::VARCHAR(15) as Total_Table_Size
FROM pg_class as t JOIN pg_catalog.pg_namespace n ON n.oid = t.relnamespace
WHERE relname like '%_bk'



CREATE OR REPLACE FUNCTION "vsr_get_data_type"(_t regclass, _c text)
  RETURNS text AS
$body$
DECLARE
	_schema text;
	_table text;
	data_type text;
BEGIN
	-- Prepare names to use in index and trigger names
	IF _t::text LIKE '%.%' THEN
		_schema := regexp_replace (split_part(_t::text, '.', 1),'"','','g');
		_table := regexp_replace (split_part(_t::text, '.', 2),'"','','g');
	ELSE
		_schema := 'public';
		_table := regexp_replace(_t::text,'"','','g');
	END IF;

	data_type := (SELECT format_type(a.atttypid, a.atttypmod)
	FROM pg_attribute a 
	JOIN pg_class b ON (a.attrelid = b.relfilenode)
	JOIN pg_namespace c ON (c.oid = b.relnamespace)
WHERE
	b.relname = _table AND
	c.nspname = _schema AND
	a.attname = _c);
	
	RETURN data_type;
END
$body$ LANGUAGE plpgsql;


SELECT vsr_get_data_type('"PGHP_2".testes_versioning','descr')



(SELECT 'o' || '.' || c.column_name
			FROM information_schema.columns As c
			WHERE table_schema = 'PGHP' and table_name = 'usos')



SELECT 'first(g' || '.' || a.attname || ')::' || format_type(a.atttypid, a.atttypmod) || ' as ' || a.attname
FROM 
	pg_attribute a 
	JOIN pg_class b ON (a.attrelid = b.relfilenode)
	JOIN pg_namespace c ON (c.oid = b.relnamespace)
WHERE
	b.relname = 'usos' AND
	c.nspname = 'PGHP' AND
	a.attname IN (


SELECT c.column_name, vsr_get_data_type('"PGHP".usos',c.column_name)
FROM information_schema.columns As c
WHERE table_name = 'usos' and table_schema = 'PGHP';


(SELECT c.column_name
			FROM information_schema.columns As c
			WHERE table_schema = 'PGHP' and table_name = 'usos')

select 1::varchar(10)
select 1::character varying(10)
