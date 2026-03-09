# UI Component Analysis - Prelura Swift App

## Components with High Reusability Potential

### 1. **Product Cards** ⭐⭐⭐ (CRITICAL - Currently Duplicated 3x)
- **Current State**: `HomeItemCard`, `WardrobeItemCard`, `DiscoverItemCard` - all nearly identical
- **Location**: HomeView.swift, ProfileView.swift, DiscoverView.swift
- **Component Name**: `ProductCard` or `ItemCard`
- **Props Needed**: 
  - `item: Item`
  - `showSellerInfo: Bool` (optional, for feed)
  - `aspectRatio: CGFloat` (default: 1.3)
- **Features**:
  - Product image with 1:1.3 aspect ratio
  - Like count overlay (heart icon + count)
  - Brand, title, condition, price display
  - Discount badge
  - Fixed sizing to prevent layout shifts

---

### 2. **Search Bar** ⭐⭐⭐ (Used in 4+ places)
- **Current State**: Duplicated in HomeView, DiscoverView, BrowseView
- **Component Name**: `SearchBar` or `SearchField`
- **Props Needed**:
  - `placeholder: String`
  - `text: Binding<String>`
  - `onSubmit: (() -> Void)?` (optional)
- **Features**:
  - Magnifying glass icon
  - Rounded corners (24px)
  - Consistent styling
  - Background color

---

### 3. **Category Filter Button** ⭐⭐⭐ (Used in 3+ places)
- **Current State**: `CategoryFilterButton` in BrowseView.swift (but used elsewhere)
- **Component Name**: `CategoryFilterButton` (already exists but should be shared)
- **Props Needed**:
  - `title: String`
  - `isSelected: Bool`
  - `action: () -> Void`
- **Features**:
  - Glass effect for unselected
  - Solid purple for selected
  - Gradient border
  - Shadow effects

---

### 4. **Brand Filter Pill** ⭐⭐ (Used in DiscoverView)
- **Current State**: `BrandFilterPill` in DiscoverView.swift
- **Component Name**: `BrandFilterPill`
- **Props Needed**:
  - `brand: String`
  - `isSelected: Bool`
  - `action: () -> Void`
- **Features**:
  - Similar to CategoryFilterButton but for brands
  - Could potentially merge with CategoryFilterButton

---

### 5. **Brand Button** ⭐⭐ (Used in ProfileView)
- **Current State**: `BrandButton` in ProfileView.swift
- **Component Name**: `BrandButton`
- **Props Needed**:
  - `brand: String`
  - `isSelected: Bool`
  - `action: () -> Void`
- **Features**:
  - Chat bubble icon
  - Glass effect / solid purple states
  - Similar to BrandFilterPill - could be unified

---

### 6. **Price Display** ⭐⭐⭐ (Used in 5+ places)
- **Current State**: Duplicated in all product cards
- **Component Name**: `PriceView` or `PriceDisplay`
- **Props Needed**:
  - `price: Double`
  - `originalPrice: Double?` (optional)
  - `discountPercentage: Int?` (optional)
  - `showPercentage: Bool` (default: true)
- **Features**:
  - Original price with strikethrough
  - Current price
  - Discount percentage badge
  - Consistent formatting

---

### 7. **Like/Heart Button** ⭐⭐⭐ (Used in all product cards)
- **Current State**: Duplicated in HomeItemCard, WardrobeItemCard, DiscoverItemCard
- **Component Name**: `LikeButton` or `HeartButton`
- **Props Needed**:
  - `likeCount: Int`
  - `isLiked: Bool` (optional, for future)
  - `action: () -> Void`
- **Features**:
  - Heart icon
  - Like count
  - Black semi-transparent background
  - Tappable area

---

### 8. **Product Image Container** ⭐⭐⭐ (Used in all product cards)
- **Current State**: Duplicated image loading logic everywhere
- **Component Name**: `ProductImageView`
- **Props Needed**:
  - `imageURLs: [String]`
  - `aspectRatio: CGFloat` (default: 1.3)
  - `cornerRadius: CGFloat` (default: 8)
- **Features**:
  - AsyncImage loading
  - Placeholder states
  - Fixed sizing
  - Error handling
  - Background gradient

---

### 9. **Section Header** ⭐⭐⭐ (Used in 5+ places)
- **Current State**: Duplicated pattern across DiscoverView sections
- **Component Name**: `SectionHeader`
- **Props Needed**:
  - `title: String`
  - `subtitle: String?` (optional)
  - `showSeeAll: Bool` (default: false)
  - `seeAllAction: (() -> Void)?` (optional)
