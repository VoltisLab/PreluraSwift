# Prelura AI Dataset

This document is the single reference for all AI training data used by `AISearchService`. **Keep it in sync with the model**: when you add or change vocabulary or response sets in `Prelura-swift/Services/AISearchService.swift`, update this file as well.

---

## 1. App colours

Canonical colour names used for search and display.

| Colours |
|--------|
| Black, White, Red, Blue, Green, Yellow, Pink, Purple, Orange, Brown, Grey, Beige, Navy, Maroon, Teal |

---

## 2. Parent categories

Feed / filter categories.

| Categories |
|------------|
| All, Women, Men, Kids, Toddlers, Boys, Girls |

---

## 3. Subcategories

Broad categories for keyword matching.

| Subcategories |
|---------------|
| Clothing, Clothes, Shoes, Footwear, Accessories, Electronics, Home, Beauty, Books, Sports |

---

## 4. Colour phrases (multi-word → app colour)

Matched before single-word colours.

| Phrase | App colour |
|--------|------------|
| sky blue | Blue |
| light blue | Blue |
| dark blue | Navy |
| navy blue | Navy |
| royal blue | Blue |
| dark green | Green |
| light green | Green |
| burgundy red | Maroon |
| off white | White |

---

## 5. Colour aliases

User terms and common names mapped to app colours.

| Alias | App colour |
|-------|------------|
| camo, camouflage, olive, forest, mint, sage, lime, emerald, dark green, light green, army | Green |
| wine, burgundy, burgundy red, claret, bordeaux | Maroon |
| crimson, scarlet, dark red, cherry | Red |
| navy, navy blue, midnight, royal blue, sky blue, light blue, dark blue, cobalt | Navy / Blue |
| tan, sand, cream, ivory, off white | Beige / White |
| charcoal, silver, gray, slate | Grey |
| taupe, khaki, mocha, chocolate | Brown / Beige |
| magenta, rose, blush | Pink |
| lavender, violet, plum, mauve | Purple |
| gold, mustard | Yellow |
| amber, coral, peach, terracotta, rust | Orange |
| teal, turquoise, aqua | Teal |

---

## 6. Category synonyms

Query terms normalised to a single category term.

| From | To |
|------|-----|
| jumper, jumpers, sweaters | sweater |
| trainers, sneaker, trainer | sneakers |
| coat, coats | jacket |
| tshirt, t-shirt, t shirt, tshirts | tee |
| bag, bags, handbags | handbag |
| hoody, hoodies | hoodie |
| trouser, pant, pants | trousers |
| heel, boot | heels, boots |

---

## 7. Category keywords

Product types used for fuzzy matching (e.g. dress, jacket). Typos within Levenshtein distance 2 are corrected.

| Keywords |
|----------|
| dress, dresses, hoodie, hoodies, jacket, jackets, coat, coats, jeans, trousers, skirt, skirts, heels, boots, trainers, sneakers, bag, handbag, handbags, jumper, sweater, sweaters, tee, tshirt, shirt, shirts, top, tops, blouse, blouses, scarf, scarves, outfit, outfits, cardigan, cardigans, blazer, blazers, joggers, jogger, cargo, flannel, bomber |

---

## 8. Conversational strippers

Phrases removed from the start or end of the query so “do you have a green dress” is treated like “green dress”.

| Phrases |
|---------|
| do you have, do you have a, do you have any, do u have, do u have a |
| im looking for, i'm looking for, i am looking for, looking for, looking for a |
| im searching for, i'm searching for, i am searching for, searching for, searching for a |
| i want, i want a, i need, i need a, show me, show me a, show me some |
| can i get, can you show, got any, have you got, need a, want a |
| asap, pls, please, thanks, thank you |

---

## 9. Search stopwords

Words dropped from the final search string (articles, filler, colour modifiers).

| Stopwords |
|-----------|
| a, an, the, do, you, have, has, get, got, for, to, of, im, i'm, me, and, or, but, that, this, is, it, in, on |
| lighter, darker, light, dark, almost, soft, pale, faded, bright, not, than, something, close |

