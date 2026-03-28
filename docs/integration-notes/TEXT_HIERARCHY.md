# Text Hierarchy Across Prelura Swift App

This document outlines the complete text hierarchy used throughout the Prelura Swift application, ordered from largest/most prominent to smallest/least prominent.

## Typography System (from Theme.swift)

### 1. **Large Title** (34pt, Bold)
- **Size**: 34pt
- **Weight**: Bold
- **Usage**: Not currently used in the app
- **Example**: Could be used for major page titles or hero sections

### 2. **Title** (28pt, Bold)
- **Size**: 28pt
- **Weight**: Bold
- **Usage**: 
  - Main app name/logo text ("Prelura" in header)
  - Major page titles
- **Color**: Primary purple (`Theme.primaryColor`)
- **Example**: `Text("Prelura").font(Theme.Typography.title)`

### 3. **Title 2** (22pt, Bold)
- **Size**: 22pt
- **Weight**: Bold
- **Usage**: 
  - Section headings
  - User statistics values
- **Color**: Primary text color
- **Example**: User stats numbers in ProfileView

### 4. **Title 3** (20pt, Semibold)
- **Size**: 20pt
- **Weight**: Semibold
- **Usage**: 
  - Navigation bar titles
  - Secondary page titles
- **Color**: Primary text color
- **Example**: Navigation titles in various views

### 5. **Headline** (17pt, Semibold)
- **Size**: 17pt
- **Weight**: Semibold
- **Usage**: 
  - Section headers (e.g., "Recently viewed", "Brands You Love", "On Sale")
  - Important labels
  - Button text in primary actions
  - Conversation recipient names in ChatListView
- **Color**: Primary text color
- **Example**: `Text("Recently viewed").font(Theme.Typography.headline)`

### 6. **Body** (17pt, Regular)
- **Size**: 17pt
- **Weight**: Regular
- **Usage**: 
  - Main content text
  - Search bar placeholder text
  - List items
  - General readable text
- **Color**: Primary text color
- **Example**: Search field text, body content

### 7. **Callout** (16pt, Regular)
- **Size**: 16pt
- **Weight**: Regular
- **Usage**: 
  - Not currently used in the app
  - Could be used for emphasized body text

### 8. **Subheadline** (15pt, Regular)
- **Size**: 15pt
- **Weight**: Regular
- **Usage**: 
  - Product titles in cards
  - Product brand names
  - Product prices
  - Button labels ("See All")
  - Filter button text
  - Last message preview in conversations
- **Color**: 
  - Primary text color (for titles, prices)
  - Primary purple (for brand names, "See All" buttons)
- **Example**: 
  - `Text(item.title).font(Theme.Typography.subheadline)`
  - `Text(brand).font(Theme.Typography.subheadline).foregroundColor(Theme.primaryColor)`

### 9. **Footnote** (13pt, Regular)
- **Size**: 13pt
- **Weight**: Regular
- **Usage**: 
  - Not currently used in the app
  - Could be used for secondary information

### 10. **Caption** (12pt, Regular)
- **Size**: 12pt
- **Weight**: Regular
- **Usage**: 
  - Product condition text
  - Seller usernames
  - Section subtitles (e.g., "Discounted items", "Steals under £15")
  - Timestamps
  - Category labels
  - Small metadata
  - Like counts
- **Color**: 
  - Secondary text color (for conditions, subtitles)
  - Primary text color (for usernames)
- **Example**: 
  - `Text(item.formattedCondition).font(Theme.Typography.caption)`
  - `Text("Discounted items").font(Theme.Typography.caption)`

## Custom Font Sizes (Not in Theme)

### Icon Fonts
- **18pt, Semibold**: Notification bell icon
- **20pt, Regular**: Heart icon in header
- **16pt, Medium**: Search icon
- **14pt, Semibold**: Heart icon in product cards
- **24pt, Regular**: Category icons (fallback)
- **32pt, Bold**: Initial letters in avatars (Top Shops)
- **9pt, Bold**: Initial letters in small avatars (seller info)

### Special Cases
- **System sizes**: Various icon sizes used throughout (ranging from 9pt to 60pt for empty states)

## Usage Patterns by Component

### Product Cards
- **Brand**: Subheadline (15pt, Regular) - Purple
- **Title**: Subheadline (15pt, Regular) - Primary text
- **Condition**: Caption (12pt, Regular) - Secondary text
- **Price**: Subheadline (15pt, Regular) - Primary text
- **Seller Username**: Caption (12pt, Regular) - Secondary text
- **Like Count**: Caption (12pt, Regular) - White (on overlay)

### Section Headers
- **Title**: Headline (17pt, Semibold) - Primary text
- **Subtitle**: Caption (12pt, Regular) - Secondary text
- **Action Button**: Subheadline (15pt, Regular) - Purple

### Navigation
- **App Name**: Title (28pt, Bold) - Purple
- **Page Title**: Title 3 (20pt, Semibold) - Primary text
- **Navigation Bar Title**: Large (system default)

### Buttons
- **Primary Button Text**: Headline (17pt, Semibold) - White
- **Secondary Button Text**: Subheadline (15pt, Regular) - Purple
- **Filter Button Text**: Subheadline (15pt, Regular) - Purple/White

### Lists
- **List Item Title**: Headline (17pt, Semibold) - Primary text
- **List Item Subtitle**: Subheadline (15pt, Regular) - Secondary text
- **List Item Metadata**: Caption (12pt, Regular) - Secondary/Tertiary text

## Color Hierarchy

1. **Primary Purple** (`Theme.primaryColor`): Brand name, brand labels, action buttons, selected states
2. **Primary Text** (`Theme.Colors.primaryText`): Main content, titles, usernames
3. **Secondary Text** (`Theme.Colors.secondaryText`): Conditions, subtitles, metadata
4. **Tertiary Text** (`Theme.Colors.tertiaryText`): Least important information
5. **White**: Text on dark overlays, button text on colored backgrounds

## Summary

The app follows a clear typographic hierarchy:
- **Largest**: Title (28pt) for app branding
- **Large**: Title 2 (22pt) for major values
- **Medium**: Headline (17pt) for section headers and important labels
- **Body**: Body/Subheadline (15-17pt) for main content
- **Small**: Caption (12pt) for metadata and secondary information

This creates a clear visual hierarchy that guides users through the interface, with the most important information (brand, product titles, prices) being most prominent, and supporting information (conditions, timestamps) being more subtle.
