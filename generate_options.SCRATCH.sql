if 1=2 begin
		-- mbw: Why no defined columns in the CTEs?
		--Generating Provisions data
		; WITH svh  As  (
			-- Second: Get the values from [sv_medical_service] for the identified [svh_medical_service_history] records
			--Select		A.sv_id, A.sv_nm
			Select	distinct	A.sv_id, c.PARN_SV_ID, c.SV_STRC_C, A.sv_nm
            From		[MASTER].[svh_medical_service_history]	A
            Inner Join	(	-- First, get uniquq 'A' = Active records, grouped by sv_id and get the max effective from date
							-- mbw: Make this a 1st class table in temp with the PK sv_id, sv_eff_frm_dt, kill "A."
							Select		A.sv_id, Max(A.sv_eff_frm_dt) as sv_eff_frm_dt
                            From		[MASTER].[svh_medical_service_history] A
                            Where		A.sv_stus_c	= 'A'
                            Group  By	A.sv_id
						 )										B On	A.sv_id = B.sv_id and A.sv_eff_frm_dt = B.sv_eff_frm_dt
			inner join	[MASTER].[sv_medical_service]			c on	a.SV_ID = c.SV_ID
			/* was commented out										vvv not needed vvvvvv So, clear why it was commented out since it doesn't connect ot A, B or C table...
			inner join	[MASTER].[PRS_PRODUCT_SERVICE]			d on	a.SV_ID	= b.SV_ID and d.pr_id =	Case When @PR_ID IS NOT NULL Then @PR_ID Else d.pr_id End
			*/
            Where		 A.sv_stus_c		=	'A'-- Might be redundant b/c the subquery filter for this but can't guarantee that in the data so use it...
		)
		,
		-- Recursive CTE using hierarchical traversal to get the a -> b -> c -> d, etc.
		--	Note: Structually, this can be pulled out of the CTE set into a separate entry that is used to make a table that allows field 7 to be updated b/c svh_heirarchy is used for B only 
		svh_hierarchy as (
			-- Anchor member 
			SELECT P0.sv_id, CAST(P0.SV_NM AS VarChar(Max))                            as LevelWithName, CAST(P0.SV_ID AS VarChar(Max))                          as LevelWithID --, P.PARN_SV_ID
			FROM   svh P0
			WHERE  P0.PARN_SV_ID IS NULL -- Top-level service

			UNION ALL
			-- recursive member
			SELECT P1.sv_id, CAST(P1.SV_NM AS VarChar(Max)) + ' -> ' + M.LevelWithName as LevelWithName, CAST(P1.SV_ID AS VarChar(Max)) + ' -> ' + M.LevelWithID as LevelWithID --, P1.PARN_SV_ID
			FROM		svh			  P1 
			INNER JOIN	svh_hierarchy M  ON M.sv_id = P1.PARN_SV_ID -- Find childredn	mbw: the -> seems backwards...
		)

		select * From svh_hierarchy

		select * From Master.[svh_medical_service_history] where sv_id in (2138821075, 2094436046, 2094436044, 2094436043 ) and SV_STUS_C='A'order by sv_id
		select * From Master.[sv_medical_service]          where sv_id in (2138821075, 2094436046, 2094436044, 2094436043 )                  order by sv_id

		/*
		Nursery Care -> Maternity -> Inpatient Hospital Facility Services -> Inpatient Facility Services	2138821075 -> 2094436046 -> 2094436044 -> 2094436043
		*/
end

if 1-2 begin
	-- tmgreadonly															tmgreadonly
	select count(1) from RPTeBS_enGen_UAT.Temp.PRPHOptions					-- 16832
	select count(1) from RPTeBS_enGen_UAT.Temp.FullProvisionOption			-- 6773
	select count(1) from RPTeBS_enGen_UAT.Temp.FinalProvisionOptions		-- 0

	select count(1) from RPTeBS_enGen_UAT.Temp.mbw_PRPHOptions					-- 16,832	19,261,548	
	select count(1) from RPTeBS_enGen_UAT.Temp.mbw_FullProvisionOption			--  6,773	12,830,778
	select count(1) from RPTeBS_enGen_UAT.Temp.mbw_FinalProvisionOptions		--      0	19,259,784

	select count(1) from RPTeBS_enGen_UAT.Temp.mbwNew_PRPHOptions					-- 16,832	19,944,141 b/c need to do last distinct
	select count(1) from RPTeBS_enGen_UAT.Temp.mbwNew_FullProvisionOption			--  6,773	12,830,778
	select count(1) from RPTeBS_enGen_UAT.Temp.mbwNew_FinalProvisionOptions		--      0	19,259,784
	

	select count(1) from RPTeBS_enGen_UAT.[MASTER].[prph_product_provision_history_1015]				--		19,956,008	

	select prp_stus_c, count(1) from RPTeBS_enGen_UAT.[MASTER].[prph_product_provision_history_1015] group by prp_stus_c				--		19,956,008	
	/*
	prp_stus_c	(No column name)
	A	19272592
	I	683416
	*/

	select min(PRPH_REC_ID) as 'min', max(PRPH_REC_ID) as 'max', (max(PRPH_REC_ID) - min(PRPH_REC_ID)) as 'range', count(1) as count from RPTeBS_enGen_UAT.[MASTER].[prph_product_provision_history_1015]				

	min			max			range		count
	22923315	8162078096	8139154781	19956123

	select 8139154781 / 19956123 -- 407x as many IDs ranges as are used

