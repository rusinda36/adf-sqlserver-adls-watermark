# Observed lab results

Source: user-supplied ADF outputs, SQL query results, and Azure Storage screenshots on November 2, 2026 (America/Toronto).

| Scenario | Observed result |
| --- | --- |
| First copy | 10,000 rows read and copied; 1 file; 28-second Copy duration; no errors; watermark 11 |
| Second copy | 10,000 rows read and copied; 1 file; 23-second Copy duration; no errors; watermark 21 |
| Injected checkpoint failure | NewBatchID temporarily set to 21; Copy succeeded; SaveWatermark failed |
| Recovery | Original NewBatchID expression restored; SQL watermark subsequently 31; storage showed a single batches_22_31.parquet modified after the failed run |
| Empty eligible range | ReadUpperBound temporarily restricted to LoadBatchID <= 31; pipeline succeeded with only ReadWatermark, ReadUpperBound, HasNewData; no Copy or SaveWatermark execution |

First ten completed batch IDs: 1,2,3,4,5,7,8,9,10,11. Each had RowsLoaded=1000. ID 6 was absent from this result; the exact reason was not established here.

Files observed after recovery:
- batches_1_11.parquet: 318.77 KiB
- batches_12_21.parquet: 320.15 KiB
- batches_22_31.parquet: 323.11 KiB

First successful full pipeline run ID: 727c0305-6ddf-41bb-9990-b78f9043d85e.
Injected failure run ID: 08c83ff5-7f7a-44c9-989f-da6d8b342145.
Empty-range run ID: ad9359ee-26b4-4fba-a0d7-97186866f127.

## Evidence limits

The checkpoint value immediately after the injected failure was requested but not explicitly returned. Failure location, later watermark 31 and storage listing were observed. The exact SQL error text for the injected failure was not supplied. Recovery Copy row counts were not supplied. File content, row-key uniqueness across Parquet files, and byte-level equivalence before/after overwrite were not independently verified. ADF reported dataConsistencyVerification=NotVerified on the two supplied Copy outputs.

The empty-range test used a temporary ceiling of 31. The full source was not exhausted. Remaining source batches are eligible when the ceiling is removed. The final supplied pipeline JSON removed the ceiling, restored the checkpoint expression and included the ORDER BY whitespace correction; that final cleanup version was reviewed but not rerun in the conversation.