---

## 10. Happy event words

Presence triggers a more cheerful tone in replies.

| Words |
|-------|
| birthday, wedding, festival, holiday, holidays, celebration, party, vacation, trip, graduation, date night, travel |

---

## 11. Sad event words

Presence triggers a neutral, considerate tone.

| Words |
|-------|
| funeral, breakup, break up, memorial |

---

## 12. Season keywords

Kept in the search string when present.

| Seasons |
|---------|
| winter, summer, autumn, spring |

---

## 13. Material keywords

Kept in the search string when present.

| Materials |
|-----------|
| leather, denim, cotton, wool, silk, linen |

---

## 14. Style keywords

Kept in the search string when present.

| Styles |
|--------|
| vintage, minimalist, oversized, streetwear, y2k, casual, elegant, sporty, retro, relaxed |

---

## 15. Budget words (word → max price £)

When no “under £X” is found, these set a default max price.

| Word | Max £ |
|------|--------|
| cheap | 30 |
| budget | 35 |
| affordable | 40 |

**Price pattern (regex):** `under\s*[£$]?\s*(\d+)` (case insensitive).

---

## 16. Typo matching

- **Max Levenshtein distance:** 2 (e.g. derss → dress, gren → Green).
- **Min length for fuzzy match:** 3 characters.

---

## 17. Valid sizes

Extracted from “size M”, “size 32”, etc. and appended to search.

| Valid size tokens |
|-------------------|
| xs, s, m, l, xl, xxl, small, medium, large, or any numeric string |

---

## 18. Response sets (Batch 1–4)

Each set has a **name** (used in selection logic) and a list of **responses**. The AI picks one response at random when the set is selected. Sets with more than 5 entries have had extra alternatives added from later batches.

### Batch 1

#### birthday_party
1. Happy birthday! Let's find some great green dresses for your celebration.
2. That sounds fun! Here are some green dresses that could work perfectly for a birthday party.
3. Let's explore some green dress options for your birthday.
4. Here are some green dresses that might be great for a birthday outfit.
5. I'll show you some green dresses that could be perfect for celebrating.

#### boots_under_price
1. Here are some black boots under £50 you might like.
2. These black boots match your budget.
3. Let's explore some affordable black boot options.
4. I've found some black boots within your price range.
5. Here are some budget-friendly black boots.

#### lighter_than_navy
1. Let's explore some shades lighter than navy, like cobalt or royal blue.
2. Here are some blue options slightly lighter than navy.
3. You might like these bright navy and royal blue items.
4. These items sit between navy and bright blue.
5. Here are some lighter blue pieces close to navy.

#### comfy_travel
1. Here are some comfortable hoodies that could be great for travel.
2. Let's find a cosy hoodie perfect for travelling.
3. These relaxed hoodies might be ideal for your trip.
4. Here are some hoodies designed for comfort.
5. You might like these soft travel-friendly hoodies.

#### vintage_denim
1. Here are some vintage denim jackets you might like.
2. Let's explore some retro denim jacket styles.
3. These jackets have a vintage denim look.
4. Here are some classic denim jackets.
5. You might like these vintage-inspired denim jackets.

#### night_out_dress
1. Here are some short black dresses perfect for a night out.
2. Let's find a stylish black dress for your night out.
3. These short black dresses could work well.
4. You might like these sleek black dress options.
5. Here are some great night-out dresses.

#### everyday_trainers (10 responses)
1. Here are some white trainers great for everyday use.
2. Let's explore some versatile white trainers.
3. These white trainers are perfect for daily wear.
4. You might like these comfortable white sneakers.
5. Here are some casual white trainer options.
6. Here are some white trainers under £40.
7. Let's explore some budget-friendly white trainer options.
8. These trainers stay within your price range.
9. You might like these affordable white sneakers.
10. Here are some everyday trainers under £40.

#### beige_minimalist
1. Here are some minimalist beige pieces.
2. Let's explore some clean beige styles.
3. These neutral beige items might match that look.
4. You might like these simple beige designs.
5. Here are some understated beige options.

