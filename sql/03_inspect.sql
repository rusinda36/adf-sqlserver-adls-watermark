USE RestartSafeETL;
GO
SELECT * FROM etl.AdfWatermark;
SELECT TOP (10) LoadBatchID, RowsLoaded
FROM etl.LoadBatch WHERE Status = 'Completed' ORDER BY LoadBatchID;
-- Expected source row count for the ranges observed in this lab:
SELECT b.LoadBatchID, b.RowsLoaded, COUNT_BIG(*) AS MatchedRows
FROM etl.LoadBatch AS b
JOIN stg.RetailTransaction AS r
  ON r.SourceFileID = b.SourceFileID
 AND r.SourceSheet = b.SourceSheet
 AND r.SourceRowNumber BETWEEN b.StartRowNumber AND b.EndRowNumber
WHERE b.Status = 'Completed' AND b.LoadBatchID <= 31
GROUP BY b.LoadBatchID, b.RowsLoaded
ORDER BY b.LoadBatchID;
-- The last query is supplied for inspection; it was not executed in this session.
