# Pricing & EOS/EOSL — Snowflake `price_list` Reference

**All** pricing and EOS/EOSL questions route to Snowflake `sales-sql-executor`
against `edna.cons_common_dimension.price_list`, regardless of how the user
phrases it and whether they mention Snowflake. Never source pricing or lifecycle
dates from a knowledge base or Salesforce. Never estimate, convert, or
extrapolate. All prices are USD.

Column names contain spaces — wrap in double quotes. Key columns:
`"Marketing Part Number"`, `"Price List Name"`, `"Base Price"`,
`"Long Description"`, `"Product Line"`, `"Item Status"`, `"Effective From"`,
`"Effective To"`, `"End Of Sale Date"`, `"End Of Service Date"`,
`"Source System Code"` (always `'ORACLE_FUSION'`).

**Abbreviation glossary:** `EP1` → search `"Long Description"` for
`Extreme Platform ONE`. Never search for the literal string `EP1`.

## Pricing queries

Always include both filters:

```sql
"Source System Code" = 'ORACLE_FUSION'
AND "Effective From" <= CURRENT_DATE
AND ("Effective To" IS NULL OR "Effective To" >= CURRENT_DATE)
```

Specific SKU:

```sql
SELECT "Marketing Part Number","Price List Name","Base Price",
       "Effective From","Effective To"
FROM edna.cons_common_dimension.price_list
WHERE "Source System Code" = 'ORACLE_FUSION'
  AND "Marketing Part Number" = '<sku>'
  AND "Effective From" <= CURRENT_DATE
  AND ("Effective To" IS NULL OR "Effective To" >= CURRENT_DATE)
ORDER BY "Price List Name"
```

Add `AND "Price List Name" = '<name>'` for a specific geography, or switch to
`"Marketing Part Number" LIKE '%<partial>%'` (with `LIMIT 50`) for fuzzy
search. (LIMIT is fine here — this is Snowflake, not the Workato SOQL tool.)

### EP1 / subscription pricing

Add two more filters and identify the product by description:

```sql
SELECT "Marketing Part Number","Long Description","Price List Name","Base Price",
       "Effective From","Effective To"
FROM edna.cons_common_dimension.price_list
WHERE "Source System Code" = 'ORACLE_FUSION'
  AND "Product Line" = 'Subscription'
  AND "Item Status" IN ('BegShipSVC','BgShipSVC','Open Books SVC','OpBooksSVC')
  AND "Long Description" LIKE '%Extreme Platform ONE%'
  AND "Long Description" LIKE '%Tier <X>%'        -- omit this line for "all tiers"
  AND "Effective From" <= CURRENT_DATE
  AND ("Effective To" IS NULL OR "Effective To" >= CURRENT_DATE)
ORDER BY "Price List Name"
```

Present subscription results with the Long Description column:
`Long Description | Marketing Part Number | Price List Name | Base Price (USD)`.

### Presentation

If no geography is specified, return every Price List Name that has a price;
omit lists with no price. Standard table:
`Marketing Part Number | Price List Name | Base Price (USD)`. Show
Effective From/To only if the user asks for validity dates or multiple price
periods are returned. Never collapse multiple rows.

If nothing returns: *"No active pricing found for [product] in the Oracle
Fusion price list. Please verify the product name or tier identifier."*

## EOS / EOSL queries

Same table, `"Source System Code" = 'ORACLE_FUSION'`, but **do not** apply the
active-price date filter (discontinued products would be hidden). Use
`SELECT DISTINCT` to dedupe across geographies.

```sql
SELECT DISTINCT "Marketing Part Number","Long Description",
       "End Of Sale Date","End Of Service Date"
FROM edna.cons_common_dimension.price_list
WHERE "Source System Code" = 'ORACLE_FUSION'
  AND "Marketing Part Number" = '<sku>'
```

For families, use `"Long Description" LIKE '%Extreme Platform ONE%'` (EP1) or
`"Marketing Part Number" LIKE '%<partial>%'`, ordered by
`"End Of Sale Date" DESC NULLS LAST`. For a window, e.g. next 12 months:
`"End Of Sale Date" BETWEEN CURRENT_DATE AND DATEADD(month, 12, CURRENT_DATE)`.

Present as: `Marketing Part Number | Long Description | End Of Sale Date |
End Of Service Date`. Show NULL dates as "Not announced" / "TBD". Add a short
note: **End Of Sale** = no longer available for purchase; **End Of Service** =
no more support/maintenance. Note full EOL when both dates are past.

No results: *"No End of Sale or End of Service information found for [product]
in the Oracle Fusion price list."*

## Replacement SKU lookup

When a product is already EOS or has an announced (future) EOS date, run a
**separate** Salesforce lookup (SaaS tool, `Query_Salesforce_Saas`) **after**
the Snowflake query:

```sql
SELECT Id, Name, ProductCode, Replacement_SKU__c
FROM Product2 WHERE ProductCode = '<marketing_part_number>'
```

Fuzzy fallback: `ProductCode LIKE '%<mpn>%'`. (Remember: no LIMIT clause via
the Workato tool — it appends its own.)

If `Replacement_SKU__c` is populated, suggest it ("Recommended replacement:
<SKU>"). If empty or no match, say none is on file. **Never** infer a
replacement from description or general knowledge. Add a "Recommended
Replacement" column when one is found ("None on file" otherwise). Don't price
the replacement or create records unless asked.