- **Features**:
  - Title and optional subtitle
  - "See All" button on right
  - Consistent spacing

---

### 10. **Profile Avatar** ⭐⭐⭐ (Used in 4+ places)
- **Current State**: Duplicated in ProfileView, ChatListView, ItemDetailView
- **Component Name**: `ProfileAvatar` or `AvatarView`
- **Props Needed**:
  - `imageURL: String?`
  - `username: String` (for fallback initial)
  - `size: CGFloat` (default: 50)
  - `isEditable: Bool` (default: false, for profile)
- **Features**:
  - AsyncImage loading
  - Fallback to initial letter
  - Circular shape
  - Optional PhotosPicker integration

---

### 11. **Stat Column** ⭐⭐ (Used in ProfileView)
- **Current State**: `StatColumn` in ProfileView.swift
- **Component Name**: `StatColumn` (already exists, should be shared)
- **Props Needed**:
  - `value: String`
  - `label: String`
- **Features**:
  - Large value text
  - Small label text
  - Consistent styling

---

### 12. **Notification Bell Button** ⭐⭐ (Used in 3+ places)
- **Current State**: Duplicated in HomeView, DiscoverView
- **Component Name**: `NotificationBellButton`
- **Props Needed**:
  - `hasNotifications: Bool` (optional, for badge)
  - `action: () -> Void`
- **Features**:
  - Glass effect
  - Fixed 44x44 size
  - Purple icon color
  - Optional badge

---

### 13. **Empty State View** ⭐⭐ (Used in 3+ places)
- **Current State**: Duplicated in ChatListView, BrowseView
- **Component Name**: `EmptyStateView`
- **Props Needed**:
  - `icon: String`
  - `title: String`
  - `message: String?` (optional)
- **Features**:
  - Large icon
  - Title text
  - Optional message
  - Centered layout

---

### 14. **Info Badge** ⭐⭐ (Used in ItemDetailView)
- **Current State**: `InfoBadge` in ItemDetailView.swift
- **Component Name**: `InfoBadge` (already exists, should be shared)
- **Props Needed**:
  - `icon: String`
  - `text: String`
- **Features**:
  - Icon + text
  - Purple background
  - Capsule shape

---

### 15. **Navigation Row** ⭐⭐ (Used in SellView, ProfileView)
- **Current State**: Duplicated pattern in SellView for form fields
- **Component Name**: `NavigationRow` or `FormRow`
- **Props Needed**:
  - `title: String`
  - `value: String?` (optional)
  - `placeholder: String?` (optional)
  - `destination: AnyView?` (optional, for NavigationLink)
  - `action: (() -> Void)?` (optional)
- **Features**:
  - Title on left
  - Value or placeholder on right
  - Chevron icon
  - Divider at bottom
  - Optional NavigationLink

---

### 16. **Section Divider** ⭐⭐ (Used in 5+ places)
- **Current State**: Duplicated Rectangle overlay pattern
- **Component Name**: `SectionDivider`
- **Props Needed**:
  - `color: Color?` (default: Theme.Colors.glassBorder)
  - `height: CGFloat` (default: 0.5)
- **Features**:
  - Thin divider line
  - Consistent styling

---

### 17. **Category Circle** ⭐⭐ (Used in DiscoverView)
- **Current State**: `CategoryCircle` in DiscoverView.swift
- **Component Name**: `CategoryCircle`
- **Props Needed**:
  - `category: String`
  - `imageURL: String?`
  - `size: CGFloat` (default: 70)
- **Features**:
  - Circular image
  - Category label
  - Gradient border
  - Fallback icon

---

### 18. **Shop Card** ⭐ (Used in DiscoverView)
- **Current State**: Top Shops section in DiscoverView
- **Component Name**: `ShopCard`
- **Props Needed**:
  - `shopName: String`
  - `imageURL: String?` (optional)
- **Features**:
  - Square thumbnail
  - Shop name label
  - Placeholder with initial

---

### 19. **Discount Badge** ⭐⭐ (Used in all product cards)
- **Current State**: Duplicated in price displays
- **Component Name**: `DiscountBadge`
- **Props Needed**:
  - `percentage: Int`
  - `style: BadgeStyle` (default: .red)
- **Features**:
  - Percentage text
  - Red capsule background
  - Consistent sizing

---

### 20. **Loading Indicator** ⭐ (Used in 3+ places)
- **Current State**: Basic ProgressView usage
- **Component Name**: `LoadingView` or `LoadingIndicator`
- **Props Needed**:
  - `message: String?` (optional)
- **Features**:
  - Centered ProgressView
  - Optional message
  - Full screen or inline

