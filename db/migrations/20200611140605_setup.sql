-- migrate:up
CREATE TABLE IF NOT EXISTS value
  ( intval integer NOT NULL
  );

-- migrate:down
DROP TABLE IF EXISTS value;