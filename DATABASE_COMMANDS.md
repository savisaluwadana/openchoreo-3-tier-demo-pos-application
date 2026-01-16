# PostgreSQL Docker Database Commands

This document contains all the commands you need to interact with and test your PostgreSQL database running in Docker.

---

## 🐳 Container Management

### Check if the container is running
```bash
docker ps
```

### Start the database container
```bash
docker-compose up -d
```

### Stop the database container
```bash
docker-compose down
```

### Restart the database container
```bash
docker-compose restart postgres
```

### Stop and remove all data (fresh start)
```bash
docker-compose down -v
docker-compose up -d
```

---

## 📊 View Logs

### View database logs
```bash
docker-compose logs postgres
```

### View live database logs (follow mode)
```bash
docker-compose logs -f postgres
```

### View last 50 lines of logs
```bash
docker-compose logs --tail=50 postgres
```

---

## 💻 Access PostgreSQL CLI

### Enter the PostgreSQL interactive shell
```bash
docker exec -it inventory_postgres psql -U postgres -d inventory_db
```

---

## 🔍 SQL Commands (Inside PostgreSQL CLI)

Once you're inside the PostgreSQL CLI using the command above, you can run these SQL commands:

### List all tables
```sql
\dt
```

### View the products table structure
```sql
\d products
```

### View all databases
```sql
\l
```

### View all users/roles
```sql
\du
```

### Count all products
```sql
SELECT COUNT(*) FROM products;
```

### View all products
```sql
SELECT * FROM products;
```

### View specific columns
```sql
SELECT id, name, sku, quantity, price FROM products;
```

### View products ordered by price
```sql
SELECT * FROM products ORDER BY price DESC;
```

### Filter products by quantity
```sql
SELECT * FROM products WHERE quantity > 10;
```

### Insert a test product
```sql
INSERT INTO products (name, description, sku, quantity, price) 
VALUES ('Test Product', 'This is a test', 'TEST-001', 5, 99.99);
```

### Verify the insert
```sql
SELECT * FROM products WHERE sku = 'TEST-001';
```

### Update the test product
```sql
UPDATE products SET quantity = 10 WHERE sku = 'TEST-001';
```

### Update multiple fields
```sql
UPDATE products 
SET quantity = 15, price = 89.99 
WHERE sku = 'TEST-001';
```

### Delete the test product
```sql
DELETE FROM products WHERE sku = 'TEST-001';
```

### Delete all products (careful!)
```sql
DELETE FROM products;
```

### Exit PostgreSQL CLI
```sql
\q
```

---

## ⚡ Quick SQL Queries (Without Entering CLI)

### Run a single SQL query directly
```bash
docker exec -it inventory_postgres psql -U postgres -d inventory_db -c "SELECT * FROM products;"
```

### Count products
```bash
docker exec -it inventory_postgres psql -U postgres -d inventory_db -c "SELECT COUNT(*) FROM products;"
```

### View specific product by SKU
```bash
docker exec -it inventory_postgres psql -U postgres -d inventory_db -c "SELECT * FROM products WHERE sku = 'LAP-001';"
```

### Insert a product directly
```bash
docker exec -it inventory_postgres psql -U postgres -d inventory_db -c "INSERT INTO products (name, sku, quantity, price) VALUES ('Quick Product', 'QUICK-001', 10, 49.99);"
```

---

## 🔧 Database Backup & Restore

### Backup the entire database
```bash
docker exec -t inventory_postgres pg_dump -U postgres inventory_db > backup.sql
```

### Restore from backup
```bash
docker exec -i inventory_postgres psql -U postgres -d inventory_db < backup.sql
```

### Export products table to CSV
```bash
docker exec -it inventory_postgres psql -U postgres -d inventory_db -c "COPY products TO STDOUT WITH CSV HEADER" > products.csv
```

---

## 🗄️ Reinitialize Database

### Reset database to initial state
```bash
# Stop container and remove volumes
docker-compose down -v

# Start container (will run init.sql automatically)
docker-compose up -d

# Verify initialization
docker exec -it inventory_postgres psql -U postgres -d inventory_db -c "SELECT * FROM products;"
```

---

## 🔍 Troubleshooting Commands

### Check database connection
```bash
docker exec -it inventory_postgres psql -U postgres -d inventory_db -c "SELECT version();"
```

### Check if database exists
```bash
docker exec -it inventory_postgres psql -U postgres -c "\l"
```

### Check container health
```bash
docker inspect inventory_postgres | grep -A 10 Health
```

### View container resource usage
```bash
docker stats inventory_postgres
```

### Access container shell
```bash
docker exec -it inventory_postgres sh
```

---

## 📝 Useful SQL Queries for Testing

### Get total inventory value
```sql
SELECT SUM(quantity * price) AS total_value FROM products;
```

### Get average product price
```sql
SELECT AVG(price) AS average_price FROM products;
```

### Find low stock items (quantity < 10)
```sql
SELECT name, sku, quantity FROM products WHERE quantity < 10;
```

### Find products created today
```sql
SELECT * FROM products WHERE DATE(created_at) = CURRENT_DATE;
```

### Get product count by price range
```sql
SELECT 
  CASE 
    WHEN price < 50 THEN 'Low'
    WHEN price BETWEEN 50 AND 100 THEN 'Medium'
    ELSE 'High'
  END AS price_range,
  COUNT(*) AS count
FROM products
GROUP BY price_range;
```

---

## 🔑 Connection Information

- **Container Name**: `inventory_postgres`
- **Database Name**: `inventory_db`
- **Username**: `postgres`
- **Password**: `postgres`
- **Port**: `5432` (mapped to host)
- **Host**: `localhost` (from your machine)

**Connection String:**
```
postgresql://postgres:postgres@localhost:5432/inventory_db
```

---

## 📚 Quick Reference

| Command | Description |
|---------|-------------|
| `\dt` | List tables |
| `\d table_name` | Describe table |
| `\l` | List databases |
| `\du` | List users |
| `\q` | Quit PostgreSQL CLI |
| `\?` | Help with psql commands |
| `\h` | Help with SQL commands |

---

**Last Updated**: January 16, 2026
