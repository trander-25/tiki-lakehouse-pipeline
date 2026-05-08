-- 1. Tạo database metastore nếu chưa tồn tại
-- Lưu ý: Postgres mặc định không hỗ trợ CREATE DATABASE IF NOT EXISTS trực tiếp trong script đơn giản, 
-- nên ta dùng khối lệnh DO để kiểm tra.
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'metastore') THEN
        PERFORM dblink_exec('dbname=' || current_database(), 'CREATE DATABASE metastore');
    END IF;
END $$;

-- 2. Kết nối vào database metastore để phân quyền
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