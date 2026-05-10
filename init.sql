-- 1. Database 'metastore' được tạo tự động bởi docker-entrypoint
--    thông qua biến môi trường POSTGRES_DB=metastore.
--    Không cần CREATE DATABASE thủ công.

-- 2. Kết nối vào database metastore
\c metastore;

-- 3. Cấp quyền cho user admin trên schema public (Dành cho Postgres 15+)
GRANT ALL ON SCHEMA public TO admin;
ALTER SCHEMA public OWNER TO admin;

-- 4. Tạo sẵn các bảng hệ thống để Iceberg không bị lỗi "Transaction Aborted"
CREATE TABLE IF NOT EXISTS iceberg_tables (
  catalog_name VARCHAR(255) NOT NULL,
  table_namespace VARCHAR(255) NOT NULL,
  table_name VARCHAR(255) NOT NULL,
  metadata_location VARCHAR(1000),
  previous_metadata_location VARCHAR(1000),
  PRIMARY KEY (catalog_name, table_namespace, table_name)
);

CREATE TABLE IF NOT EXISTS iceberg_namespaces (
  catalog_name VARCHAR(255) NOT NULL,
  namespace VARCHAR(255) NOT NULL,
  PRIMARY KEY (catalog_name, namespace)
);

CREATE TABLE IF NOT EXISTS iceberg_namespace_properties (
  catalog_name VARCHAR(255) NOT NULL,
  namespace VARCHAR(255) NOT NULL,
  property_key VARCHAR(255) NOT NULL,
  property_value VARCHAR(1000),
  PRIMARY KEY (catalog_name, namespace, property_key)
);

-- 5. Cấp quyền sở hữu bảng cho user admin
ALTER TABLE iceberg_tables OWNER TO admin;
ALTER TABLE iceberg_namespaces OWNER TO admin;
ALTER TABLE iceberg_namespace_properties OWNER TO admin;