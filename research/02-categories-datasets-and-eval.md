# Categories, Datasets, and Evaluation Research

## Objective

Decide which scam categories to target first, what data to gather, and how to
measure whether the product is good enough to trust.

## 1. Top categories for v1

Your current categories are directionally correct, but I would tighten them to
match common elder-fraud patterns and message-based detection.

### Recommended v1 category set

1. `Impersonation`
   - bank, government, delivery, telecom, support, family-member impersonation
2. `Credential theft`
   - phishing for passwords, OTPs, login links, account recovery codes
3. `Payment extraction`
   - gift cards, bank transfer, crypto, fake fees, fake overdue bills
4. `Tech support / device compromise`
   - fake virus, fake account lock, fake security emergency
5. `Emotion / pressure fraud`
   - romance, family emergency, panic, threats, urgency, shame pressure

### Why this set

It aligns better with official elder-fraud reporting than generic buckets like
`selling` or broad `frauds`.

The FBI’s reported elder-fraud patterns support prioritizing:

- tech support
- personal data breach / credential theft
- confidence / romance
- non-delivery or payment extraction
- investment and impersonation patterns

## 2. Dataset procurement strategy

No single public dataset will be enough. Build a layered dataset strategy.

### Layer A: Public seed datasets

Use public datasets to bootstrap taxonomy and model evaluation:

- UCI SMS Spam Collection
- Mendeley SMS Phishing Dataset
- Sting9 phishing / scam message dataset

### Layer B: Internal product benchmark

Build your own screenshot-first benchmark because the app’s real problem is not
just classifying text, but handling messy screenshots from real users.

Include:

- cropped SMS screenshots
- WhatsApp screenshots
- email screenshots
- fake bank alert screenshots
- mixed-quality screenshots with blur, glare, and compression

### Layer C: Hard-case set

Maintain a separate hard-case set for:

- ambiguous legitimate alerts
- political / charity solicitations
- OTP and verification messages
- courier or delivery notices
- customer-support follow-ups
- gray-area financial reminders

## 3. Recommended benchmark structure

Each benchmark item should include:

- `sample_id`
- `market`
  - `india` or `us`
- `channel`
  - `sms`, `whatsapp`, `email`, `popup`, `other`
- `input_type`
  - `text` or `screenshot`
- `ground_truth_label`
  - `scam`, `not_scam`, `unclear`
- `category`
- `message_text_gold`
  - human-corrected text for screenshot items
- `image_quality`
  - `clean`, `medium`, `hard`
- `ocr_output`
- `ocr_edit_distance`
- `model_output`
- `final_policy_output`
- `human_explanation`
- `recommended_action`

## 4. False-positive guidance

This needs calibration, but the key principle is:

- false reassurance is dangerous
- false alarms damage trust and retention

### Recommendation

Optimize for:

- very low false negatives on obvious scams
- controlled false positives on legitimate finance and account messages
- strong use of `Unclear` as a safety buffer

### Working acceptance targets

These are product targets, not externally sourced standards:

- obvious-scam recall should be very high before launch
- false positives on clearly legitimate transactional messages should be low
- any confusion-heavy slice should route more often to `Unclear`

I would not freeze exact numeric targets until the first benchmark exists.

## 5. Dataset research recommendations

Before training or prompt-tuning anything, answer:

- How many examples do we have per category?
- How many screenshot examples do we have per market?
- How many real-user-style “hard” screenshots do we have?
- How many ambiguous-but-legitimate examples do we have?

Without that, you will overestimate quality.

## Source Notes

- FBI elder fraud overview: https://www.fbi.gov/news/stories/elder-fraud-in-focus
- FBI elder fraud report summary: https://www.fbi.gov/contact-us/field-offices/cincinnati/news/fbi-elder-fraud-report-highlights-frauds-and-scams-targeting-older-americans
- FTC impersonation scams: https://www.ftc.gov/news-events/news/press-releases/2024/06/ftc-data-shows-major-increases-cash-payments-government-impersonation-scammers
- UCI SMS Spam Collection: https://archive.ics.uci.edu/dataset/228
- SMS Phishing Dataset (Mendeley): https://data.mendeley.com/datasets/f45bkkt8pr/1
- Sting9 dataset: https://sting9.org/dataset
