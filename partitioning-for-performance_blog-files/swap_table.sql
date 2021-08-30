-- first rename original table, this table can be dropped later
begin;
SET search_path to data_mart;

-- Call function to move all the child table to data_mart schema
select  * from table_swap ('data_mart_new', 'data_mart', 'events' );

--ALTER TABLE  events RENAME TO events_old;
DROP TABLE events;

ALTER TABLE data_mart_new.events SET SCHEMA data_mart; -- This will only move Parent table

DROP FUNCTION table_swap(text,text,text);

--------
--save the sequences
--alter sequence events_event_id_seq rename to events_event_id_seq_old;
--alter sequence events_org_id_seq rename to events_org_id_seq_old;

commit;


