use Portfolio_project_olist

select count(*) as total_orders 
from olist_orders_dataset;
-- 99441 total orders in orders dataset.
/*
3 -  business analytical questions-:
  1. How many orders and what was the products breached the contractual dilivery time 
  (expected_delivery_time < order_deliverd_time) and what were the average delay days for those delayed orders.
  
  2. What was the reason for these delays it was from seller side, seller made delay to provide the item to logistics carrier 
  or logistics carrier made delay in during the doorstep delivery.

  3. Is the heavy product categories taking more time to deliver and charges than lighter product categories.



================================================================================
PROJECT 1: Olist Supply Chain Logistics & SLA Breach Root Cause Analysis
AUTHOR: Naman
DATE: 02/10/2026
DATABASE: Olist Relational Sandbox
================================================================================
*/

--CTE 1- Base SLA classification and delivery lag.
with orders_sla_base as (
  select order_id,
        order_status,
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date,
       case when order_delivered_customer_date > order_estimated_delivery_date then 'Late' else 'on time' end as order_delivered_status,
       --Total customer delays days past delivery date-
       datediff(day, order_estimated_delivery_date, order_delivered_customer_date) as customer_delay_days,
       --days between the seller delivery to carrier services
       datediff(day, order_approved_at, order_delivered_carrier_date) as seller_handling_days,
       --Carrier delivery days
       datediff(day, order_delivered_carrier_date, order_delivered_customer_date) as carrier_transit_days
  from olist_orders_dataset 
  where order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_delivered_carrier_date IS NOT NULL
      AND order_approved_at IS NOT NULL
),
--CTE 2: Product Dimension Enrichment via INNER JOIN
line_item_enriched as (
  select b.order_id,
        b.order_delivered_status,
        b.customer_delay_days,
        b.seller_handling_days,
        b.carrier_transit_days,
        oi.product_id,
        Coalesce(p.product_category_name, 'unknown') as product_category_name,
        p.product_weight_g
  from orders_sla_base as b
    INNER JOIN olist_order_items_dataset oi 
        ON b.order_id = oi.order_id
    INNER JOIN olist_products_dataset p 
        ON oi.product_id = p.product_id
)

--Main query A:  Bottleneck discomposition (seller vs carrier)
select order_delivered_status,
       count(distinct order_id) as total_orders,
       round(avg(cast(seller_handling_days AS FLOAT)), 2) AS avg_seller_handling_days,
       round(avg(cast(carrier_transit_days AS FLOAT)), 2) AS avg_carrier_transit_days,
       round(avg(cast(customer_delay_days AS FLOAT)), 2) AS avg_delay_after_breach_days
from orders_sla_base
where order_delivered_status = 'Late'
group by order_delivered_status;
/*
--Main query B: Product Category Vulnerability Matrix (Top 5 Lagging Categories)
select product_category_name,
       count(distinct order_id) as total_delayed_orders,
       round(avg(cast(customer_delay_days AS FLOAT)), 2) AS avg_delay_after_breach_days,
       round(avg(cast(carrier_transit_days AS FLOAT)), 2) AS avg_carrier_transit_days,
       round(avg(cast(seller_handling_days AS FLOAT)), 2) AS avg_seller_handling_days,
       ROUND(AVG(CAST(product_weight_g AS FLOAT)), 2) AS avg_weight_grams
from line_item_enriched
where order_delivered_status = 'Late'
group by product_category_name
having count(distinct order_id) >= 20
order by avg_delay_after_breach_days desc,
avg_weight_grams desc;
*/