#### oversized_hoodies (15 responses)
1. Here are some oversized hoodies you might like.
2. Let's explore some relaxed-fit hoodies.
3. These hoodies have an oversized style.
4. You might like these baggy hoodie options.
5. Here are some loose-fit hoodies.
6. Here are some oversized hoodies with a streetwear vibe.
7. Let's explore some relaxed streetwear hoodie styles.
8. These hoodies have an oversized streetwear look.
9. You might like these baggy hoodie designs.
10. Here are some casual streetwear hoodies.
11. Here are some comfy oversized hoodies.
12. Let's explore some relaxed hoodie styles.
13. These hoodies focus on comfort and fit.
14. You might like these loose hoodie options.
15. Here are some cosy hoodie picks.

#### festival_colourful
1. Let's find some colourful outfits perfect for a festival.
2. Here are some vibrant pieces you might like.
3. These colourful items could be great for a festival.
4. You might enjoy these bright festival outfits.
5. Here are some fun and colourful styles.

#### jeans_not_skinny
1. Here are some relaxed-fit blue jeans.
2. Let's explore some straight-leg denim options.
3. These looser jeans might suit you.
4. You might like these wide-leg jeans.
5. Here are some comfortable denim styles.

#### winter_coat (10 responses)
1. Here are some warm coats perfect for winter.
2. Let's explore some winter coat options.
3. These coats could keep you warm.
4. You might like these thick winter jackets.
5. Here are some cosy outerwear choices.
6. Here are some beige winter coats.
7. Let's explore some warm neutral coats.
8. These coats could work well for winter.
9. You might like these cosy beige styles.
10. Here are some elegant coats.

#### leather_jackets
1. Here are some leather jackets you might like.
2. Let's explore some leather jacket styles.
3. These jackets have a leather finish.
4. You might like these biker-style jackets.
5. Here are some leather outerwear options.

#### dresses_under_price
1. Here are some dresses under £30.
2. Let's explore some budget-friendly dresses.
3. These dresses fit within your price range.
4. You might like these affordable styles.
5. Here are some low-cost dress options.

#### party_dress (10 responses)
1. Here are some red dresses perfect for a party.
2. Let's explore some bold red dress options.
3. These red dresses could be great for a party.
4. You might like these vibrant red styles.
5. Here are some festive red dresses.
6. Here are some red dresses perfect for a party.
7. Let's explore some bold party dress options.
8. These dresses could work well for a party.
9. You might like these vibrant red styles.
10. Here are some festive dress options.

#### green_hoodies (10 responses)
1. Here are some green hoodies you might like.
2. Let's explore some green hoodie styles.
3. These hoodies come in green shades.
4. You might like these casual green hoodies.
5. Here are some comfortable green hoodie options.
6. Here are some dark green hoodies that stay within a lower budget.
7. Let's explore some affordable dark green hoodies.
8. These green hoodies might match what you're looking for.
9. I've found some budget-friendly dark green hoodie options.
10. Here are some green hoodies that shouldn't break the bank.

#### wedding_classy
1. Let's explore some elegant wedding outfit options.
2. Here are some classy styles that might suit a wedding.
3. These outfits could work well for a wedding.
4. You might like these refined pieces.
5. Here are some sophisticated options.

#### yellow_sweaters
1. Here are some yellow sweaters.
2. Let's explore some bright sweater options.
3. These sweaters come in yellow tones.
4. You might like these warm yellow knits.
5. Here are some colourful sweater options.

#### casual_everyday_jacket
1. Here are some casual jackets you might like.
2. Let's explore some everyday jacket styles.
3. These jackets are great for daily wear.
4. You might like these relaxed outerwear options.
5. Here are some comfortable jackets.

#### stylish_cheap (15 responses)
1. Let's explore some stylish budget options.
2. Here are some affordable fashion pieces.
3. These items combine style and value.
4. You might like these trendy affordable picks.
5. Here are some stylish items within a lower budget.
6. Let's explore some stylish pieces that are still budget-friendly.
7. Here are some affordable options that could work for dinner.
8. These items combine elegance and value.
9. You might like these classy yet affordable styles.
10. Here are some stylish pieces within a lower price range.
11. Let's explore some trendy pieces that are still affordable.
12. Here are some fashionable budget options.
13. These items combine style and value.
14. You might like these trendy picks within a lower budget.
15. Here are some affordable fashion pieces.

