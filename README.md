# Inventory Management System

A full-stack Inventory Management System built with **Next.js**, **Express.js**, and **PostgreSQL** using the `pg` driver for raw SQL queries.

## Tech Stack

- **Frontend**: Next.js 14 (App Router), TypeScript, Tailwind CSS
- **Backend**: Express.js, TypeScript
- **Database**: PostgreSQL
- **Driver**: `pg` (node-postgres) for raw SQL queries

## Project Structure

```
├── backend/               # Express API server
│   ├── src/
│   │   ├── server.ts     # Main server file with API routes
│   │   ├── db.ts         # PostgreSQL connection pool
│   │   └── types.ts      # TypeScript interfaces
│   ├── package.json
│   ├── tsconfig.json
│   └── .env.example
│
├── frontend/             # Next.js application
│   ├── src/
│   │   ├── app/          # App Router pages
│   │   ├── components/   # React components
│   │   └── types/        # TypeScript interfaces
│   ├── package.json
│   ├── tsconfig.json
│   └── .env.local.example
│
└── init.sql             # Database initialization script
```

## Prerequisites

- Node.js 18+ and npm/yarn
- PostgreSQL 13+

## Getting Started

### 1. Database Setup

First, create a PostgreSQL database:

```bash
# Login to PostgreSQL
psql -U postgres

# Create database
CREATE DATABASE inventory_db;

# Exit psql
\q
```

Set your database URL as an environment variable:

```bash
export DATABASE_URL="postgresql://username:password@localhost:5432/inventory_db"
```

Initialize the database schema:

```bash
psql $DATABASE_URL -f init.sql
```

Or from the backend directory:

```bash
cd backend
npm run db:init
```

### 2. Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Copy environment variables
cp .env.example .env

# Edit .env and set your DATABASE_URL
# DATABASE_URL=postgresql://username:password@localhost:5432/inventory_db

# Run development server
npm run dev
```

The backend API will start on `http://localhost:5000`

### 3. Frontend Setup

```bash
cd frontend

# Install dependencies
npm install

# Copy environment variables
cp .env.local.example .env.local

# Run development server
npm run dev
```

The frontend will start on `http://localhost:3000`

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/products` | Get all products |
| GET | `/api/products/:id` | Get a single product |
| POST | `/api/products` | Create a new product |
| PUT | `/api/products/:id` | Update a product |
| DELETE | `/api/products/:id` | Delete a product |

### Example API Request

**Create a product:**

```bash
curl -X POST http://localhost:5000/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Laptop",
    "description": "High-performance laptop",
    "sku": "LAP-001",
    "quantity": 10,
    "price": 999.99
  }'
```

## Features

✅ **CRUD Operations**: Full Create, Read, Update, Delete functionality  
✅ **Raw SQL**: Uses parameterized queries for security  
✅ **TypeScript**: Type-safe across the entire stack  
✅ **Responsive UI**: Built with Tailwind CSS  
✅ **Real-time Updates**: Frontend refreshes after data changes  
✅ **Input Validation**: Both frontend and backend validation  
✅ **Error Handling**: Comprehensive error messages  

## Security

- **SQL Injection Prevention**: All queries use parameterized statements (`$1`, `$2`, etc.)
- **CORS**: Configured to only accept requests from the frontend
- **Input Validation**: Required fields validated on both client and server

## Deployment Tips

### Environment Variables

For deployment, set the following environment variables:

**Backend:**
```
DATABASE_URL=postgresql://user:password@host:port/database
PORT=5000
FRONTEND_URL=https://your-frontend-url.com
```

**Frontend:**
```
NEXT_PUBLIC_API_URL=https://your-backend-url.com/api
```

### Database Migration

The `pg` library automatically reads the `DATABASE_URL` environment variable, making deployment simple. Just ensure your hosting platform (Vercel, Railway, Render, etc.) has this variable set.

## Development Scripts

### Backend
- `npm run dev` - Start development server with hot reload
- `npm run build` - Build for production
- `npm start` - Run production server
- `npm run db:init` - Initialize database schema

### Frontend
- `npm run dev` - Start Next.js development server
- `npm run build` - Build for production
- `npm start` - Run production server
- `npm run lint` - Run ESLint

## License

MIT

## Contributing

Feel free to submit issues or pull requests!