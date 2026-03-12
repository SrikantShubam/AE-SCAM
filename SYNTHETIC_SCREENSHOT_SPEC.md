# Synthetic Screenshot Spec

## Objective

Create realistic message screenshots from seed text so we can start OCR and
classification evaluation before a large real-screenshot corpus exists.

## Channels to simulate

- SMS
- WhatsApp
- email

## Markets to simulate

- India
- US

## Required screenshot variants

### SMS

- India:
  - alphanumeric sender IDs
  - short code style
  - bank-style transactional message layout
- US:
  - phone numbers
  - short codes
  - carrier-style SMS layout

### WhatsApp

- incoming message bubbles
- forwarded-style message appearance
- contact name visible
- timestamps visible
- optional dark mode

### Email

- subject line visible
- sender email visible
- body preview or opened email view
- common mobile email client styling

## Quality tiers

### Clean

- sharp image
- no crop loss
- standard compression
- high contrast

### Medium

- mild blur
- mild compression
- slightly smaller text
- dark mode or mixed contrast

### Hard

- aggressive JPEG compression
- crop loss
- angle distortion
- low contrast
- forwarded / resaved appearance

## Required scam-span coverage

Each generated corpus batch should include enough samples containing:

- URLs
- phone numbers
- payment amounts
- OTPs / codes
- urgency phrases
- impersonation cues

## Rendering rules

- preserve realistic line breaks
- preserve sender line styling
- preserve timestamp placement
- avoid unrealistically clean typography
- vary font size slightly across templates

## Annotation rules for synthetic samples

- every synthetic screenshot must retain:
  - source text id
  - rendered screenshot id
  - channel
  - market
  - quality tier
  - gold text
  - scam spans

## Initial target

Create the first 100 synthetic screenshots as:

- 35 SMS
- 35 WhatsApp
- 30 email

Suggested market split:

- 50 India
- 50 US

Suggested label split:

- 40 scam
- 40 not_scam
- 20 unclear

## Success condition

The synthetic set is good enough for OCR bake-off when:

- it covers all major categories
- it covers all quality tiers
- it includes the scam-critical spans
- it looks visually close enough to real phone screenshots to stress OCR
