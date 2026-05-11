import duckdb
import matplotlib.pyplot as plt
import seaborn as sns
import os
from datetime import datetime

def main():
    # Create analytics directory if it doesn't exist
    output_dir = 'assets/analytics'
    os.makedirs(output_dir, exist_ok=True)

    print("Connecting to Minio via DuckDB...")
    # Connect to Minio using DuckDB
    conn = duckdb.connect()
    conn.execute("""
        INSTALL httpfs;
        LOAD httpfs;
    """)
    # Set Minio credentials and endpoint
    conn.execute("""
        SET s3_endpoint='localhost:9000';
        SET s3_access_key_id='admin';
        SET s3_secret_access_key='password';
        SET s3_use_ssl=false;
        SET s3_url_style='path';
    """)

    # Define the SQL query to fetch top 10 best-selling products
    query = """
        SELECT 
            p.product_name, 
            MAX(f.quantity_sold) as quantity_sold 
        FROM read_parquet('s3://lakehouse/marts/fct_product_snapshots.parquet') AS f
        JOIN read_parquet('s3://lakehouse/marts/dim_products.parquet') AS p 
            ON f.product_sk = p.product_sk
        WHERE f.quantity_sold IS NOT NULL
        GROUP BY p.product_name
        ORDER BY quantity_sold DESC 
        LIMIT 10
    """

    print("Executing query to fetch top 10 products...")
    df = conn.execute(query).df()

    df['short_name'] = df['product_name'].apply(lambda x: (x[:45] + '...') if len(x) > 45 else x)

    print("Plotting top 10 products by quantity sold...")
    plt.figure(figsize=(12, 7))

    # Check if the DataFrame is not empty before plotting
    if not df.empty:
        ax = sns.barplot(data=df, x='quantity_sold', y='short_name', hue='short_name', palette='viridis', legend=False)
        plt.title('Top 10 Best-Selling Books on Tiki', fontsize=16, fontweight='bold', pad=20)
        plt.xlabel('Quantity Sold', fontsize=12)
        plt.ylabel('Book Name', fontsize=12)

        # Add data labels to each bar
        for p in ax.patches:
            width = p.get_width()
            plt.text(width + (df['quantity_sold'].max() * 0.01), p.get_y() + p.get_height() / 2, 
                     f'{int(width):,}', ha='left', va='center')
        
        plt.tight_layout()
        output_path = f'{output_dir}/top_10_books.png'
        plt.savefig(output_path, dpi=300)
        print(f"Successfully saved chart to: {output_path}")
    else:
        print("No data available to plot.")

if __name__ == "__main__":
    main()