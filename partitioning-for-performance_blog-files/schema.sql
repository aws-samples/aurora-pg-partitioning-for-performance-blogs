CREATE SCHEMA data_mart;
CREATE TABLE data_mart.organization ( org_id BIGSERIAL,
        org_name TEXT,
        CONSTRAINT pk_organization PRIMARY KEY (org_id)  
    );

CREATE TABLE data_mart.events(
        event_id        BIGSERIAL, 
        operation       CHAR(1), 
        value           FLOAT(24), 
        parent_event_id BIGINT, 
        event_type      VARCHAR(25), 
        org_id          BIGSERIAL, 
        created_at      timestamptz, 
        CONSTRAINT pk_data_mart_event PRIMARY KEY (event_id, created_at), 
        CONSTRAINT ck_valid_operation CHECK (operation = 'C' OR operation = 'D'), 
        CONSTRAINT fk_orga_membership 
            FOREIGN KEY(org_id) 
            REFERENCES data_mart.organization (org_id),
        CONSTRAINT fk_parent_event_id 
            FOREIGN KEY(parent_event_id, created_at) 
            REFERENCES data_mart.events (event_id,created_at)
    ) ;

CREATE INDEX idx_org_id     ON  data_mart.events(org_id);
CREATE INDEX idx_event_type ON  data_mart.events(event_type);
