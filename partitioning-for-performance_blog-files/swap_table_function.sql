SET SEARCH_PATH=data_mart;
CREATE OR REPLACE FUNCTION table_swap (IN SOURCE_SCHEMA TEXT, IN DEST_SCHEMA TEXT, IN TABLE_NAME text,out p_table regclass)
LANGUAGE PLPGSQL
AS $$
        DECLARE
           s_schema ALIAS FOR $1;
           d_schema ALIAS FOR $2;
           parent_table ALIAS  for $3;
           p_table regclass;
BEGIN
           FOR p_table IN
                      select c.oid::pg_catalog.regclass 
						 FROM pg_catalog.pg_class c, pg_catalog.pg_inherits i 
						 WHERE c.oid=i.inhrelid 
							AND i.inhparent in (SELECT c.oid FROM pg_catalog.pg_class c
                             LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
                        WHERE c.relname OPERATOR(pg_catalog.~) ('^(' || parent_table ||')$') COLLATE pg_catalog.default
                          AND n.nspname OPERATOR(pg_catalog.~) ('^('|| s_schema ||')$') COLLATE pg_catalog.default) ORDER BY pg_catalog.pg_get_expr(c.relpartbound, c.oid) = 'DEFAULT',          c.oid::pg_catalog.regclass::pg_catalog.text

                   LOOP
                         EXECUTE format('ALTER TABLE %s SET SCHEMA %s', p_table,d_schema );   END LOOP;


END;$$;
