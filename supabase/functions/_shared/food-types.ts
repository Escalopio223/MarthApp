/**
-- ==============================================================================
-- DEFINICIONES TYPESCRIPT: MÓDULO DE ALIMENTACIÓN (MARTHAPP)
-- Entidades, Enums, DTOs y Esquema de Base de Datos para Supabase / PostgreSQL
-- ==============================================================================
*/

/**
 * Slugs taxonómicos oficiales para las categorías de alimentos
 */
export type FoodCategorySlug =
  | 'dairy'
  | 'fruit'
  | 'vegetable'
  | 'meat'
  | 'fish'
  | 'grain'
  | 'bakery'
  | 'snack'
  | 'cleaning';

/**
 * Tipos de comida para slots de menús y calendario
 */
export type MealType =
  | 'breakfast'
  | 'mid_morning'
  | 'lunch'
  | 'snack'
  | 'dinner';

/**
 * Tipo de elemento asignado en una ranura de menú o calendario
 */
export type SlotItemType = 'recipe' | 'single_ingredient';

/**
 * Tipo de elemento en la lista de favoritos de cocina
 */
export type FavoriteItemType = 'recipe' | 'ingredient';

// ==============================================================================
// 1. MODELOS DE FILA DE BASE DE DATOS (DATABASE ROWS)
// ==============================================================================

export interface FoodCategoryRow {
  id: string;
  name: string;
  icon_slug: FoodCategorySlug;
  created_at: string;
}

export interface RecipeRow {
  id: string;
  title: string;
  country: string;
  cuisine_type: string;
  prep_oven: string | null;
  prep_airfryer: string | null;
  prep_microwave: string | null;
  is_global: boolean;
  environment_id: string | null;
  created_at: string;
}

export interface RecipeIngredientRow {
  id: string;
  recipe_id: string;
  name: string;
  category_id: string;
  created_at: string;
}

export interface FoodFavoriteRow {
  id: string;
  environment_id: string;
  item_type: FavoriteItemType;
  recipe_id: string | null;
  ingredient_name: string | null;
  created_at: string;
}

export interface SavedWeeklyMenuRow {
  id: string;
  environment_id: string;
  name: string;
  description: string | null;
  created_at: string;
}

export interface SavedWeeklyMenuSlotRow {
  id: string;
  saved_menu_id: string;
  day_of_week: number; // 1 = Lunes, 7 = Domingo
  meal_type: MealType;
  item_type: SlotItemType;
  recipe_id: string | null;
  custom_name: string | null;
}

export interface ActiveCalendarSlotRow {
  id: string;
  environment_id: string;
  date: string; // YYYY-MM-DD
  meal_type: MealType;
  item_type: SlotItemType;
  recipe_id: string | null;
  custom_name: string | null;
}

export interface ShoppingListItemRow {
  id: string;
  environment_id: string;
  name: string;
  occurrences_count: number;
  category_id: string | null;
  is_checked: boolean;
  is_manual: boolean;
  created_at: string;
  updated_at: string;
}

// ==============================================================================
// 2. TIPOS PARA INSERCIÓN (INSERTS) Y ACTUALIZACIÓN (UPDATES)
// ==============================================================================

export type FoodCategoryInsert = Omit<FoodCategoryRow, 'created_at'> & {
  id?: string;
  created_at?: string;
};
export type FoodCategoryUpdate = Partial<Omit<FoodCategoryRow, 'id' | 'created_at'>>;

export type RecipeInsert = Omit<RecipeRow, 'id' | 'created_at'> & {
  id?: string;
  country?: string;
  cuisine_type?: string;
  is_global?: boolean;
  environment_id?: string | null;
  created_at?: string;
};
export type RecipeUpdate = Partial<Omit<RecipeRow, 'id' | 'created_at'>>;

export type RecipeIngredientInsert = Omit<RecipeIngredientRow, 'id' | 'created_at'> & {
  id?: string;
  created_at?: string;
};
export type RecipeIngredientUpdate = Partial<Omit<RecipeIngredientRow, 'id' | 'created_at'>>;

export type FoodFavoriteInsert = Omit<FoodFavoriteRow, 'id' | 'created_at'> & {
  id?: string;
  created_at?: string;
};
export type FoodFavoriteUpdate = Partial<Omit<FoodFavoriteRow, 'id' | 'created_at'>>;

