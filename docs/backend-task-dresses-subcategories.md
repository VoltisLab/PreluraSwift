# Backend task: Dresses subcategories ✅ Done

**Repository:** [VoltisLab/prelura-app](https://github.com/VoltisLab/prelura-app)

**Completed:** Dresses subcategories were added in the backend and the deploy workflow runs `add_categories` after migrations, so new categories are created on each deploy.

## Problem

In the app, when the user goes to **Sell an item → Select Category** and taps **Dresses**, no subcategories appear. The `categories(parentId: <Dresses id>)` query returns an empty list (or Dresses has `hasChildren: false`), so the user cannot pick a dress type.

## Required change

Ensure the **Dresses** category has children in the backend, and that the existing GraphQL query returns them.

### API contract (already used by the Swift app)

The app calls:

```graphql
query Categories($parentId: Int) {
  categories(parentId: $parentId) {
    id
    name
    hasChildren
    fullPath
  }
}
```

- `parentId: null` → root categories (e.g. Women, Men, …).
- `parentId: <Dresses category id>` → must return the list below.

Each child category should have:

- `id` (Int or String as in your schema)
- `name` (String)
- `hasChildren` (Boolean) — set to `false` for these dress types (leaf categories)
- `fullPath` (String, optional) — e.g. `"Women > Dresses > Mini Dress"` if your schema has it

### Subcategory names to add under Dresses

Add these as **child categories of Dresses** (exact names for consistency):

1. Mini Dress  
2. Midi Dress  
3. Maxi Dress  
4. Bodycon Dress  
5. Wrap Dress  
6. Shift Dress  
7. Shirt Dress  
8. Slip Dress  
9. Skater Dress  
10. Sundress  
11. Evening Dress  
12. Cocktail Dress  
13. Sweater Dress  
14. Denim Dress  

Order can follow the list above or your existing category ordering (e.g. by name).

## After the backend is updated

No Swift app changes are required. The app already:

- Calls `categories(parentId:)` for the selected parent (e.g. Dresses).
- Shows a list of children; leaves (`hasChildren: false`) are selectable as the final category.
- Uses the chosen category id/name when creating the product.

Once the backend returns these 14 categories for Dresses, they will appear in **Select Category** when the user taps **Dresses**, and the selection will be saved correctly on listing creation.
