from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta

# 1. Định nghĩa các tham số mặc định
default_args = {
    'owner': 'thevinh',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# 2. Khởi tạo DAG
with DAG(
    '0_test_symlink_dag', # Tên DAG hiển thị trên giao diện
    default_args=default_args,
    description='DAG đơn giản để test kết nối symlink',
    schedule_interval=None,  # Chỉ chạy thủ công khi nhấn Trigger
    catchup=False,
    tags=['testing'],
) as dag:

    # 3. Định nghĩa một hàm Python đơn giản
    def hello_airflow():
        print("--------------------------------------------------")
        print("Chúc mừng! Symlink hoạt động tốt. Airflow đã đọc được file này!")
        print("--------------------------------------------------")

    # 4. Định nghĩa task
    t1 = PythonOperator(
        task_id='check_connection_task',
        python_callable=hello_airflow,
    )

    t1