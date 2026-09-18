<!-- RESOURCE: Full SEO/GEO/AEO/LLM optimization guidance from Digital. Read this file ONLY when the decision tree in SKILL.md says the content needs SEO/LLM optimization (i.e., it will live at or be linked from a URL). -->

# SEO & LLM Optimization for Web-Published Content

This guidance ensures marketing content performs well in search engines AND AI-powered systems (ChatGPT, Claude, RAG platforms, etc.). It works **alongside** brand standards to maximize discoverability and accuracy. It applies ONLY to content that will be published online at (or linked from) a URL — the decision tree in SKILL.md determines whether to apply it.

## Content Architecture & Header Hierarchy

**Strict Header Structure (H1 > H2 > H3 > H4)**
- **H1 (Page Title)**: One per page. Include primary keyword. Must be search-focused and scannable.
  - Example: "Zero Trust Network Architecture: Simplify Security & Compliance"
- **H2 (Main Sections)**: Break content into modular, standalone sections. Each H2 should be independently meaningful for LLM extraction and search clustering.
  - Example: "How Zero Trust Simplifies Network Access" (not just "Benefits")
- **H3+ (Subsections)**: Use for drill-down detail. Maintain logical nesting.

**Why this matters for LLMs**: Strict hierarchy helps RAG systems extract relevant sections, cite accurately, and avoid context collapse. Modular sections improve indexing and allow LLMs to pull the most relevant chunk from your content.

## Strategic Keyword Integration

**Keyword Placement & Natural Language**
- **H1**: Place primary keyword naturally at or near the start (e.g., "Cloud-Managed Networks: Benefits for Enterprise Security")
- **H2/H3**: Integrate semantic variations and related keywords (synonyms, related concepts, question formats)
- **First 40 words of each section (AEO)**: Include a definition-first answer to the section heading
- **Body text**: Prioritize user intent over keyword density. Use "AI-powered networking solutions" more than "AI networking" if it reads better and clarifies meaning for both humans and LLMs