---

### 21. **Custom Header** ⭐⭐ (Used in 3+ places)
- **Current State**: Duplicated in HomeView, DiscoverView, BrowseView, ProfileView
- **Component Name**: `PageHeader`
- **Props Needed**:
  - `title: String`
  - `leadingButton: ButtonConfig?` (optional)
  - `trailingButtons: [ButtonConfig]` (optional)
- **Features**:
  - Centered title
  - Optional leading/trailing buttons
  - Consistent spacing
  - Divider at bottom

---

### 22. **Rating Stars** ⭐⭐ (Used in ProfileView, ItemDetailView)
- **Current State**: Duplicated HStack with stars
- **Component Name**: `RatingView` or `StarRating`
- **Props Needed**:
  - `rating: Double` (0-5)
  - `showCount: Bool` (default: false)
  - `reviewCount: Int?` (optional)
- **Features**:
  - 5 yellow stars
  - Optional review count
  - Consistent sizing

---

### 23. **Horizontal Product Slider** ⭐⭐⭐ (Used in DiscoverView 4x)
- **Current State**: Duplicated ScrollView + LazyHStack pattern
- **Component Name**: `ProductSlider` or `HorizontalProductList`
- **Props Needed**:
  - `items: [Item]`
  - `itemWidth: CGFloat` (default: 160)
  - `spacing: CGFloat` (default: Theme.Spacing.sm)
- **Features**:
  - Horizontal scrolling
  - Fixed item width
  - Product cards
  - NavigationLink integration

---

### 24. **Form Section Header** ⭐ (Used in SellView)
- **Current State**: Duplicated in SellView sections
- **Component Name**: `FormSectionHeader`
- **Props Needed**:
  - `title: String`
- **Features**:
  - Section title
  - Consistent padding
  - Background color

---

### 25. **Toggle Row** ⭐ (Used in ProfileView)
- **Current State**: Multi-buy toggle in ProfileView
- **Component Name**: `ToggleRow`
- **Props Needed**:
  - `title: String`
  - `isOn: Binding<Bool>`
- **Features**:
  - Title on left
  - Toggle on right
  - Divider at bottom
  - Consistent padding

---

### 26. **Expandable Section** ⭐⭐ (Used in ProfileView)
- **Current State**: Categories section in ProfileView
- **Component Name**: `ExpandableSection`
- **Props Needed**:
  - `title: String`
  - `isExpanded: Binding<Bool>`
  - `content: AnyView`
- **Features**:
  - Title with chevron
  - Animated expansion
  - Content view
  - Divider

---

### 27. **Checkbox Row** ⭐ (Used in ProfileView categories)
- **Current State**: Category items in ProfileView
- **Component Name**: `CheckboxRow`
- **Props Needed**:
  - `title: String`
  - `subtitle: String?` (optional, for count)
  - `isChecked: Bool`
  - `action: () -> Void`
- **Features**:
  - Minus icon
  - Title and subtitle
  - Checkbox on right
  - Divider

---

### 28. **Message Row** ⭐ (Used in ChatListView)
- **Current State**: `ChatRowView` in ChatListView.swift
- **Component Name**: `MessageRow` or `ConversationRow`
- **Props Needed**:
  - `conversation: Conversation`
  - `onTap: (() -> Void)?` (optional)
- **Features**:
  - Avatar
  - Username
  - Last message preview
  - Timestamp
  - Unread badge

---

### 29. **Image Gallery** ⭐ (Used in ItemDetailView)
- **Current State**: Image gallery in ItemDetailView
- **Component Name**: `ImageGalleryView`
- **Props Needed**:
  - `imageURLs: [String]`
  - `selectedIndex: Binding<Int>`
- **Features**:
  - Main image display
  - Thumbnail indicators
  - Swipe navigation

---

### 30. **Seller Info Card** ⭐ (Used in ItemDetailView)
- **Current State**: Seller info in ItemDetailView
- **Component Name**: `SellerInfoCard`
- **Props Needed**:
  - `seller: User`
- **Features**:
  - Avatar
  - Display name
  - Rating stars
  - Review count
  - Glass effect background

---

## Priority Ranking

### 🔴 **HIGH PRIORITY** (Duplicated 3+ times, critical for consistency)
1. **ProductCard** - Unify HomeItemCard, WardrobeItemCard, DiscoverItemCard
2. **SearchBar** - Used in Home, Discover, Browse
3. **PriceDisplay** - Used in all product cards
4. **ProductImageView** - Image loading logic duplicated everywhere
5. **LikeButton** - Duplicated in all product cards
6. **SectionHeader** - Used in 4+ DiscoverView sections
7. **ProfileAvatar** - Used in Profile, Chat, ItemDetail
8. **PageHeader** - Used in Home, Discover, Browse, Profile

