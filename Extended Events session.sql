/*
Prep 
	Make sure tempdb is small
	Make sure ConfigurationItemsChanged XEvents is in place
*/



--Demo 1 make some changes to the server
USE master;
GO
EXEC sys.sp_configure N'show advanced options', N'1'  RECONFIGURE WITH OVERRIDE
GO
EXEC sys.sp_configure N'max server memory (MB)', N'4000'
GO
EXEC sys.sp_configure N'cost threshold for parallelism', N'5'
GO
EXEC sys.sp_configure N'max degree of parallelism', N'1'
GO
EXEC sys.sp_configure N'optimize for ad hoc workloads', N'0'
GO
RECONFIGURE WITH OVERRIDE
GO
USE AdventureWorks2019;
GO
EXEC sys.sp_configure N'show advanced options', N'0'  RECONFIGURE WITH OVERRIDE
GO
EXEC sys.sp_configure N'show advanced options', N'1'  RECONFIGURE WITH OVERRIDE
GO
EXEC sys.sp_configure N'max server memory (MB)', N'16000'
GO
EXEC sys.sp_configure N'cost threshold for parallelism', N'30'
GO
EXEC sys.sp_configure N'max degree of parallelism', N'8'
GO
EXEC sys.sp_configure N'optimize for ad hoc workloads', N'1'
GO
RECONFIGURE WITH OVERRIDE
GO
EXEC sys.sp_configure N'show advanced options', N'0'  RECONFIGURE WITH OVERRIDE
GO

--Take a look at the ConfigurationItemsChanged Session data



--Demo 2
/*
create the tempdbGrowth session and script it
BigTransactionHistory from Adam Machanic
http://dataeducation.com/thinking-big-adventure/
*/
SELECT * INTO #test FROM AdventureWorks2019.dbo.bigTransactionHistory;
SELECT * INTO #test2 FROM AdventureWorks2019.dbo.bigTransactionHistory;
SELECT * INTO #test3 FROM AdventureWorks2019.dbo.bigTransactionHistory;
DROP TABLE #test;
DROP TABLE #test2;
DROP TABLE #Test3;

USE [tempdb]
GO
DBCC SHRINKDATABASE(N'tempdb' )
GO

/*
Take a look at data collected
*/


--Demo 3
--How to figure out the tempdbGrowth trace?
--https://docs.microsoft.com/en-us/sql/relational-databases/extended-events/view-the-extended-events-equivalents-to-sql-trace-event-classes?view=sql-server-ver15

--Find trace_id
SELECT * 
FROM fn_trace_getinfo(NULL);

SELECT DISTINCT GEI.eventid, name 
FROM fn_trace_geteventinfo(2) AS GEI 
JOIN sys.trace_events TE ON te.trace_event_id = GEI.eventid;  

SELECT GEI.eventid,TE.name AS EventName, COL.name AS ColumnName
FROM fn_trace_geteventinfo(2) AS GEI 
JOIN sys.trace_events TE ON te.trace_event_id = GEI.eventid
JOIN sys.trace_columns AS COL ON COL.trace_column_id = GEI.columnid;  

--look at filters, too
SELECT GEI.eventid,TE.name AS EventName, COL.name AS ColumnName,
	F.logical_operator, 
	CASE F.comparison_operator
		WHEN 0 THEN '='
		WHEN 1 THEN '<>'
		WHEN 2 THEN '>'
		WHEN 3 THEN '<'
		WHEN 4 THEN '>='
		WHEN 5 THEN '<='
		WHEN 6 THEN 'LIKE'
		WHEN 7 THEN 'Not like'
	END AS Operator,
	F.value
FROM fn_trace_geteventinfo(2) AS GEI 
JOIN sys.trace_events TE ON te.trace_event_id = GEI.eventid
JOIN sys.trace_columns AS COL ON COL.trace_column_id = GEI.columnid
JOIN fn_trace_getfilterinfo(2) AS F ON F.columnid = Col.trace_column_id
WHERE CAST(F.Value AS VARCHAR(20)) NOT LIKE 'SQL Server Profiler%';
;  
GO  


--Find the equivalent extended events
SELECT DISTINCT
    tb.trace_event_id,
    te.name            AS 'Event Class',
    em.package_name    AS 'Package',
    em.xe_event_name   AS 'XEvent Name',
    tb.trace_column_id,
    tc.name            AS 'SQL Trace Column',
    am.xe_action_name  AS 'Extended Events action'