**Example**: For a section on "Zero Trust Architecture," the opening sentence might be:
- ❌ "Zero trust architecture is a security model." (bland, doesn't help LLM understanding)
- ✓ "Zero trust network architecture is a security model that requires verification of every user and device before granting access, regardless of network location." (definition-first, context-rich for LLM extraction)

**GEO Targeting**: When content targets specific regions, explicitly note regional variations:
- "In North America, zero trust adoption is driven by compliance mandates. In Europe, GDPR and NIS2 regulations accelerate adoption."

## Technical Metadata Specifications

**Meta Title (SEO)**
- Under 60 characters (ideal: 50–55)
- Lead with primary keyword or value prop
- Include brand name only if space allows
- Example: "Cloud-Managed Networks for Enterprise Zero Trust | Extreme"

**Meta Description (AEO)**
- Under 160 characters
- Lead with value prop or direct answer to user intent
- Include a clear call-to-action (CTA)
- Example: "Simplify zero trust deployment with cloud-managed networking. Reduce complexity, accelerate adoption. Explore Extreme's solutions."

**AEO Summary (Definition-First Writing)**
- First 40–50 words of the page/section should answer "What is this?" directly
- Structured as a complete definition, not a teaser
- Used by LLMs (ChatGPT, Claude) in snippet generation and RAG retrieval

## Modular Content Sections

**Standalone Modules for RAG & Search Engines**
- Draft each H2 section as a self-contained module with:
  - **Opening definition** (answers "what" and "why")
  - **Substantive detail** (3–5 key points)
  - **Concrete example or use case** (helps LLM contextualize)
  - **Internal link** (vertical-aligned; see below)
- Content should remain coherent when extracted in isolation by LLMs or search engines

**Example Structure**:
```
## Zero Trust Network Segmentation

Zero trust network segmentation divides your network into micro-zones,
each requiring independent verification. This reduces lateral movement
of threats and limits breach blast radius.

### Key Principles
- Verify every device and user
- Enforce least privilege access
- Monitor all network traffic

### Real-World Impact
Organizations using zero trust segmentation limit breach blast
radius and contain threats faster. [Cite only verified, sourced
statistics here -- never unattributed figures.]

[Related: How to Implement Zero Trust on Your Network]
```

## Structured Data & Formatting for LLM Extraction

**Descriptive Alt-Text for Images**
- Every image gets descriptive alt-text (not just keywords)
- Include context; describe what the image shows and why it's relevant
- Example: ✓ "Dashboard showing network segmentation policies with color-coded access zones for healthcare compliance"
  vs. ✗ "network segmentation"
- Helps both accessibility and LLM image understanding (for multimodal LLMs)

**FAQ Sections (Mandatory)**
- Every page benefits from an FAQ section
- Format as "People Also Ask" style Q&A (mirrors Google SERP behavior)
- Write questions as users would ask them, not branded language
- Example questions:
  - "What's the difference between zero trust and network segmentation?"
  - "How long does zero trust implementation take?"
  - "Does zero trust work with existing network infrastructure?"

**Lists & Formatting**
- Bulleted lists: Use consistent formatting; each item should be scannable standalone
- Numbered lists: Reserve for sequential steps only
- **Bold key terms** when first introduced in a section (helps LLM keyword extraction)
- Avoid nested lists deeper than 2 levels (impairs LLM parsing)

## Natural Language Context for LLM Comprehension

**Prioritize Intent Over Keywords**
- Write for the human first; LLM comprehension follows
- Use conversational topic clusters: Instead of repeating "zero trust" 5× in a paragraph, vary: "zero trust," "trust verification," "device verification," "continuous authentication"
- This helps LLMs understand the concept more deeply vs. surface-level keyword matching

**Example Comparison**:
- ❌ "Extreme Platform ONE supports zero trust. Zero trust is important for security. Zero trust reduces risk. Our zero trust solution is cloud-managed."
- ✓ "Extreme Platform ONE supports zero trust architectures that verify every user and device before granting access. This continuous authentication model significantly reduces lateral movement risk and accelerates compliance."

**Claim Substantiation for LLM Citation**
- Every quantitative claim must include a source or context
- Format: "80% of enterprises adopted cloud-managed networks by 2025 (Gartner, 2024)"
- Inline citations help LLMs cite your content accurately instead of making up statistics
- Avoid attributing claims to generic entities ("industry experts" → specify "Gartner," "IDC," "Forrester")

## Vertical-Aligned Internal Linking

**Cross-Linking for Topic Relevance**
- Use descriptive anchor text that includes semantic keywords
- Link to adjacent H2 topics to help LLMs understand topic relationships
- Example: Instead of "Learn more," use "Discover how to implement zero trust in hybrid environments"
- This improves LLM context and search crawlability

## Channel-Specific SEO/LLM Guidance

**Web Pages, Product Pages, Blog Posts, Case Studies**
- ✅ Apply ALL SEO/LLM optimization rules above
- Header hierarchy, metadata, modular sections, alt-text, FAQ sections, internal linking all essential
- Example: Product page for Extreme Platform ONE should have H1 with primary keyword, meta title/description, FAQ section, and modular sections for features, benefits, use cases

**White Papers (Published as Web-Linked PDFs)**
- ✅ Apply ALL SEO/LLM optimization rules above (PDF lives at a URL on your website and is indexed by search engines)
- Maintain strict H2/H3 hierarchy for search and LLM extraction
- Include a "People Also Ask" FAQ section at the end
- Use definition-first writing in opening sections
- Example: White paper on "Zero Trust Architecture" should have H1 title, modular H2 sections (What is Zero Trust, How It Works, Implementation Guide), and substantiated claims

**Data Sheets (Published on Website)**
- ✅ Apply SEO/LLM optimization rules
- Use clear H2 headings for each section (Overview, Features, Benefits, Specifications, etc.)
- Include descriptive alt-text for all product/architecture diagrams
- Brief FAQ section optional but recommended
- Keep metadata under 160 characters

**Social Media Posts**
- ⚠️ Partial SEO/LLM optimization
- NO Meta titles/descriptions (not applicable to social platforms)
- NO internal linking (social platforms don't use crawlers)
- DO use semantic keywords and conversational topic clustering
- DO prioritize user intent and clarity for AI (LLM training includes social content)
- DO include alt-text for images for accessibility and multimodal LLM understanding
- Example: LinkedIn post about "Cloud-Managed Networking for SASE" should use clear language, avoid keyword stuffing, include descriptive image alt-text

**Email Campaigns**
- ❌ DO NOT apply SEO/LLM optimization
- Email is not indexed by search engines; optimization rules waste resources
- Instead follow: Brand terminology, conversational tone, clear CTA, inclusive language
- Use sentence case subject lines (per SKILL.md Quick Rules)
- Avoid excessive hierarchy; email readers don't scan the way web readers do
- Keep paragraphs short and scannable
- Example: Email subject "Simplify your zero trust implementation" (sentence case, benefit-focused, no keyword optimization needed)

**eBooks & Downloadable PDFs (Not Web-Linked)**
- ❌ DO NOT apply SEO/LLM optimization
- If distributed via email or direct download (not linked from a web page), these won't be indexed
- Instead follow: Brand terminology, professional tone, consistent hierarchy (H2/H3 for structure), substantiated claims
- Use a table of contents for scannability
- Maintain visual consistency throughout
- Example: eBook "The Future of AI Networking" should follow brand voice and include ToC, but doesn't need meta titles or FAQ sections
- **Exception**: If the eBook PDF lives at a permanent URL on your website (e.g., `/downloads/ebook-ai-networking.pdf`), apply full SEO/LLM optimization
