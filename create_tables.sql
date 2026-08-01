-- Customer Profiles
CREATE TABLE customer_profiles
(
	customer_id			  INTEGER PRIMARY KEY,
	age					  SMALLINT,
	gender				  VARCHAR(20),
	location			  VARCHAR(50),
	join_date			  DATE
);

-- Product Inventory
CREATE TABLE product_inventory
(
	product_id 			INTEGER PRIMARY KEY,
	product_name		VARCHAR(100),
	category			VARCHAR(50),
	stock_level			INTEGER,
	price				NUMERIC(10,2)
);

-- Sales Transactions
CREATE TABLE sales_transaction_staging 
(
    transaction_id      INTEGER,
    customer_id         INTEGER,
    product_id          INTEGER,
    quantity_purchased  INTEGER,
    transaction_date    DATE,
    price               NUMERIC(10, 2)
);


