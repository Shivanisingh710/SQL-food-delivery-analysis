create database Project;
use project;

# Given 4 csv files with the following schema

# customers - (cid, cname, age, gender)
# restaurants - (res_id, res_name, city, location)
# menu - (menu_id, res_id, item_name, veg/non-veg, res_price, app_price)
# orders - (order_id, menu_id, cust_id, qty, order_date, order_time, eta, delivery_time)

select * from orders;
select * from menu;
select * from restaurants;

# Load these csv files in any database using Table Data Import wizard
# and solve these questions below


# Basic Questions

# Q1) Find Res with more than 50 orders

select r.res_id,r.res_name,count(o.order_id) Num_of_orders
from restaurants r 
join menu m on r.res_id = m.res_id
join orders o on m.menu_id = o.menu_id 
group by r.res_id,r.res_name
having Num_of_orders > 50;

# Q2) Find the top 5 customers by total quantity ordered.

select c.cid,c.cname,o.qty 
from customers c
join orders o on c.cid = o.cust_id
order by o.qty desc 
limit 5;

# Q3) Find each customer's first order date and last order date
# only for those customers who have placed multiple orders

select c.cid,c.cname,min(o.order_date) First_Order_Date, 
max(o.order_date) Last_Order_Date,count(o.order_id) num_of_orders
from orders o               
join customers c on c.cid = o.cust_id
group by c.cid,c.cname
having num_of_orders > 1
order by num_of_orders desc;

# Q4) Find customers who ordered from more than 3 distinct restaurants.

select count(distinct r.res_id) rest_count,c.Cid,c.cname
from restaurants r 
join menu m on r.res_id = m.res_id
join orders o on m.menu_id = o.menu_id 
join customers c on c.cid = o.cust_id
group by  c.Cid,c.cname
having rest_count>3;


# Q5) Find month wise total revenue

select Distinct monthname(o.order_date) Mon,month(o.order_date) Mon_num,sum(m.app_price) Total_Revenue 
from orders o 
join menu m on o.menu_id = o.menu_id
group by Mon,Mon_num
order by Mon_num;

# Q6) Find each restaurant's average delivery delay 
# Display res_id,order_time, delivery_time, diff, eta

select distinct r.res_id, o.order_time,o.delivery_time,o.eta,
minute(timediff(o.delivery_time,o.order_time)) diff,
round(avg(minute(timediff(o.delivery_time,o.order_time)))
over (partition by r.res_id),2) avg_delay_min
from orders o
join menu m on o.menu_id = m.menu_id
join restaurants r on r.res_id = m.res_id;


# Q7) Find menu items where app price is higher than restaurant price
# Display item_name, res_price, app_price
select item_name, res_price, app_price 
from menu
where app_price > res_price;

# Questions on 
# Subqueries, Window Functions, Self-join, Joins


# Q1) Find most expensive menu item in each restaurant ?
select res_id,item_name,res_price
from(
select res_id,item_name,res_price,
dense_rank() over (partition by res_id order by res_price desc) Rnk
from menu)dt
where rnk =1;

# Q2) Find customers whose total orders exceed the average orders 
# placed by all customers.
select cust_id,count(order_id) Total_orders 
from orders
group by cust_id 
having Total_orders >
(select avg(order_count) from 
(select count(order_id) order_count
from orders group by cust_id )dt); 
 

# Q3) Rank customers based on total spending. 
# Display cust_id,total_spend and rank. Display top 15 Ranks
select *
from
(select cust_id, Total_spend, 
rank() over (order by Total_Spend desc) rnk
from
(select o.cust_id, sum(o.qty * m.app_price) Total_Spend
 from menu m
join orders o
on m.menu_id = o.menu_id
group by o.cust_id) dt) dt1
where rnk <= 15;

# Q4) Find the top 3 highest priced item in the menu for each city
select * 
from
(select m.app_price, 
        r.city, 
        dense_rank() over 
        (partition by r.city 
         order by m.app_price
         desc) rnk
from menu m 
join restaurants r 
on r.res_id = m.res_id) dt
where rnk <= 3;

# Q5) Find running revenue by order month for 2024
select Running_Sales 
from
(select distinct sum(revenue) 
        over(order by month(order_date)) 
        as Running_Sales, 
		monthname(order_date),
        year(order_date) yr
from
(
    select o.order_date,
    (o.qty * m.app_price) as revenue
    from menu m
    join orders o
    on m.menu_id = o.menu_id
) dt
having yr = 2024) dt1;

