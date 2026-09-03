# Santuri Bookings — Agent Guide

## Project overview

This is a lightweight static booking and information website for Santuri East Africa's creative spaces in Nairobi. Keep it framework-free unless the user explicitly requests a migration. Calendly provides scheduling.

## Working rules

- Keep changes local unless the user explicitly asks to publish or push.
- Do not update the private Sites preview or the live custom domain by default.
- Do not invent operational details, equipment inventories, policies, prices, capacities, or availability.
- Preserve the monochrome black-and-white visual system and the interactive topographic canvas background.
- Maintain responsive behavior, keyboard access, visible focus states, and reduced-motion support.
- Retain direct Calendly URLs as fallbacks whenever using the embedded popup launcher.
- Use bookings@santuri.org for booking enquiries.

## Important files

- index.html: booking-focused homepage
- spaces.html: detailed editorial information about each space
- assets/css/main.css: shared styles for every page
- assets/js/main.js: room data, filtering, Calendly launchers, analytics hooks, and canvas animation
- booking-policy.html: operating terms and house rules
- privacy.html: privacy information
- assets/images/: optimized production images
- images/: original source images
- sitemap.xml and robots.txt: search-engine discovery files

## Confirmed business information

- Opening hours: 09:00–18:00
- Minimum booking: one hour
- Standard space rate: 1,000 KES per hour
- Studio capacity: five people
- DJ practice room capacity: three people
- Classroom capacity: twenty people
- Workstation capacity: one person
- Staff are available to help.
- Studio engineers can be arranged for 2,500 KES per hour.
- Address: Santuri East Africa, Basement, The Mall, Chiromo Road / Ring Road Westlands, Nairobi, Kenya

## Experience and content

- Homepage cards should remain compact and comparison-friendly.
- On wide screens, show all four homepage cards in one row; step down to two columns on tablets and one column on mobile.
- Keep the homepage and card area white with subtle outlines, black type, and black primary actions.
- “View details” links should open the matching section of spaces.html.
- Booking actions should use the Calendly popup when its script is available and retain working direct-link fallbacks.
- The Spaces page uses the large room images in assets/images and alternates image/text feature sections.
- Keep the DJ feature compact: its portrait source is displayed in a cropped 4:3 frame focused on the performer and equipment.
- The Visit section uses a two-column address-and-square-map layout on desktop and stacks on mobile.
- The black “Need help?” strip sits below the Visit address/map row and must remain full-bleed to both viewport edges and the bottom of the section.
- The main footer is white so the original black logo remains visible without inversion.
- The header is sticky and uses a deliberately small logo.
- Inclusion wording: “Everyone is welcome at Santuri.” Harassment or discrimination of any kind is not tolerated.
- House rules cover closed drink containers, no indoor smoking or vaping, safeguarding personal belongings, respectful conduct, and responsible equipment use.

## Local verification

Serve the repository as static files and check index.html, spaces.html, booking-policy.html, and privacy.html. Validate assets/js/main.js after JavaScript edits and confirm all referenced images exist.
