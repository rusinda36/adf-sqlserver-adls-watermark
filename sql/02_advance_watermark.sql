USE RestartSafeETL;
GO
CREATE OR ALTER PROCEDURE etl.AdvanceAdfWatermark
    @ExpectedBatchID int,
    @NewBatchID int
AS
BEGIN
    SET NOCOUNT ON;
    IF @NewBatchID <= @ExpectedBatchID
        THROW 50001, 'New watermark must exceed the previous value.', 1;
    UPDATE etl.AdfWatermark
    SET LastLoadBatchID = @NewBatchID
    WHERE PipelineName = 'retail_to_adls'
      AND LastLoadBatchID IN (@ExpectedBatchID, @NewBatchID);
    IF @@ROWCOUNT <> 1
        THROW 50002, 'Watermark is missing or has changed unexpectedly.', 1;
END;
GO
GRANT EXECUTE ON OBJECT::etl.AdvanceAdfWatermark TO adf_retail;