---

### Batch 2

#### light_blue_jeans
1. Here are some light blue jeans you might like.
2. Let's explore some lighter denim styles.
3. These jeans come in light blue shades.
4. You might like these faded blue denim options.
5. Here are some casual light blue jeans.

#### yellow_scarf_winter
1. Here are some yellow scarves that could work well for winter.
2. Let's explore some warm yellow scarf options.
3. These yellow scarves might match what you're looking for.
4. You might like these cosy winter scarves.
5. Here are some bright scarf options.

#### between_blue_green
1. Let's explore colours between blue and green like teal or turquoise.
2. Here are some teal and aqua coloured items.
3. These pieces blend blue and green tones.
4. You might like these turquoise styles.
5. Here are some items in that colour range.

#### heels_under_price
1. Here are some red heels under £40.
2. Let's explore some affordable red heel options.
3. These heels match your budget.
4. You might like these red shoe styles.
5. Here are some budget-friendly heels.

#### holiday_light_dresses
1. Let's find some lightweight dresses perfect for a holiday.
2. Here are some breezy dress options.
3. These dresses might work well for warm weather.
4. You might like these summer dresses.
5. Here are some relaxed holiday dresses.

#### brown_leather_boots
1. Here are some brown leather boots you might like.
2. Let's explore some leather boot styles.
3. These boots come in brown leather.
4. You might like these classic boot designs.
5. Here are some stylish leather boots.

#### neutral_work
1. Let's explore some neutral outfits suitable for work.
2. Here are some simple office-friendly pieces.
3. These neutral styles might work well.
4. You might like these professional outfits.
5. Here are some understated workwear options.

#### black_handbags
1. Here are some black handbags you might like.
2. Let's explore some stylish bag options.
3. These handbags come in black.
4. You might like these classic bag styles.
5. Here are some everyday handbags.

#### trainers_gym
1. Here are some trainers that could work well for the gym.
2. Let's explore some sporty trainer options.
3. These shoes might be good for workouts.
4. You might like these athletic trainers.
5. Here are some comfortable gym shoes.

#### vintage_dresses
1. Here are some vintage-style dresses.
2. Let's explore some retro dress options.
3. These dresses have a vintage look.
4. You might like these classic styles.
5. Here are some timeless dresses.

#### muted_green_jacket
1. Here are some muted green jackets.
2. Let's explore some darker green outerwear.
3. These jackets have subtle green tones.
4. You might like these olive green jackets.
5. Here are some softer green options.

#### cheap_hoodies
1. Here are some budget-friendly hoodies.
2. Let's explore some affordable hoodie options.
3. These hoodies stay within a lower price range.
4. You might like these casual hoodies.
5. Here are some inexpensive styles.

#### pink_skirts
1. Here are some pink skirts you might like.
2. Let's explore some skirt styles in pink.
3. These skirts come in pink shades.
4. You might like these colourful skirts.
5. Here are some casual skirt options.

#### cute_date
1. Let's explore some cute outfit options.
2. Here are some styles that might work well for a date.
3. These outfits might match that vibe.
4. You might like these flattering looks.
5. Here are some stylish pieces.

#### grey_hoodies
1. Here are some grey hoodies.
2. Let's explore some hoodie styles in grey.
3. These hoodies come in grey tones.
4. You might like these casual hoodies.
5. Here are some relaxed hoodie options.

#### warm_stylish
1. Let's explore some warm and stylish pieces.
2. Here are some cosy outfit options.
3. These items combine comfort and style.
4. You might like these winter-ready styles.
5. Here are some warm fashion picks.

#### blue_jackets
1. Here are some blue jackets.
2. Let's explore some jacket styles in blue.
3. These jackets come in blue shades.
4. You might like these casual jackets.
5. Here are some outerwear options.