FROM
              sys.trace_events         te
    LEFT JOIN sys.trace_xe_event_map   em ON te.trace_event_id  = em.trace_event_id
    LEFT JOIN sys.trace_event_bindings tb ON em.trace_event_id  = tb.trace_event_id
    LEFT JOIN sys.trace_columns        tc ON tb.trace_column_id = tc.trace_column_id
    LEFT JOIN sys.trace_xe_action_map  am ON tc.trace_column_id = am.trace_column_id
WHERE tb.trace_event_id IN (92,94,93,95)
ORDER BY te.name, tc.name;


--Demo 4
--Query the ring buffer to get a count of events in the last hour
--Just use this query replacing the name and altering the minutes if desired
WITH 
RingBuffer AS (
	SELECT 
             CAST(xet.target_data AS XML) AS targetData
    FROM    sys.dm_xe_session_targets AS xet
            INNER JOIN sys.dm_xe_sessions AS xes
                ON xes.address = xet.event_session_address
        WHERE   xes.name = 'tempdbgrowth'
            AND xet.target_name = 'ring_buffer')
SELECT COUNT(*) AS CountOfEvents
FROM RingBuffer
CROSS APPLY targetData.nodes('//RingBufferTarget/event') AS nodeData(event_data)
WHERE DATEDIFF(MINUTE,nodeData.event_data.value('(@timestamp)[1]','datetime2'), SYSUTCDATETIME()) < 60;

--Use this for SQL Agent Job
DECLARE @Count INT;
WITH 
RingBuffer AS (
	SELECT 
             CAST(xet.target_data AS XML) AS targetData
    FROM    sys.dm_xe_session_targets AS xet
            INNER JOIN sys.dm_xe_sessions AS xes
                ON xes.address = xet.event_session_address
        WHERE   xes.name = 'tempdbgrowth'
            AND xet.target_name = 'ring_buffer')
SELECT @Count = COUNT(*) 
FROM RingBuffer
CROSS APPLY targetData.nodes('//RingBufferTarget/event') AS nodeData(event_data)
WHERE DATEDIFF(MINUTE,nodeData.event_data.value('(@timestamp)[1]','datetime2'), SYSUTCDATETIME()) < 60;

IF @Count > 0 BEGIN 
	RAISERROR('tempdb size changed',11,1)
END;

	
/*
Show a custom metric in SQL Monitor
And SQL Agent job
*/



/*
See if alert fired, may take a minute
*/

--Demo 5

WITH 
RingBuffer AS (
	SELECT 
             CAST(xet.target_data AS XML) AS targetData
    FROM    sys.dm_xe_session_targets AS xet
            INNER JOIN sys.dm_xe_sessions AS xes
                ON xes.address = xet.event_session_address
        WHERE   xes.name = 'tempdbgrowth'
            AND xet.target_name = 'ring_buffer')
SELECT nodeData.event_data.value('(@timestamp)[1]','datetime2') AS EventTime,
	nodeData.event_data.value('(data[@name="size_change_kb"])[1]','int') AS SizeChangeKB,
	nodeData.event_data.value('(data[@name="file_name"])[1]','sysname') AS FileName
FROM RingBuffer
CROSS APPLY targetData.nodes('//RingBufferTarget/event') AS nodeData(event_data)
WHERE DATEDIFF(MINUTE,nodeData.event_data.value('(@timestamp)[1]','datetime2'), SYSUTCDATETIME()) < 180
AND nodeData.event_data.value('(data[@name="size_change_kb"])[1]','int') < 0
;

--Demo 6 BONUS 1
--Start StoredProcedureParametersValues
USE AdventureWorks2019;
GO
DECLARE @TotalSold INT;
EXEC dbo.usp_ProductSales @ProductID = 0                 -- int
                        , @TotalSold = @TotalSold OUTPUT -- int



--Grouping

--Demo 7 BONUS 2
--Start QueryBehavior
BEGIN TRAN;

UPDATE Person.Address
SET City = 'Fornebuabc';

SELECT a.AddressID,
       a.AddressLine1,
       a.AddressLine2,
	   a.City
FROM Person.Address AS a
WHERE a.City = N'Fornebuabc'; -- nvarchar(30)

ROLLBACK TRAN;