# Q6) Find menu items never ordered.

select item_name 
from menu 
where menu_id 
not in 
(select menu_id 
from orders);

# Q7) Find top 4 ordered item per restaurant
# Display res_name, item_name, total_qty, rank
select * 
from
(select *, 
rank() over (partition by res_name order by most_ordered desc) rnk
from
(select distinct r.res_name, m.item_name, 
sum(o.qty) over (partition by r.res_name,m.item_name) most_ordered
from orders o
join menu m 
on o.menu_id = m.menu_id
join restaurants r 
on r.res_id = m.res_id) dt) dt1
where rnk <= 4;

# Q8) Find customers whose spending is above their own gender 
# average spending. Display cust_id, gender, spend, avg_spend by gender

select cid, gender, spend, avg_spend 
from
(select *, avg(Spend) over (partition by gender) avg_spend
from
(select c.cid, c.gender, sum(m.app_price*o.qty) Spend
from menu m
join orders o 
on o.menu_id = m.menu_id
join customers c
on c.cid = o.cust_id
group by c.cid, c.gender) dt) dt1
where Spend > avg_spend; 


# Q9) Find the latest order placed by each customer.
# Display all columns from orders

select * 
from
(select *,
        row_number() over 
        (partition by cust_id 
        order by order_date desc) rn
from 
	orders) dt
where rn = 1;

# Q10) Find customers with consecutive-day orders.

select *
from
(select *, 
lag(order_date) over (partition by cust_id order by order_date) prev_date
from orders) dt
where datediff(order_date,prev_date) = 1;

# Q11) Find percentage contribution of each restaurant to total revenue.

select distinct
       dt.res_id,
       (Res_Revenue/Total_Revenue)*100 `Res%_Contri`
from       
(
select o.order_id,
        o.menu_id,
        r.res_id,
        m.app_price,
        o.qty,
        sum(m.app_price*o.qty) over(partition by r.res_id) Res_Revenue,
        sum(m.app_price*o.qty) over()  Total_Revenue
from orders o
join menu m
	on o.menu_id = m.menu_id
join restaurants r
    on m.res_id = r.res_id
    ) dt;
 
# Q12) Find the bottom 3 least ordered items overall(least ordered in terms of qty)
select dt1.item_name, 
       rnk
from
(select
       *,
       dense_rank() over
       (order by dt.Qty) rnk
from
(select distinct 
       m.item_name, 
       count(o.qty) over (partition by m.item_name) Qty
from orders o
join menu m
	on o.menu_id = m.menu_id) dt) dt1
where rnk <= 3;

# Q13) Find restaurants whose Avg revenue is above average restaurant revenue.
# Dispaly res_id and revenue

select distinct
      dt.res_id,
      Revenue,
      Avg_Res_Revenue
from
(select 
      m.app_price,
      o.qty,
      m.menu_id,
      r.res_id,
	  avg(m.app_price*o.qty) over (partition by r.res_id) Revenue,
      avg(m.app_price*o.qty) over() Avg_Res_Revenue
from orders o
join menu m
	on o.menu_id = m.menu_id
join restaurants r
    on m.res_id = r.res_id) dt	
having
    Revenue > Avg_Res_Revenue;
     
# Q14) Find each customer's preferred restaurant (most ordered from).
select distinct
      cust_id,
      res_name
from      
(select 
	*, dense_rank() over 
    (partition by cust_id order by order_num desc) 
	 drnk
from
(select
      r.res_name,
      o.cust_id,
      count(o.order_id) Order_num
from orders o
join menu m
	on o.menu_id = m.menu_id
join restaurants r
    on m.res_id = r.res_id
group by 
     r.res_name,
     o.cust_id) dt) dt1
where drnk = 1;
    
# Q15) Find customers whose spending is above the average spending 
# of customers from the same age group (18–25, 26–35, 36–45).
# Display cid, age_group, spend, avg_group_spend
select 
      cid,
      age_group,
      spend,
      avg_group_spend
from
(select 
	  *,
      avg(Spend) over(partition 
      by age_group) 
      avg_group_spend
from
(select 
      c.cid, 
      (case
           when c.age between 18 and 25 then '18-25'
           when c.age between 26 and 35 then '26-35'
           when c.age between 36 and 45 then '36-45'
	   end)   age_group,
       sum(m.app_price*o.qty) Spend
from customers c
join orders o
    on o.cust_id = c.cid
join menu m
	on m.menu_id = m.menu_id
group by c.cid, age_group) dt) dt1
where Spend > Avg_group_spend;
       
