// TypeScript interfaces matching the database schema
export interface Product {
  id: number;
  name: string;
  description: string | null;
  sku: string;
  quantity: number;
  price: number;
  created_at: Date;
}

export interface CreateProductInput {
  name: string;
  description?: string;
  sku: string;
  quantity?: number;
  price: number;
}
