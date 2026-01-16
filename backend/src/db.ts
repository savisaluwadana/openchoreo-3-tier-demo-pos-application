import { Pool } from 'pg';

// Create a connection pool
// The Pool will automatically read from DATABASE_URL environment variable
// or you can provide explicit connection details
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  // Optional: Configure pool settings
  max: 20, // Maximum number of clients in the pool
  idleTimeoutMillis: 30000, // How long a client can be idle before being closed
  connectionTimeoutMillis: 2000, // How long to wait for a connection
});

// Test the connection
pool.on('connect', () => {
  console.log('✅ Database connected successfully');
});

pool.on('error', (err) => {
  console.error('❌ Unexpected database error:', err);
  process.exit(-1);
});

export default pool;
