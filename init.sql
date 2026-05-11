-- 1. Database 'metastore' được tạo tự động bởi docker-entrypoint
--    thông qua biến môi trường POSTGRES_DB=metastore.
--    Không cần CREATE DATABASE thủ công.

-- 2. Kết nối vào database metastore
\c metastore;

-- 3. Cấp quyền cho user admin trên schema public (Dành cho Postgres 15+)
GRANT ALL ON SCHEMA public TO admin;
ALTER SCHEMA public OWNER TO admin;