---

### Batch 3

#### olive_cargo_trousers
1. Here are some olive green cargo trousers you might like.
2. Let's explore some cargo trousers in olive green.
3. These trousers match the olive green cargo style.
4. You might like these relaxed cargo trousers.
5. Here are some casual olive green cargo options.

#### pastel_pink_cardigans
1. Here are some pastel pink cardigans you might like.
2. Let's explore some soft pink cardigan styles.
3. These cardigans come in pastel pink shades.
4. You might like these light pink knitwear options.
5. Here are some cosy pastel cardigans.

#### navy_blazer_work
1. Here are some navy blue blazers suitable for work.
2. Let's explore some professional navy blazer options.
3. These blazers could work well for office wear.
4. You might like these classic navy styles.
5. Here are some smart blazer options.

#### oversized_grey_sweaters
1. Here are some oversized grey sweaters you might like.
2. Let's explore some relaxed grey knitwear.
3. These sweaters have an oversized fit.
4. You might like these cosy grey styles.
5. Here are some comfortable oversized sweaters.

#### brown_suede_jackets
1. Here are some brown suede jackets you might like.
2. Let's explore some suede outerwear options.
3. These jackets come in brown suede.
4. You might like these classic suede styles.
5. Here are some stylish suede jackets.

#### dark_blue_skinny_jeans
1. Here are some dark blue skinny jeans you might like.
2. Let's explore some fitted denim styles.
3. These jeans come in dark blue shades.
4. You might like these slim-fit denim options.
5. Here are some classic skinny jeans.

#### cream_sweater_winter
1. Here are some cream knit sweaters perfect for winter.
2. Let's explore some warm knitwear options.
3. These sweaters come in cream tones.
4. You might like these cosy winter knits.
5. Here are some soft cream sweaters.

#### yellow_summer_dress
1. Here are some yellow summer dresses.
2. Let's explore some bright summer styles.
3. These dresses come in yellow shades.
4. You might like these warm-weather dresses.
5. Here are some light and colourful dress options.

#### muted_purple_hoodie
1. Here are some hoodies in muted purple tones.
2. Let's explore some soft purple hoodie styles.
3. These hoodies come in subtle purple shades.
4. You might like these relaxed hoodie options.
5. Here are some understated purple hoodies.

#### vintage_leather_bags
1. Here are some vintage brown leather bags.
2. Let's explore some classic leather bag styles.
3. These bags have a vintage leather look.
4. You might like these timeless leather designs.
5. Here are some retro-inspired handbags.

#### oversized_black_tees
1. Here are some oversized black t-shirts you might like.
2. Let's explore some relaxed-fit black tees.
3. These t-shirts have an oversized style.
4. You might like these streetwear-style shirts.
5. Here are some loose black t-shirts.

#### minimalist_white_shirts
1. Here are some minimalist white shirts.
2. Let's explore some clean and simple shirt designs.
3. These shirts follow a minimalist style.
4. You might like these classic white shirts.
5. Here are some understated shirt options.

#### green_dress_graduation
1. Congratulations on graduating! Let's find a great green dress.
2. Here are some green dresses that could work for graduation.
3. Let's explore some elegant green dress options.
4. You might like these graduation-ready dresses.
5. Here are some stylish green dresses.

#### light_grey_joggers
1. Here are some light grey joggers.
2. Let's explore some comfortable jogger options.
3. These joggers come in light grey shades.
4. You might like these casual joggers.
5. Here are some relaxed-fit joggers.

#### comfy_travel_generic
1. Let's explore some comfortable travel outfits.
2. Here are some relaxed clothing options for travelling.
3. These pieces focus on comfort.
4. You might like these easygoing styles.
5. Here are some comfy travel picks.

#### black_stylish_trainers
1. Here are some stylish black trainers.
2. Let's explore some fashionable trainer options.
3. These trainers combine style and comfort.
4. You might like these sleek black sneakers.
5. Here are some trendy trainer options.