end



set nocount on

		declare @first			bigint
			,	@last			bigint
			,	@numRows		bigint
			,	@count			bigint
			,	@BATCH_COUNT	bigint = 100000
			,	@m				varchar(100)

		select @first = min(PRPH_REC_ID), @last = max(PRPH_REC_ID), @numRows = count(1) from RPTeBS_enGen_UAT.[MASTER].[prph_product_provision_history_1015] with(nolock)
		select @m = 'insert into Temp.mbwNew_PRPHOptions  ' + convert(varchar(20),@numRows) +' total rows, ['+convert(varchar(20),@first) + '..' + convert(varchar(20),@last) + '] by ' + convert(varchar(20),@BATCH_COUNT)
print @m
-- insert into Temp.mbwNew_PRPHOptions 19,956,217 total rows, [ 22,923,315 .. 8,162,078,096 ] by 100000
-- insert into Temp.mbwNew_PRPHOptions  19956727 total rows, [22923315..8162078096] by 100000
															  
		declare @row_a bigint = @first
			,	@row_b bigint = @first + @BATCH_COUNT - 1


		while @row_a < @last begin
			select @count = count(1) from RPTeBS_enGen_UAT.[MASTER].[prph_product_provision_history_1015] with(nolock) where PRPH_REC_ID between @row_a and @row_b
			-- Stick a timer entry in there	
			select @m = '  [' + RIGHT('           ' + FORMAT(@row_a, '#,##0'), 11) + '..' 
   							  + RIGHT('           ' + FORMAT(@row_b, '#,##0'), 11) + '] = '
							  + right('      '      + format(@count, '#,##0'),  7)
					
			print @m

			-- Move up
			select @row_a = @row_a + @BATCH_COUNT
			select @row_b = @row_b + @BATCH_COUNT
			
		end -- On looping

		select @@version




USE [RPTeBS_enGen_UAT]
go

-- Step 1: Create the temp table with IDENTITY and data
DROP TABLE #idList;

create table #idlist (
	rownum			int identity(1,1) --primary key clustered
,	[PRPH_REC_ID]	bigint 
)

insert into #idlist select PRPH_REC_ID from RPTeBS_enGen_UAT.[MASTER].[prph_product_provision_history_1015] ORDER BY PRPH_REC_ID;

-- Step 2: Add a clustered index on the rn column
CREATE CLUSTERED INDEX IX_KeyBatches_rn ON #idList(rownum);
--(19956734 rows affected)
--Completion time: 2025-06-17T15:29:11.9448756-04:00


-- Step 2: Select every 50,000th row starting from the first
declare @num		bigint = 0
declare @BATCH_SIZE	bigint = 50000
declare @lastID		bigint
declare @s			varchar(100)

declare @keepGoing	int = 1

while @keepGoing > 0 begin
	select @num = @num + @BATCH_SIZE
	select @lastID = PRPH_REC_ID from #idList where rownum = @num
	if (@@ROWCOUNT = 0) begin 
		select top 1 @num = rownum, @lastID = PRPH_REC_ID from #idList  order by rownum desc
		set @keepGoing = 0
	end
	select @s = RIGHT('              ' + FORMAT(@num, '#,##0'),11) + ' = ' +  RIGHT('              ' + FORMAT(@lastID, '#,##0'), 14)
	print @s

--	if (@num > 1000000) begin set @keepGoing = 0 end
end


--		-- THIS LOOKS WRONG
--		-- THIS LOOKS WRONG
--		-- THIS LOOKS WRONG
--		19850000 = 160,486,756
--		19900000 = 161,338,257
--		19950000 = 162,051,068
--		20000000 = 162,051,068

select * from #idList order by rownum


SELECT PRPH_REC_ID
FROM #idList
WHERE (rn - 1) % 50000 = 0
ORDER BY rn;

-- Optional: Clean up
-- DROP TABLE #idList;
