-- migrate:up
CREATE TABLE IF NOT EXISTS Values
  ( intvalue integer NOT NULL
  );

-- migrate:down
DROP TABLE IF EXISTS Values;