#### vintage_denim_jeans
1. Here are some vintage denim jeans.
2. Let's explore some retro denim styles.
3. These jeans have a vintage look.
4. You might like these classic denim options.
5. Here are some old-school denim styles.

#### casual_weekend
1. Let's explore some casual weekend outfits.
2. Here are some relaxed styles perfect for weekends.
3. These pieces are great for everyday wear.
4. You might like these comfortable outfits.
5. Here are some easygoing clothing options.

---

### Batch 4

#### bold_colourful
1. Let's explore some bold and colourful fashion pieces.
2. Here are some vibrant items you might like.
3. These pieces feature bright colours and standout designs.
4. You might enjoy these colourful styles.
5. Here are some eye-catching outfits.

#### pastel_blue_hoodie
1. Here are some hoodies in pastel blue.
2. Let's explore some soft blue hoodie styles.
3. These hoodies come in light blue shades.
4. You might like these relaxed pastel hoodies.
5. Here are some cosy pastel blue options.

#### elegant_heels_wedding
1. Here are some elegant heels suitable for a wedding.
2. Let's explore some sophisticated shoe options.
3. These heels could work well for a wedding outfit.
4. You might like these classy footwear styles.
5. Here are some stylish wedding heels.

#### smart_jacket_work
1. Here are some smart jackets suitable for work.
2. Let's explore some professional outerwear.
3. These jackets might work well for the office.
4. You might like these tailored jacket styles.
5. Here are some polished jacket options.

#### cosy_cardigans_winter
1. Here are some cosy winter cardigans.
2. Let's explore some warm knitwear.
3. These cardigans could keep you warm in winter.
4. You might like these comfortable knit styles.
5. Here are some soft cardigan options.

#### neutral_simple
1. Let's explore some neutral and minimalist styles.
2. Here are some simple clothing options.
3. These pieces focus on clean and neutral tones.
4. You might like these understated outfits.
5. Here are some minimalist wardrobe pieces.

#### oversized_flannel_shirts
1. Here are some oversized flannel shirts.
2. Let's explore some relaxed flannel styles.
3. These shirts feature an oversized fit.
4. You might like these casual flannel options.
5. Here are some cosy flannel shirts.

#### light_brown_boots
1. Here are some light brown boots.
2. Let's explore some brown boot styles.
3. These boots come in lighter brown shades.
4. You might like these classic boot options.
5. Here are some casual brown boots.

#### black_skirts_work
1. Here are some black skirts suitable for work.
2. Let's explore some office-friendly skirt styles.
3. These skirts could work well for professional outfits.
4. You might like these classic skirt options.
5. Here are some simple black skirts.

#### lightweight_summer_jacket
1. Here are some lightweight jackets perfect for summer.
2. Let's explore some breathable outerwear.
3. These jackets could work well for warm weather.
4. You might like these casual summer styles.
5. Here are some light jacket options.

#### blue_hoodies_everyday
1. Here are some blue hoodies for everyday wear.
2. Let's explore some casual hoodie options.
3. These hoodies come in blue shades.
4. You might like these comfortable styles.
5. Here are some relaxed hoodie picks.

#### stylish_handbag_under_price
1. Here are some stylish handbags under £50.
2. Let's explore some fashionable bag options within your budget.
3. These handbags stay under £50.
4. You might like these affordable bag styles.
5. Here are some budget-friendly handbags.

#### beige_trousers_office
1. Here are some beige trousers suitable for office wear.
2. Let's explore some professional trouser styles.
3. These trousers could work well for work outfits.
4. You might like these neutral trouser options.
5. Here are some office-ready trousers.

#### vintage_bomber_jacket
1. Here are some vintage bomber jackets.
2. Let's explore some retro bomber styles.
3. These jackets have a vintage bomber look.
4. You might like these classic bomber designs.
5. Here are some stylish bomber jackets.

#### pastel_sweaters
1. Here are some sweaters in pastel colours.
2. Let's explore some soft-toned knitwear.
3. These sweaters feature pastel shades.
4. You might like these light coloured sweaters.
5. Here are some gentle pastel styles.

