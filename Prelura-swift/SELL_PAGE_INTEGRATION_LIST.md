# Sell Page Integration List (from Flutter)

Reference: Flutter `lib/views/pages/sell_item/sell_item_view.dart` and `lib/views/widgets/menu_card.dart`.

## Colour & theme integration

| Element | Flutter | Swift (Theme) |
|--------|---------|----------------|
| Primary accent (links, icons, buttons) | `PreluraColors.primaryColor` / `PreluraColors.activeColor` (purple) | `Theme.primaryColor` |
| Draft link & badge | Link: primary; badge circle: primary; count: white | Same |
| Photo add icon container | `PreluraColors.primaryColor.withOpacity(0.1)` | `Theme.primaryColor.opacity(0.1)` |
| Photo add icon | `PreluraColors.primaryColor` | `Theme.primaryColor` |
| Section headers | `AppTextStyles.h5`, w600, 16pt, theme text | `Theme.Typography.subheadline` / headline, `Theme.Colors.secondaryText` |
| Row title (label) | `AppTextStyles.bodyMedium` 15pt, w500, theme body color | `Theme.Typography.body`, `Theme.Colors.primaryText` when has value else `Theme.Colors.secondaryText` |
| Row value (subtitle) | bodyMedium, w300, `PreluraColors.greyColor` (subtitleColor) | `Theme.Typography.body`, `Theme.Colors.secondaryText` |
| Chevron | theme icon color / 18pt | `Theme.Colors.secondaryText`, ~13pt |
| Info banner bg | `PreluraColors.primaryColor.withOpacity(0.1)` | `Theme.primaryColor.opacity(0.1)` |
| Info banner icon & text | `PreluraColors.primaryColor` | `Theme.primaryColor` |
| Divider between rows | `buildDivider(context)` | `Theme.Colors.glassBorder`, 0.5pt |
| Cancel (app bar) | IconButton close, theme icon color | `BorderGlassButton("Cancel")` (outline, 30px) |
| Upload button | `AppButton`, radius 25, height 48, primary | `PrimaryGlassButton` |

## Per-item integration (form rows)

Every tappable row must use the same component (Flutter: `MenuCard`). One reusable row: title, optional value (subtitle), chevron, bottom divider, tap → destination.

| # | Item | Flutter | Swift |
|---|------|---------|--------|
| 1 | **Upload from drafts** | Row: "Upload from drafts" (primary), CircleAvatar count (primary bg, white text) | Same; `Theme.primaryColor`; divider below |
| 2 | **Photo upload** | Container, border grey 0.3, radius 16; icon circle primary 0.1; icon primary; "Add up to 20 photos" (body); "Tap to select..." (grey) | Same; use Theme colours and border |
| 3 | **Item Details** | Section header only (no Title/Describe in same block in list – Flutter has separate "Item Details" block with Title + Describe fields, then "Item Information" with rows) | Keep "Item Details" header; rows below |
| 4 | **Category** | MenuCard: title "Category", subtitle category?.name, subtitleColor grey, onTap → NewCategoryRoute | SellFormRow("Category", value: category?.name, destination: CategorySelectionView) |
| 5 | **Brand** | MenuCard: "Brand", subtitle customBrand ?? brand?.name, grey | SellFormRow("Brand", value: brand ?? customBrand, destination: BrandInputView) |
| 6 | **Condition** | MenuCard: "Condition", subtitle selectedCondition?.simpleName, grey | SellFormRow("Condition", value: condition, destination: ConditionSelectionView) |
| 7 | **Colours** | MenuCard: "Colours", subtitle selectedColors.join(', '), grey, onTap → ColorSelectorRoute | SellFormRow("Colours", value: colours.isEmpty ? nil : colours.joined(separator: ", "), destination: ColoursSelectionView) |
| 8 | **Additional Details** | Section header | Same |
| 9 | **Measurements (Optional)** | MenuCard: "Measurements (Optional)", no subtitle default, grey if any | SellFormRow("Measurements (Optional)", value: measurements, destination: MeasurementsView) |
| 10 | **Material (Optional)** | MenuCard: "Material (Optional)", subtitle materials names (first 2 + "..."), grey | SellFormRow("Material (Optional)", value: material, destination: MaterialSelectionView) |
| 11 | **Style (Optional)** | MenuCard: "Style (Optional)", subtitle styles joined, grey | SellFormRow("Style (Optional)", value: style, destination: StyleSelectionView) |
| 12 | **Pricing & Shipping** | Section header | Same |
| 13 | **Price** | MenuCard: "Price", subtitle "£ ..." or "", grey | SellFormRow("Price", value: price.map { "£\($0)" }, destination: PriceInputView) |
| 14 | **Discount Price (Optional)** | MenuCard: "Discount Price (Optional)", subtitle "0%" or percent, grey | SellFormRow("Discount Price (Optional)", value: discountPercent string, destination: DiscountPriceInputView) |
| 15 | **Parcel Size** | MenuCard: "Parcel Size", subtitle parcel?.name, grey | SellFormRow("Parcel Size", value: parcelSize, destination: ParcelSizeSelectionView) |
| 16 | **Info banner** | Container: bg primary 0.1, radius 12; Icon info outline primary; Text primary | Same; no white on solid primary |
| 17 | **Upload** | AppButton full width, 48h, radius 25, primary | PrimaryGlassButton("Upload") |

## Component: SellFormRow (Swift)

- **Title**: `Theme.Typography.body`, colour `Theme.Colors.primaryText` when value non-empty else `Theme.Colors.secondaryText`.
- **Value** (right): `Theme.Typography.body`, `Theme.Colors.secondaryText`, lineLimit 1.
- **Chevron**: `Image(systemName: "chevron.right")`, 13pt, `Theme.Colors.secondaryText`.
- **Padding**: horizontal `Theme.Spacing.md`, vertical `Theme.Spacing.md` (16).
- **Divider**: 0.5pt `Theme.Colors.glassBorder` below.
- **Background**: `Theme.Colors.background`.
- Wraps content in `NavigationLink(destination:...)` or `Button`; use `.buttonStyle(.plain)` so it looks like a row.

## Checklist

- [x] Cancel in toolbar uses `BorderGlassButton("Cancel")`.
- [x] Item Details = Title + Describe only; Item Information = Category, Brand, Condition, Colours (SellFormRow).
- [x] Section headers 16pt semibold, primaryText.
- [x] Draft link and badge use Theme.primaryColor.
- [ ] Photo empty state: icon container Theme.primaryColor.opacity(0.1), icon Theme.primaryColor, border Theme.Colors.glassBorder.
- [x] Info banner: background Theme.primaryColor.opacity(0.1), icon and text Theme.primaryColor.
- [x] Upload button: PrimaryGlassButton; canUpload matches Flutter.
- [ ] Colours row: same row component as others; no separate “colour” styling beyond Theme.
