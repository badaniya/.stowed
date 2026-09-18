# Support Cases, Knowledge Articles, TAM Queries & Jira Formats

## Support Cases & Knowledge Articles

Use `Query_Salesforce_Core` (Cases & Knowledge Articles **only** — this is the
Core endpoint; all other objects go to the SaaS endpoint).

### Case response format

Always include the **Case Number**; never include a link to the case:

- Case Number
- Status and Priority/Severity
- Product/Component
- Customer (first + last name only)
- Issue Summary (2–4 factual sentences)
- Recent Activity (last 5–10 meaningful updates)
- Recommended Next Steps (grounded in KB retrieval via the extreme-kb-research
  skill, only if the case is open)
- Relevant Knowledge Articles (when applicable; for open cases search the
  Salesforce Knowledge Article object via `Query_Salesforce_Core` — **not** the
  extreme-kb-research skill — for articles matching the case and provide
  troubleshooting guidance)

**Exclude opportunity, contract, quote, revenue, or any commercial data from
case summaries.**

Query habits: `ORDER BY LastModifiedDate DESC` to surface stale open cases. For
accounts whose cases are linked via a reseller (e.g. Kroger via Toshiba), use
`Account.Name LIKE '%<name>%' OR End_Customer__r.Name LIKE '%<name>%'` as a
fallback alongside the AccountId filter.

### Knowledge Article format

Article Number & Title, Status, Version, Last Modified, Objective, Environment,
Procedure, Additional notes — with the hyperlink
`https://extreme-networks.my.site.com/ExtrArticleDetail?an=<ArticleNumber>`.

## Technical Account Owner (TAM) case queries

Primary method — one dedup-by-Id query so Salesforce dedupes server-side;
report the returned count directly (no manual arithmetic):

```sql
SELECT Id, CaseNumber, Status, Priority, Subject, AccountId, Account.Name,
       End_Customer__c, End_Customer__r.Name, CreatedDate, LastModifiedDate
FROM Case
WHERE Id IN (SELECT Id FROM Case WHERE AccountId IN
        (SELECT Id FROM Account WHERE Technical_Account_Owner__c = '<owner>'))
   OR Id IN (SELECT Id FROM Case WHERE End_Customer__c IN
        (SELECT Id FROM Account WHERE Technical_Account_Owner__c = '<owner>'))
ORDER BY LastModifiedDate DESC
```

(The Workato tool appends its own LIMIT — do not add one.)

Add `AND IsClosed = false` to the outer `WHERE` for open-only.

**Never** use a "query Accounts first, then pass IDs" pattern — it silently
truncates. Only if the single query fails to execute, fall back to two queries
(Account-owned + End-Customer-owned), then merge explicitly:
unique total = Q1 + Q2 − overlap; validate that the final deduped list length
matches, then present. If the count hits the result cap, tell the user more may
exist and offer to refine. Present results in the standard case format above.

Field names: `End_Customer__c` / relationship `End_Customer__r`;
`Technical_Account_Owner__c` on Account.

## Jira output formats

**Single-issue format:**
- Issue Overview (key, summary, type, status, priority, reporter, assignee,
  created, updated)
- Description (2–4 sentences)
- Recent Activity (last 5–10)
- Linked Items
- Next Steps

Link as `[ISSUE-KEY](https://<domain>.atlassian.net/browse/ISSUE-KEY)`.

**Multi-issue format:** table
`Issue Key | Summary | Status | Priority | Assignee | Updated`; if >20 matches,
show top 20 by most-recently-updated and state how many more exist. Offer to
summarize any in detail.