### 🟡 **MEDIUM PRIORITY** (Used 2-3 times, good for consistency)
9. **CategoryFilterButton** - Already exists, should be shared
10. **BrandButton/BrandFilterPill** - Could be unified
11. **ProductSlider** - Used 4x in DiscoverView
12. **RatingView** - Used in Profile and ItemDetail
13. **EmptyStateView** - Used in Chat and Browse
14. **NotificationBellButton** - Used in Home and Discover
15. **ExpandableSection** - Used in Profile categories

### 🟢 **LOW PRIORITY** (Used 1-2 times, nice to have)
16. **InfoBadge** - Already exists, could be shared
17. **StatColumn** - Already exists, could be shared
18. **CategoryCircle** - Used in DiscoverView
19. **NavigationRow** - Used in SellView
20. **DiscountBadge** - Extract from price display
21. **ToggleRow** - Used in ProfileView
22. **CheckboxRow** - Used in ProfileView
23. **MessageRow** - Used in ChatListView
24. **ImageGalleryView** - Used in ItemDetailView
25. **SellerInfoCard** - Used in ItemDetailView
26. **ShopCard** - Used in DiscoverView
27. **FormSectionHeader** - Used in SellView
28. **SectionDivider** - Utility component
29. **LoadingIndicator** - Utility component

---

## Recommended Component Structure

```
Prelura-swift/Views/Components/
├── Cards/
│   ├── ProductCard.swift          ⭐⭐⭐ (HIGH PRIORITY)
│   ├── SellerInfoCard.swift
│   └── ShopCard.swift
├── Buttons/
│   ├── CategoryFilterButton.swift ⭐⭐ (Already exists, move here)
│   ├── BrandButton.swift          ⭐⭐
│   ├── LikeButton.swift            ⭐⭐⭐
│   ├── NotificationBellButton.swift ⭐⭐
│   └── DiscountBadge.swift         ⭐⭐
├── Forms/
│   ├── SearchBar.swift            ⭐⭐⭐
│   ├── NavigationRow.swift         ⭐⭐
│   ├── ToggleRow.swift             ⭐
│   └── CheckboxRow.swift           ⭐
├── Headers/
│   ├── PageHeader.swift           ⭐⭐⭐
│   ├── SectionHeader.swift        ⭐⭐⭐
│   └── FormSectionHeader.swift     ⭐
├── Media/
│   ├── ProductImageView.swift     ⭐⭐⭐
│   ├── ProfileAvatar.swift        ⭐⭐⭐
│   ├── ImageGalleryView.swift     ⭐
│   └── CategoryCircle.swift       ⭐⭐
├── Display/
│   ├── PriceDisplay.swift         ⭐⭐⭐
│   ├── RatingView.swift           ⭐⭐
│   ├── StatColumn.swift           ⭐⭐ (Already exists)
│   └── InfoBadge.swift            ⭐⭐ (Already exists)
├── Lists/
│   ├── ProductSlider.swift        ⭐⭐⭐
│   ├── MessageRow.swift           ⭐
│   └── ExpandableSection.swift    ⭐⭐
├── Utilities/
│   ├── EmptyStateView.swift       ⭐⭐
│   ├── LoadingIndicator.swift     ⭐
│   └── SectionDivider.swift       ⭐⭐
└── Existing/
    ├── GlassButton.swift          (Already exists)
    ├── GlassCard.swift             (Already exists)
    └── ItemCard.swift              (Already exists, but different from ProductCard)
```

---

## Implementation Notes

1. **ProductCard** should replace HomeItemCard, WardrobeItemCard, and DiscoverItemCard
2. **SearchBar** should be extracted to a shared component
3. **PriceDisplay** should handle all price formatting logic
4. **ProductImageView** should handle all AsyncImage loading states
5. **CategoryFilterButton** already exists in BrowseView - should be moved to Components
6. **BrandButton** and **BrandFilterPill** are very similar - consider merging
7. **SectionHeader** pattern is repeated 4+ times in DiscoverView
8. **ProfileAvatar** logic is duplicated in multiple views

---

## Benefits of Componentization

1. **Consistency**: Single source of truth for UI elements
2. **Maintainability**: Update once, applies everywhere
3. **Reusability**: Easy to use in new features
4. **Testing**: Easier to test individual components
5. **Performance**: Potential for better optimization
6. **Code Reduction**: Eliminate duplicate code
