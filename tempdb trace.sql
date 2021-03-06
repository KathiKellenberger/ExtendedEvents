/****************************************************/
/* Created by: SQL Server 2019 CTP3.1 Profiler          */
/* Date: 07/24/2020  12:19:15 AM         */
/****************************************************/
/*
sp_trace_setStatus 2, 0
exec sp_trace_setStatus 2,2

*/

-- Create a Queue
declare @rc int
declare @TraceID int
declare @maxfilesize bigint
set @maxfilesize = 5 

-- Please replace the text InsertFileNameHere, with an appropriate
-- filename prefixed by a path, e.g., c:\MyFolder\MyTrace. The .trc extension
-- will be appended to the filename automatically. If you are writing from
-- remote server to local drive, please use UNC path and make sure server has
-- write access to your network share

exec @rc = sp_trace_create @TraceID output, 0, N'd:\temp\tempdb_growth1', @maxfilesize, NULL 
if (@rc != 0) goto error

-- Client side File and Table cannot be scripted

-- Set the events
declare @on bit
set @on = 1
exec sp_trace_setevent @TraceID, 92, 3, @on
exec sp_trace_setevent @TraceID, 92, 11, @on
exec sp_trace_setevent @TraceID, 92, 7, @on
exec sp_trace_setevent @TraceID, 92, 8, @on
exec sp_trace_setevent @TraceID, 92, 9, @on
exec sp_trace_setevent @TraceID, 92, 10, @on
exec sp_trace_setevent @TraceID, 92, 12, @on
exec sp_trace_setevent @TraceID, 92, 13, @on
exec sp_trace_setevent @TraceID, 92, 14, @on
exec sp_trace_setevent @TraceID, 92, 15, @on
exec sp_trace_setevent @TraceID, 92, 25, @on
exec sp_trace_setevent @TraceID, 92, 26, @on
exec sp_trace_setevent @TraceID, 92, 35, @on
exec sp_trace_setevent @TraceID, 92, 36, @on
exec sp_trace_setevent @TraceID, 92, 41, @on
exec sp_trace_setevent @TraceID, 92, 51, @on
exec sp_trace_setevent @TraceID, 92, 60, @on
exec sp_trace_setevent @TraceID, 92, 64, @on
exec sp_trace_setevent @TraceID, 93, 3, @on
exec sp_trace_setevent @TraceID, 93, 11, @on
exec sp_trace_setevent @TraceID, 93, 7, @on
exec sp_trace_setevent @TraceID, 93, 8, @on
exec sp_trace_setevent @TraceID, 93, 9, @on
exec sp_trace_setevent @TraceID, 93, 10, @on
exec sp_trace_setevent @TraceID, 93, 12, @on
exec sp_trace_setevent @TraceID, 93, 13, @on
exec sp_trace_setevent @TraceID, 93, 14, @on
exec sp_trace_setevent @TraceID, 93, 15, @on
exec sp_trace_setevent @TraceID, 93, 25, @on
exec sp_trace_setevent @TraceID, 93, 26, @on
exec sp_trace_setevent @TraceID, 93, 35, @on
exec sp_trace_setevent @TraceID, 93, 36, @on
exec sp_trace_setevent @TraceID, 93, 41, @on
exec sp_trace_setevent @TraceID, 93, 51, @on
exec sp_trace_setevent @TraceID, 93, 60, @on
exec sp_trace_setevent @TraceID, 93, 64, @on


-- Set the Filters
declare @intfilter int
declare @bigintfilter bigint

set @intfilter = 2
exec sp_trace_setfilter @TraceID, 3, 0, 0, @intfilter


exec sp_trace_setstatus @TraceID, 1

-- display trace id for future references
select TraceID=@TraceID
goto finish

error: 
select ErrorCode=@rc

finish: 
go
