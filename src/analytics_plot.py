from trino.dbapi import connect
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os
from datetime import datetime


def main():
    # Create analytics directory if it doesn't exist
    output_dir = "assets/analytics"
    os.makedirs(output_dir, exist_ok=True)

    print("Connecting to Trino...")
    # Connect to Trino
    conn = connect(host="localhost", port=8080, user="trino", catalog="iceberg", schema="gold")
    cur = conn.cursor()

    # Define the SQL query to fetch top 10 best-selling products from the Gold layer
    query = """
        SELECT 
            p.product_name, 
            MAX(f.quantity_sold_count) as quantity_sold 
        FROM iceberg.gold.fct_product_snapshots AS f
        JOIN iceberg.gold.dim_products AS p 
            ON f.product_id = p.product_id
        WHERE f.quantity_sold_count IS NOT NULL
        GROUP BY p.product_name
        ORDER BY quantity_sold DESC 
        LIMIT 10
    """

    print("Executing query to fetch top 10 products...")
    cur.execute(query)
    rows = cur.fetchall()
    columns = [desc[0] for desc in cur.description]
    df = pd.DataFrame(rows, columns=columns)

    # Ensure lowercase column names for consistency
    df.columns = [col.lower() for col in df.columns]

    # Check if the DataFrame is not empty before plotting
    if not df.empty:
        df["short_name"] = df["product_name"].apply(
            lambda x: (x[:45] + "...") if len(x) > 45 else x
        )

        print("Plotting top 10 products by quantity sold...")
        plt.figure(figsize=(12, 7))
        ax = sns.barplot(
            data=df,
            x="quantity_sold",
            y="short_name",
            hue="short_name",
            palette="viridis",
            legend=False,
        )
        plt.title("Top 10 Best-Selling Books on Tiki", fontsize=16, fontweight="bold", pad=20)
        plt.xlabel("Quantity Sold", fontsize=12)
        plt.ylabel("Book Name", fontsize=12)

        # Add data labels to each bar
        for p in ax.patches:
            width = p.get_width()
            plt.text(
                width + (df["quantity_sold"].max() * 0.01),
                p.get_y() + p.get_height() / 2,
                f"{int(width):,}",
                ha="left",
                va="center",
            )

        plt.tight_layout()
        output_path = f'{output_dir}/top_10_books_{datetime.now().strftime("%Y%m%d_%H%M%S")}.png'
        plt.savefig(output_path, dpi=300)
        print(f"Successfully saved chart to: {output_path}")
    else:
        print("No data available to plot.")


if __name__ == "__main__":
    main()
