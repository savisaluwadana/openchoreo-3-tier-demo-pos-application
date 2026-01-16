-- Database initialization script for Inventory Management System
-- Run this script to create the products table

CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    sku VARCHAR(100) UNIQUE NOT NULL,
    quantity INTEGER DEFAULT 0,
    price NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create an index on SKU for faster lookups
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);

-- Insert sample data (optional - remove if not needed)
INSERT INTO products (name, description, sku, quantity, price) 
VALUES 
    ('Laptop', 'High-performance laptop for business use', 'LAP-001', 15, 999.99),
    ('Wireless Mouse', 'Ergonomic wireless mouse with USB receiver', 'MOU-001', 50, 29.99),
    ('Keyboard', 'Mechanical keyboard with RGB lighting', 'KEY-001', 30, 79.99)
ON CONFLICT (sku) DO NOTHING;
