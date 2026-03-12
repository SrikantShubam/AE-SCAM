# Product Semantics Research

## Objective

Define what the app should say, what the result states actually mean, and how
the user should be guided after each result.

## 1. What counts as `Scam`, `Not scam`, and `Unclear`

### Working product definitions

- `Scam`
  - a message likely uses deception to obtain money, credentials, identity
    information, one-time codes, remote access, or an unsafe payment action
- `Not scam`
  - the message does not show meaningful scam signals and there is no strong
    evidence of impersonation, coercion, credential theft, or unsafe payment
    demand
- `Unclear`
  - the message contains mixed or incomplete signals, or OCR/model evidence is
    too weak for a safe conclusion

### Research-backed signal families

Government and business impersonation, urgent requests for payment, and requests
for personal or financial information are recurring official warning signs in
FTC and CISA guidance. The FBI’s elder-fraud reporting also supports focusing on
impersonation, credential theft, emotional manipulation, and tech-support style
pressure first.

### Practical rule

The app should classify based on *evidence of malicious intent or unsafe action*,
not merely on whether a message is annoying or promotional.

That means:

- spam marketing is not automatically a high-severity scam
- a fake bank alert asking for login details is
- a message that could be legitimate but cannot be verified should land in
  `Unclear`, not `Not scam`

## 2. Are the three user-facing labels good enough?

### Current recommendation

Do not show raw internal classes like `high confidence: 87%` as the main UI.

Use plain-language result states:

- `Likely scam`
- `Be careful`
- `Looks safe for now`

### Why

- They are short and direct.
- They avoid fake certainty.
- They still leave room for a safe handoff path.

### Open research question

You are right that some older adults dislike ambiguity. That means the real
question is not whether ambiguity should exist; it is whether the app explains
what to do next when certainty is limited.

### Recommendation

Treat these three labels as candidates, not final copy. Run copy testing with
older adults against alternatives such as:

- `Likely scam`
- `Needs checking`
- `No strong scam signs`

or

- `Scam warning`
- `Not sure yet`
- `No clear danger found`

The winner should be based on comprehension, not aesthetics.

## 3. What does “next action” mean?

It should be one short, concrete instruction tied to the result.

Examples:

- `Do not reply. Call your bank using the number on your card.`
- `Do not click the link. Delete the message if you do not know the sender.`
- `Check with your family member using a number you already trust.`
- `Paste the text instead so we can check it again.`

This matters because “why” alone is not enough in a panic moment. The user also
needs the safest immediate move.

## 4. Minimum explanation quality bar

The explanation should not describe generic model reasoning. It should tell the
user the observed trigger.

Good explanation style:

- names the signal
- avoids jargon
- stays under roughly 120 characters in the main summary
- does not claim certainty beyond the evidence

Good examples:

- `It asks for urgent payment and pretends to be your bank.`
- `This message asks for your password or code. That is a scam sign.`
- `We could not verify the sender, and the message pushes you to act fast.`

Bad examples:

- `The model predicts this is malicious.`
- `Confidence score is 0.86.`
- `The system found anomalous linguistic indicators.`

## 5. Guest checks vs forced account

### Recommendation

Do not require account creation before first check.

Suggested policy:

- guest mode for initial checks
- email-based account only when needed for history sync, premium, or recovery
- no phone-number dependency in v1 unless it becomes essential

### Why

- less friction in a panic moment
- faster first-use experience
- lower risk of abandonment before value is proven

### Cost note

Email verification is likely the cheapest acceptable account baseline, but it
should sit behind proven user value, not in front of it.

## Source Notes

- FTC impersonation guidance: https://consumer.ftc.gov/articles/how-avoid-government-impersonation-scam
- CISA phishing guidance: https://www.cisa.gov/secure-our-world/recognize-and-report-phishing
- FBI elder fraud overview: https://www.fbi.gov/news/stories/elder-fraud-in-focus
- FBI elder fraud report summary: https://www.fbi.gov/contact-us/field-offices/cincinnati/news/fbi-elder-fraud-report-highlights-frauds-and-scams-targeting-older-americans
- NIH plain language guidance: https://www.nih.gov/institutes-nih/nih-office-director/office-communications-public-liaison/clear-communication/plain-language-nih
- CDC plain language checklist: https://www.cdc.gov/health-literacy/php/develop-materials/plain-language.html
