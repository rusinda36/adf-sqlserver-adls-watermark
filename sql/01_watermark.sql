USE RestartSafeETL;
GO
-- Repeatable setup. Preserve any existing checkpoint.
IF OBJECT_ID('etl.AdfWatermark', 'U') IS NULL
BEGIN
    CREATE TABLE etl.AdfWatermark
    (
        PipelineName varchar(100) NOT NULL PRIMARY KEY,
        LastLoadBatchID int NOT NULL
    );
END;
IF NOT EXISTS (SELECT 1 FROM etl.AdfWatermark WHERE PipelineName = 'retail_to_adls')
    INSERT INTO etl.AdfWatermark (PipelineName, LastLoadBatchID)
    VALUES ('retail_to_adls', 0);
GO
