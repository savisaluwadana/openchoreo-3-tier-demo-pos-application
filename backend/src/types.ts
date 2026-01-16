// TypeScript interfaces for type safety
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

export interface UpdateProductInput {
  name?: string;
  description?: string;
  sku?: string;
  quantity?: number;
  price?: number;
}