export type SavedWeeklyMenuInsert = Omit<SavedWeeklyMenuRow, 'id' | 'created_at'> & {
  id?: string;
  created_at?: string;
};
export type SavedWeeklyMenuUpdate = Partial<Omit<SavedWeeklyMenuRow, 'id' | 'created_at'>>;

export type SavedWeeklyMenuSlotInsert = Omit<SavedWeeklyMenuSlotRow, 'id'> & {
  id?: string;
};
export type SavedWeeklyMenuSlotUpdate = Partial<Omit<SavedWeeklyMenuSlotRow, 'id' | 'saved_menu_id'>>;

export type ActiveCalendarSlotInsert = Omit<ActiveCalendarSlotRow, 'id'> & {
  id?: string;
};
export type ActiveCalendarSlotUpdate = Partial<Omit<ActiveCalendarSlotRow, 'id' | 'environment_id'>>;

export type ShoppingListItemInsert = Omit<ShoppingListItemRow, 'id' | 'created_at' | 'updated_at'> & {
  id?: string;
  occurrences_count?: number;
  is_checked?: boolean;
  is_manual?: boolean;
  created_at?: string;
  updated_at?: string;
};
export type ShoppingListItemUpdate = Partial<Omit<ShoppingListItemRow, 'id' | 'environment_id' | 'created_at'>>;

// ==============================================================================
// 3. MODELOS ENRIQUECIDOS DE DOMINIO Y DTOS (DOMAIN & DATA TRANSFER OBJECTS)
// ==============================================================================

export interface RecipeIngredientWithCategory extends RecipeIngredientRow {
  category?: FoodCategoryRow | null;
}

export interface RecipeWithIngredients extends RecipeRow {
  ingredients: RecipeIngredientWithCategory[];
}

export interface SavedWeeklyMenuSlotDetailed extends SavedWeeklyMenuSlotRow {
  recipe?: RecipeWithIngredients | null;
}

export interface SavedWeeklyMenuWithSlots extends SavedWeeklyMenuRow {
  slots: SavedWeeklyMenuSlotDetailed[];
}

export interface ActiveCalendarSlotDetailed extends ActiveCalendarSlotRow {
  recipe?: RecipeWithIngredients | null;
}

export interface ShoppingListItemWithCategory extends ShoppingListItemRow {
  category?: FoodCategoryRow | null;
}

export interface FoodFavoriteDetailed extends FoodFavoriteRow {
  recipe?: RecipeWithIngredients | null;
}

// ==============================================================================
// 4. TIPADO PARA CLIENTE SUPABASE (DATABASE DEFINITION INTERFACE)
// ==============================================================================

export interface FoodDatabaseSchema {
  public: {
    Tables: {
      food_categories: {
        Row: FoodCategoryRow;
        Insert: FoodCategoryInsert;
        Update: FoodCategoryUpdate;
      };
      recipes: {
        Row: RecipeRow;
        Insert: RecipeInsert;
        Update: RecipeUpdate;
      };
      recipe_ingredients: {
        Row: RecipeIngredientRow;
        Insert: RecipeIngredientInsert;
        Update: RecipeIngredientUpdate;
      };
      food_favorites: {
        Row: FoodFavoriteRow;
        Insert: FoodFavoriteInsert;
        Update: FoodFavoriteUpdate;
      };
      saved_weekly_menus: {
        Row: SavedWeeklyMenuRow;
        Insert: SavedWeeklyMenuInsert;
        Update: SavedWeeklyMenuUpdate;
      };
      saved_weekly_menu_slots: {
        Row: SavedWeeklyMenuSlotRow;
        Insert: SavedWeeklyMenuSlotInsert;
        Update: SavedWeeklyMenuSlotUpdate;
      };
      active_calendar_slots: {
        Row: ActiveCalendarSlotRow;
        Insert: ActiveCalendarSlotInsert;
        Update: ActiveCalendarSlotUpdate;
      };
      shopping_list_items: {
        Row: ShoppingListItemRow;
        Insert: ShoppingListItemInsert;
        Update: ShoppingListItemUpdate;
      };
    };
    Views: Record<string, never>;
    Functions: {
      is_environment_member: {
        Args: { target_env_id: string };
        Returns: boolean;
      };
    };
    Enums: {
      food_category_slug: FoodCategorySlug;
      meal_type: MealType;
      slot_item_type: SlotItemType;
      favorite_item_type: FavoriteItemType;
    };
  };
}