# Q16) Find the top 2 restaurants by revenue in each city.
# Dispaly city, restaurant_name, revenue,rank

select
      city,
      res_name,
      Revenue,
      rnk
from      
(select 
      *,
      dense_rank() over
      (order by Revenue desc) rnk
from
(select 
      r.city,
      r.res_id,
      r.res_name,
      sum(m.app_price*o.qty) Revenue
from orders o
join menu m
	on o.menu_id = m.menu_id
join restaurants r
    on m.res_id = r.res_id
group by r.city,
         r.res_id,
         r.res_name) dt) dt1
where rnk <= 2;

# Q17) Find customers whose latest order value is greater than their 
# average historical order value.
# Display cust_id, order_id, oerder_value, avg_order_value, rank

select
      *
from      
(select
	  cust_id,
      order_id,
      order_value,
      Avg_order_value,
      row_number() over 
	  (partition by cust_id 
	  order by order_date desc) Latest
from      
(select
      *,
      avg(order_value) over
      (partition by cust_id)  avg_order_value
from
(select
	  o.cust_id,
      o.order_id,
      o.order_date,
      sum(m.app_price*o.qty) order_value
from menu m
join orders o
    on m.menu_id = o.menu_id
group by o.cust_id,
         o.order_id,
         o.order_date) dt) dt1
where order_value > avg_order_value) dt2
where latest = 1;

# Q18) Find restaurants whose most expensive item is above 
# the overall average max item price.
# Display res_id, max_price

select
      res_id,
      max_price
from
(select
      *,
      avg(max_price) 
      over()  
      average_max_item_price
from
(select 
        res_id,
        item_name,
        app_price,
        max(app_price) 
        over(partition by res_id) 
        Max_price
from menu ) dt
where max_price = app_price) dt1
where max_price > average_max_item_price;

# Q19) Find menu items whose revenue is above the average revenue 
# of items in the same restaurant.
# Display res_id, item_name, revenue, avg_res_item_rev

select 
      *
from      
(select
      *,
      avg(Revenue) over (partition by res_id)
      avg_res_item_rev
from
(select
	  m.res_id,
      m.item_name,
      sum(m.app_price*o.qty) Revenue
from orders o
join menu m
    on m.menu_id = o.menu_id
group by m.res_id,
         m.item_name) dt) dt1
where revenue > avg_res_item_rev; 


# Q20) Find customers who have ordered every restaurant available in their city.
# Display cid
select distinct
      cust_id
from      
(select
     cust_id,
      city,
      res_count 
from      
(select 
      o.cust_id,
      r.city,
      count(distinct r.res_id) res_count
from orders o
join menu m
	on o.menu_id = m.menu_id
join restaurants r
    on m.res_id = r.res_id
group by o.cust_id,
         r.city) dt
where res_count in
(select res_city_count
from 
(select 
      count(distinct res_id) res_city_count, 
	  city 
from      
     restaurants
group by
      city) dt1) )dt2;

# Q21) Find revenue growth/decline for each restaurant compared to previous order date.
# Display res_id, order_date, revenue, revenue_change

select
      res_id,
      order_date,
      revenue,
      (revenue - revenue_prev) revenue_change
from
(select
	  *,
      lag(Revenue,1,Revenue) 
      over(partition by res_id 
      order by order_date) 
      Revenue_prev
from      
(select
	  m.res_id,
      o.order_date,
      sum(m.app_price*o.qty) Revenue
from orders o
join menu m
	on m.menu_id = o.menu_id
group by m.res_id,
         o.order_date) dt) dt1;
    
# Q22) Find customers whose total spend ranks in top 10%.
# Display cust_id,spend and spend_decile (Hint use ntile window function)

select
      *
from      
(select
      o.cust_id,
      sum(m.app_price*o.qty) Spend,
      ntile(10) over(order by 
      sum(m.app_price*o.qty) desc) 
      Spend_decile
from orders o
join menu m
	on m.menu_id = o.menu_id
group by o.cust_id) dt
where spend_decile = 1;
   
# Q23) Find the most frequently ordered pair of menu items by same customer.

Select
    o1.cust_id,
    m1.item_name item_1,
    m2.item_name item_2,
    COUNT(*) pair_count
from orders o1
join orders o2
    on o1.cust_id = o2.cust_id
    and o1.order_date = o2.order_date
    and o1.order_id < o2.order_id
join menu m1
    on o1.menu_id = m1.menu_id
