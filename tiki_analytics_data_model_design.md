# Tiki Analytics Data Model Design (Star Schema for Power BI)

This document provides a detailed overview of the redesigned dimensional model (Star Schema) developed inside the Tiki Lakehouse. This structure is optimized specifically for Power BI, enabling intuitive dashboard building, auto-detected hierarchies, and advanced business analysis.

---

## 1. Dashboard Objectives & Audience (Business Requirements)

* **Target Audience**: Category Manager / Marketplace Sellers on Tiki.
* **Objective**: Market Intelligence Analysis and Competitor Monitoring.
* **Specific Use Cases Addressed**:
  * **a) Daily Market Volume & GMV**: Tracking daily fluctuations in estimated GMV and actual quantities sold.
  * **b) Market Share Analysis**: Segmenting market share percentage between different Sellers and Publishers/Authors (Company/Brand).
  * **c) Potential Product Discovery**: 
    * Identifying potential books (e.g., high average ratings but low sales counts).
    * Identifying trending books (fastest sales volume growth over a 7-day window).
  * **d) Pricing & Promotion Strategy**: Analyzing competitor price fluctuations, list price margins, and active discount distributions.

---

## 2. Schema Architecture Overview

The redesigned model transitions from a wide-flat structure to a classic **Kimball Star Schema**. This minimizes redundant data joins, creates clean single-direction filters, and leverages native calendar properties.

```mermaid
erDiagram
    dim_products ||--o{ fct_product_snapshots : "product_id"
    dim_sellers ||--o{ fct_product_snapshots : "seller_id"
    dim_categories ||--o{ fct_product_snapshots : "category_key"
    dim_dates ||--o{ fct_product_snapshots : "date_key"

    dim_products {
        varchar product_id PK
        varchar product_sku
        varchar product_name
        varchar url_path
        varchar thumbnail_url
        varchar brand_name "Brand or Author/Publisher"
        varchar book_cover
    }
    dim_sellers {
        varchar seller_id PK
        varchar seller_type
        varchar seller_name
    }
    dim_categories {
        varchar category_key PK
        varchar category_l1
        varchar category_l2
        varchar category_l3
        varchar primary_category_name
    }
    dim_dates {
        integer date_key PK "YYYYMMDD Integer"
        date date_value "True DATE Type"
        integer year
        integer month
        integer day
        integer quarter
        integer day_of_week_num
        varchar day_name
        varchar month_name
    }
    fct_product_snapshots {
        timestamp extracted_at
        integer date_key FK "YYYYMMDD Integer"
        varchar product_id FK
        varchar seller_id FK
        varchar category_key FK
        double current_price
        double list_price
        double discount
        double discount_rate
        double original_price
        double rating_average
        integer review_count
        integer order_count
        integer favourite_count
        integer cumulative_quantity_sold
        integer daily_quantity_sold
        double daily_gmv
        boolean is_discounted
    }
```

---