#### lightweight_scarf_spring
1. Here are some lightweight scarves perfect for spring.
2. Let's explore some breathable scarf styles.
3. These scarves are ideal for warmer weather.
4. You might like these soft scarf options.
5. Here are some spring-ready scarves.

#### stylish_boots_winter
1. Here are some stylish boots suitable for winter.
2. Let's explore some winter boot options.
3. These boots combine warmth and style.
4. You might like these fashionable winter boots.
5. Here are some cosy boot picks.

---

## 19. Warm lead-in phrases

One of these is chosen at random and prepended to every successful result reply so the AI feels warm and personable.

1. I can certainly help you with that.
2. Of course!
3. Let me have a look…
4. Happy to help!
5. I'd be glad to.
6. Sure thing!
7. Absolutely!
8. Let me find something for you.
9. I'm on it!
10. No problem at all.
11. Consider it done.
12. I've got you covered.
13. Here we go!
14. Let me see what I can find.
15. I'd love to help.
16. Of course I can!
17. Glad to help!
18. One moment…
19. Coming right up!
20. I'll see what's available.

---

## 20. Spelling correction

When a word is corrected by fuzzy match (category or colour), the first correction is stored as `spellingCorrectionHint: (original, corrected)`. The reply can then start with:

- **English:** `Do you mean "Dress"?` (from key `Do you mean \"%@\"?`)
- **Greek:** `Εννοείτε "Dress";`

---

## 21. Salutations (100 greeting phrases)

If the user's message, after normalisation (lowercase, trim, collapse spaces, straight apostrophe), matches **any** of the phrases below, the AI treats it as a greeting and responds with a random greeting reply (e.g. *"Hi! What are you looking for? Try something like a dress, jacket, or shoes."*) instead of running a product search.

