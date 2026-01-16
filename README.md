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
- Docker and Docker Compose

## Getting Started

### 1. Database Setup (Docker)

Start PostgreSQL in a Docker container:

```bash
# Start PostgreSQL container
docker-compose up -d

# Check if the container is running
docker ps

# View logs
docker-compose logs postgres
```

The database will automatically initialize with the schema from `init.sql`. The default connection details are:
- **Host**: localhost
- **Port**: 5432
- **Database**: inventory_db
- **User**: postgres
- **Password**: postgres

**Note**: The `.env` file is already created with the correct `DATABASE_URL`

### 2. Backend Setup

```bash
cd backend

# Install dependencies
npm install

# The .env file is already created with the correct DATABASE_URL
# If you need to modify it: DATABASE_URL=postgresql://postgres:postgres@localhost:5432/inventory_db

# Run development server
npm run dev
```

The backend API will start on `http://localhost:5000`

### 3. Frontend Setup

```bash
cd frontend

# Install dependencies
npm install

# The .env.local file is already created
# Run development server
npm run dev
```

The frontend will start on `http://localhost:3000`

## Docker Commands

### Managing the Database Container

```bash
# Start the database
docker-compose up -d

# Stop the database
docker-compose down

# Stop and remove all data (careful!)
docker-compose down -v

# View database logs
docker-compose logs -f postgres

# Access PostgreSQL CLI
docker exec -it inventory_postgres psql -U postgres -d inventory_db

# Restart the database
docker-compose restart
```

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
## Development Scripts

### Backend
- `npm run dev` - Start development server with hot reload
- `npm run build` - Build for production
- `npm start` - Run production server

### Frontend
- `npm run dev` - Start Next.js development server
- `npm run build` - Build for production
- `npm start` - Run production server
- `npm run lint` - Run ESLint

### Database (Docker)
- `docker-compose up -d` - Start PostgreSQL container
- `docker-compose down` - Stop PostgreSQL container
- `docker-compose logs postgres` - View database logs
- `docker exec -it inventory_postgres psql -U postgres -d inventory_db` - Access database CLIour-backend-url.com/api
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