join menu m2
    on o2.menu_id = m2.menu_id
group by item_1, item_2, o1.cust_id
order by pair_count desc;

# Q24) Find pairs of customers who placed orders on the same date.
# Solve using self-join. Display cust1_name, cust2_name, order_date

create or replace view vi as
select distinct 
       o.cust_id,
	   c.cname, 
       o.order_id,
       o.order_date,
       c.age
from customers c
join orders o
    on c.cid = o.cust_id;

Select v1.cname cust1_name,
	   v2.cname cust2_name,
       v1.order_date
from Vi v1
join Vi v2
    on v1.order_date = v2.order_date
    and v1.cust_id != v2.cust_id
order by order_date desc;

select * from customers;


# Q25) Find duplicate-aged customer pairs
# Dispaly Cust1_name, cust2_name and age

Select  v1.cname cust1_name,
	    v2.cname cust2_name,
        v1.age
from Vi v1
join Vi v2
    on v1.age = v2.age
    and v1.cust_id < v2.cust_id
group by v1.cname, v2.cname, v1.age
having count(*) >= 1
order by v1.age desc;

# Q26) Find customers who never ordered from the same restaurant twice

select dt.cust_id
from
(select m.res_id,
       o.cust_id,
       count(*) Total_orders
from orders o
join menu m 
     on o.menu_id = m.menu_id
group by m.res_id,
         o.cust_id
order by m.res_id,
         o.cust_id) dt
where total_orders = 1;


# Q27) Find restaurants where veg items qty solds out number non-veg items
# qty sold

select dt.res_id
from
(select m.res_id,
sum(case when m.`veg/non-veg`='veg' 
     then o.qty else 0 end) veg_qty,
sum(case when m.`veg/non-veg`='non-veg' 
     then o.qty else 0 end) non_veg_qty
from menu m 
join orders o 
   on m.menu_id=o.menu_id
group by m.res_id) dt
where dt.veg_qty > dt.non_veg_qty;

# Q28) Find top 3 menu items with maximum markup percentage
# markup_percentage = % diff between app_price and res_price

select *
from
(select *,
       dense_rank() over
       (partition by res_id 
	   order by markup_percentage desc) rnk
from
(select res_id,
        menu_id,
	    item_name,
       (((app_price - res_price)/app_price) * 100)  
       markup_percentage
from menu) dt) dt2
where dt2.rnk <= 3;

# Q29) Find restaurants whose average markup exceeds overall average markup
# markup = app_price - res_price
# Dispaly res_name

select distinct res_name
from
(select m.res_id,
	   r.res_name,
       avg(m.app_price - m.res_price) 
       over(partition by m.res_id) 
       avg_markup
from menu m
join restaurants r
     on r.res_id = m.res_id) dt
where avg_markup > (select avg(app_price - res_price) price 
                      from menu);

# Q30) Rank restaurants by total commission earned
# Display res_name, total_commission, commission_rank

select *,
       dense_rank() over(order by dt.total_commission) Rnk
from
(select r.res_name,
       sum(m.app_price-m.res_id)  total_commission
from menu m
join restaurants r
     on m.res_id = r.res_id
group by r.res_name) dt;

# Q31) Find menu items priced above restaurant's own average app price
# Display item_name, res_name, app_price

select dt.item_name, dt.res_name, dt.app_price
from
(select m.item_name,
	   avg(m.app_price) over(partition by m.res_id) Avg_price,
       r.res_name,
       m.app_price
from menu m
join restaurants r
     on m.res_id = r.res_id) dt
where dt.app_price > dt.Avg_price;
     

# Q32) Find orders where total commission exceeded order average commission
# Commission = app_price - res_price
# Display ordeR_id, commission

select dt.order_id,
	   dt.commission
from
(select o.order_id,
       (m.app_price - m.res_price)  commission,
       avg(m.app_price - m.res_price) over() average_commission
from menu m 
join orders o 
   on m.menu_id=o.menu_id) dt
where dt.commission > dt.average_commission;

# Q33) Find restaurant with highest average commission per restaurant item sold
# Display res_name avg_commission, rank

select *
from
(select distinct dt.res_name,
        average_commission, 
	   dense_rank() over(order by 
       average_commission desc) rnk
from
(select r.res_name,
       avg(m.app_price - m.res_price) over
       (partition by m.res_id) 
       average_commission
from menu m
join restaurants r
     on m.res_id = r.res_id) dt) dt1
where dt1.rnk = 1;