Matching is exact on the normalised string; e.g. "Hey there", "HEY THERE", and "hey   there" all match "hey there". Curly apostrophes (’) are normalised to straight (') so "what's up" and "what's up" both match.

| # | Phrase | # | Phrase | # | Phrase | # | Phrase |
|---|--------|---|--------|---|--------|---|--------|
| 1 | hi | 26 | good day | 51 | hello team | 76 | hello good evening |
| 2 | hello | 27 | greetings | 52 | hey again | 77 | hey good afternoon |
| 3 | hey | 28 | greetings friend | 53 | hi again | 78 | hi good afternoon |
| 4 | hey there | 29 | howdy | 54 | hello again | 79 | hello good afternoon |
| 5 | hi there | 30 | howdy there | 55 | hey how are you | 80 | hey there friend |
| 6 | hello there | 31 | hey friend | 56 | hi how are you | 81 | hi there friend |
| 7 | heyy | 32 | hi friend | 57 | hello how are you | 82 | hello there friend |
| 8 | hiii | 33 | hello friend | 58 | hey how's it going | 83 | hey there mate |
| 9 | hey hey | 34 | hey mate | 59 | hi how's it going | 84 | hi there mate |
| 10 | hello hello | 35 | hi mate | 60 | hello how's it going | 85 | hello there mate |
| 11 | hiya | 36 | hello mate | 61 | hey how you doing | 86 | hey there buddy |
| 12 | heya | 37 | hey buddy | 62 | hi how you doing | 87 | hi there buddy |
| 13 | yo | 38 | hi buddy | 63 | hello how you doing | 88 | hello there buddy |
| 14 | yoo | 39 | hello buddy | 64 | hey what's going on | 89 | hey hey there |
| 15 | yo yo | 40 | hey pal | 65 | hi what's going on | 90 | hi hi |
| 16 | sup | 41 | hi pal | 66 | hello what's going on | 91 | hello hello there |
| 17 | what's up | 42 | hello pal | 67 | hey what's happening | 92 | hey how's everything |
| 18 | hey what's up | 43 | hey everyone | 68 | hi what's happening | 93 | hi how's everything |
| 19 | hi what's up | 44 | hi everyone | 69 | hello what's happening | 94 | hello how's everything |
| 20 | hello what's up | 45 | hello everyone | 70 | hey what's new | 95 | hey what's good |
| 21 | good morning | 46 | hey guys | 71 | hi what's new | 96 | hi what's good |
| 22 | morning | 47 | hi guys | 72 | hello what's new | 97 | hello what's good |
| 23 | good afternoon | 48 | hello guys | 73 | hey good morning | 98 | hey what's good |
| 24 | afternoon | 49 | hey team | 74 | hi good morning | 99 | hi what's good |
| 25 | good evening | 50 | hi team | 75 | hello good morning | 100 | hello what's good |
| (cont.) | evening | (cont.) | (cont.) | (cont.) | hey good evening | (cont.) | (cont.) |

---

## 22. Social greeting Q&A (100 questions + answers)

When the user asks a **social/greeting question** (e.g. "Hi, how are you?", "Hey, what's up?", "Hello, how's your day?"), the AI must respond with a greeting-style reply and **no product search**. Input is normalised (lowercase, trim, collapse spaces, straight apostrophe, strip `, . ! ?`) so "Hi, how are you?" matches the phrase "hi how are you".

**Detection:** The same normalisation as §21 is used. If the normalised string is in `socialGreetingPhrases` (or in `salutations`), the AI responds with a random entry from `greetingReplies` and does **not** run a product search or show fallback "tops" etc.

**100 social phrases** (stored normalised; examples of what users might type): hi how are you, hey how are you, hello how are you; hi how are you today, hey how are you today, hello how are you today; hi hows it going, hey hows it going, hello hows it going; hi how you doing, hey how you doing, hello how you doing; hi how are you doing, hey how are you doing, hello how are you doing; hi whats up, hey whats up, hello whats up; hi whats new, hey whats new, hello whats new; hi hows your day, hey hows your day, hello hows your day; hi hows your day going, hey hows your day going, hello hows your day going; hi hows everything, hey hows everything, hello hows everything; hi how have you been, hey how have you been, hello how have you been; hi how do you do, hey how do you do, hello how do you do; hi whats going on, hey whats going on, hello whats going on; hi whats happening, hey whats happening, hello whats happening; hi whats good, hey whats good, hello whats good; hi hows life, hey hows life, hello hows life; hi good to see you, hey good to see you, hello good to see you; hi nice to meet you, hey nice to meet you, hello nice to meet you; hi good morning how are you, hey good morning how are you, hello good morning how are you; hi there how are you, hey there how are you, hello there how are you; hi whats up today, hey whats up today, hello whats up today; hi how is your day, hey how is your day, hello how is your day; hi how are things, hey how are things, hello how are things; hi how have you been doing, hey how have you been doing, hello how have you been doing; hi great to see you, hey great to see you, hello great to see you; hi lovely to meet you, hey lovely to meet you, hello lovely to meet you; hi hope you are well, hey hope you are well, hello hope you are well; hi hope youre well, hey hope youre well, hello hope youre well; hi how you been, hey how you been, hello how you been; hi whats the vibe, hey whats the vibe, hello whats the vibe; hi hows your morning, hey hows your morning, hello hows your morning; hi hows your evening, hey hows your evening, hello hows your evening; hi good to chat, hey good to chat, hello good to chat; hi good afternoon how are you, hey good afternoon how are you, hello good afternoon how are you; hi good evening how are you, hey good evening how are you, hello good evening how are you; hi how is it going, hey how is it going, hello how is it going; hi whats cracking, hey whats cracking, hello whats cracking; hi how are we, hey how are we, hello how are we; hi how are you feeling, hey how are you feeling, hello how are you feeling; hi alright, hey alright, hello alright; hi you good, hey you good, hello you good; hi everything good, hey everything good, hello everything good.

**Answers:** The AI uses the same pool as §21 - `greetingReplies` - which includes both short prompts (e.g. "Hi! What are you looking for?") and social-style replies (e.g. "I'm good, thanks! What can I help you find today?", "Doing great! What are you looking for?", "All good here! What would you like to browse?"). One is chosen at random so the response feels natural.

---

*Last synced with `Prelura-swift/Services/AISearchService.swift`. Update this file whenever the model is updated.*
