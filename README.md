# Incremental SQL Server to ADLS Loading with Azure Data Factory

This project copies data from a local SQL Server database to Azure Data Lake Storage Gen2, a few batches at a time.

The question I wanted to test was simple: **what happens if the file reaches storage, but the pipeline fails before recording its progress?**

The source is Online Retail II data already loaded into SQL Server by my project "Restart-Safe ETL with Python and SQL Server"(https://github.com/rusinda36/restart-safe-etl).

## How it works

The pipeline keeps the last copied batch ID in a SQL table. This is its watermark: the point from which the next run continues.

Each run:

1. Reads the saved watermark.
2. Selects the next 10 completed batches.
3. Copies their rows into one Parquet file.
4. Saves the new watermark after the copy succeeds.

If there are no eligible batches, the pipeline finishes without writing a file.

The pipeline contains five activities:

- **ReadWatermark** — reads the saved batch ID.
- **ReadUpperBound** — finds the last batch to include in this run.
- **HasNewData** — checks whether there is anything to copy.
- **CopyRetailToADLS** — writes the selected rows to ADLS.
- **SaveWatermark** — records the completed range in SQL Server.

## Why the filename matters

Files are named using the selected batch boundaries:

    batches_1_11.parquet
    batches_12_21.parquet
    batches_22_31.parquet

The first file contains 10 batches. Batch ID 6 is absent, so the tenth completed batch has ID 11.

If copying succeeds but saving the watermark fails, the next run selects the same range. With the source unchanged, it writes to the same filename.

## What I tested

| Test | Result |
| --- | --- |
| First run | 10,000 rows copied into one file; watermark advanced to 11 |
| Second run | Another 10,000 rows copied; watermark advanced to 21 |
| Failure after copying | Copy succeeded; the checkpoint step deliberately failed |
| Manual rerun | The same range filename was reused; watermark subsequently reached 31 |
| No eligible batches | Pipeline succeeded without running Copy or SaveWatermark |

For the last test, I temporarily limited the source selection to batch IDs up to 31. This tested an exhausted range; other batches remained in the source.

The first two Copy activities took 28 and 23 seconds. These are lab observations, not performance benchmarks.

## Repository contents

| Path | Purpose |
| --- | --- |
| `adf/pipeline/` | Pipeline JSON |
| `adf/dataset/` | SQL Server and Parquet dataset definitions |
| `sql/01_watermark.sql` | Creates the watermark table and initial checkpoint |
| `sql/02_advance_watermark.sql` | Creates the procedure that advances the checkpoint |
| `sql/03_inspect.sql` | Queries for inspecting batches and progress |
| `evidence/results.md` | Test results and verification details |

## Setup

You need:

- SQL Server with the existing `RestartSafeETL` database.
- Source table `stg.RetailTransaction` and batch log `etl.LoadBatch`.
- Azure Data Factory and an ADLS Gen2 storage account.
- A self-hosted Integration Runtime with access to SQL Server.
- A compatible Java runtime on that machine for writing Parquet files.

Create two linked services in ADF:

| Linked service | Connection |
| --- | --- |
| `ls_sql_retailsource` | SQL Server through the self-hosted runtime |
| `ls_adls_raw` | ADLS Gen2 storage account |

Configure credentials in those connections. Then run SQL scripts 01 and 02, add the datasets and pipeline, and set the destination container and folder. This lab used `raw/retail`.

The JSON files describe individual ADF resources. Connections and source tables must already exist.

## What this approach assumes

I kept the source unchanged during testing and ran one pipeline at a time. Automatic activity retries were disabled; recovery was tested with a manual rerun.

Writing a file and saving a SQL watermark are separate operations. A file can exist before the pipeline records its progress.

Reusing a filename helps recover a fixed batch range, but it does not make both operations atomic. A live source with batches completing out of order would need additional tracking to avoid missing a late batch.

This experiment covers copying existing batches. Updates, deletes, and independent verification of the Parquet contents are outside its scope.
