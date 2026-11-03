# Incremental SQL Server to ADLS Loading with Azure Data Factory
A small lab extending an existing restart-safe Online Retail II loader. Azure Data Factory reads completed SQL Server batches, writes each selected range to one Snappy Parquet file in ADLS Gen2, then advances a separate SQL checkpoint.

## Files

- `adf/pipeline/pl_retail_to_adls.json`: reviewed pipeline resource definition.
- `adf/dataset/`: the two dataset definitions supplied by the user.
- `sql/01_watermark.sql`: repeatable setup that preserves existing progress.
- `sql/02_advance_watermark.sql`: checkpoint procedure used in the lab and its execution grant.
- `sql/03_inspect.sql`: read-only queries (the final per-batch count query is provided, not session-tested).
- `evidence/results.md`: observed outcomes and evidence limits.

These are individual ADF resource definitions, not a complete ARM deployment template. Pipeline JSON is reconstructed from the supplied final export with publish metadata omitted and whitespace normalized. Dataset definitions retain the supplied schema and settings. The repeatable setup wrapper is a packaging addition; the lab initially used a plain CREATE TABLE and INSERT.

## Existing dependencies

SQL Server Express on the same Windows machine as the self-hosted runtime. Database `RestartSafeETL`; existing `etl` and `stg` schemas; existing tables `stg.RetailTransaction` and `etl.LoadBatch`, produced by the preceding loader project. This package does not recreate or load those source tables. Source rows are identified by SourceFileID, SourceSheet and SourceRowNumber. Batch boundaries use the corresponding source identifiers plus StartRowNumber and EndRowNumber.

Configure these linked services in ADF before adding datasets and pipeline:

| Name | Lab configuration |
| --- | --- |
| ls_sql_retailsource | SQL Server connector 2.0, server .\SQLEXPRESS, database RestartSafeETL, SQL authentication as adf_retail, runtime ir-local-sql |
| ls_adls_raw | ADLS Gen2 account, Account key authentication, AutoResolveIntegrationRuntime |

The lab used storage account strovishenadls003 in Canada Central, hierarchical namespace enabled, container raw. Change the storage account for your environment. Linked service definitions and credentials are intentionally not included; configure secrets directly in Azure. The SQL user needs source/checkpoint reads (the lab used db_datareader) plus EXECUTE on the one procedure. SQL encryption was Mandatory with Trust server certificate enabled for the local Express lab.

Install and register the 64-bit self-hosted integration runtime. Parquet serialization runs on that machine and needs a compatible Java runtime. The working lab discovered `C:\Program Files\Java\jdk-1.8\jre\bin\server\jvm.dll` and set system JAVA_HOME to `C:\Program Files\Java\jdk-1.8\jre`; after restarting the computer and restoring the IR connection, copying succeeded. Use your actual Java installation path. This is an observed environment detail, not an installer included in the archive.

## Flow

1. Read the SQL watermark for retail_to_adls.
2. Select the next ten Completed batches above that watermark; use their maximum ID as the upper bound. IDs need not be contiguous.
3. If upper <= lower, finish without copying.
4. Join source rows to completed batch ranges and select lower < LoadBatchID <= upper.
5. Write raw/retail/batches_{lower+1}_{upper}.parquet.
6. On Copy success, call etl.AdvanceAdfWatermark with the expected and new IDs.

The filename's first number is a lower boundary, not a guarantee that the ID exists. All activity retries are 0: the tested recovery was a manual rerun. Pipeline concurrency is 1; avoid overlapping Debug, triggered or external writers. Publish does not execute the pipeline. Use one manual run at a time.

## Reproducing the scenarios

Use an isolated destination and its own checkpoint for a fresh reproduction; do not reset an active checkpoint while retaining old files.

- First/next portions: run once, inspect the Copy output and watermark, then run again.
- Failure after copying: with checkpoint 21, temporarily set SaveWatermark.NewBatchID to @int(21) and Debug once. Copy completes, then the procedure rejects the non-increasing watermark. Inspect the unchanged checkpoint and existing range file before recovery.
- Recovery: restore @activity('ReadUpperBound').output.firstRow.UpperLoadBatchID, then rerun. For the frozen source, the same boundaries and filename are selected.
- Empty eligible range: with checkpoint 31, temporarily add AND LoadBatchID <= 31 inside the ReadUpperBound inner query. Run once: only the Lookups and condition execute. Remove this test predicate and publish the restored version afterward.

## Scope and limits

This lab reuses already completed, immutable source batches and pauses the upstream loader. It does not establish a safe watermark for concurrent upstream writers: IDs can be allocated before commit and a lower batch could become Completed later. General production ingestion would require stronger eligibility tracking or a committed, ordered source frontier.

Batch ranges must not overlap and source rows must belong to the intended batches. Existing rows are not updated or deleted in this experiment. File write and SQL checkpoint are separate operations, not one distributed transaction. A file may be visible before its checkpoint is saved, and readers can observe replacement in progress. A stable filename supports overwriting the same fixed range on manual retry; it does not prove general exactly-once delivery or atomic publication. Changing the source, batch limit, or eligibility during recovery can change the range and filename. No independent Parquet content reconciliation was performed.

See evidence/results.md before using any outcome in a publication. No full million-row Azure transfer or production readiness claim is made.
