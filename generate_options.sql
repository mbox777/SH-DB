USE [RPTeBS_enGen_UAT]
--GO
--USE [RPTeBS_enGen_SHC_DEV]
--GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- Create temp table to store step timings
IF OBJECT_ID('tempdb..#mbwTime') IS NOT NULL DROP TABLE #mbwTime;
CREATE TABLE #mbwTime (
    StepNumber		INT IDENTITY(1,1),
    StepName		NVARCHAR(100),
    StepStartTime	DATETIME2 DEFAULT SYSDATETIME(),
	StepDurationMs	int,
	TotalTimeMs		int
);

/**************************************************************************************************
Name
		[Temp].[Getproductprovisionlines]
Purpose
	 To fetch Provision data for given Product or Service ID or service provision
	
Assumption
	data exists in the provision master table for given input parameters

Params
	See below for defn
	
History
	2019-10-16	Sunil K Created
	2019-12-08  Sunil K Added Period Increment value in the select column list
	
Test Run : 
exec [Temp].[Getproductprovisionlines] null,'Out-of-Pocket Excludes Copayments'

**************************************************************************************************/
-- ALTER PROCEDURE [Temp].[Getproductprovisionlines] 
declare
@PR_ID					Bigint			=	NULL,
@SERVICE_PROVISION		Varchar (500)	=	NULL,
@sv_id					bigint			=	NULL,
@ProductType            Varchar (500)   =   NULL
--As
--Begin

	-- SET NOCOUNT ON added to prevent extra result sets From
	-- interfering with Select statements.
	SET NOCOUNT ON;
	-- This XACT_ABORT ON setting will rollback entire transaction if there is any single error & stop further processing of the SP
	SET XACT_ABORT ON;

-- debugging
set nocount off
	
	--Try block added for error handling if any
	BEGIN TRY 

		if 1=2 begin
			-- mbw: Why is this drop and recreate without any indexes or table structure?  Just truncate the tables that exist with indexes, types
			-- Clear all the temp tables that we need will dump things into  
			if object_id('Temp.mbw_PRPHOptions')				is not null begin drop table Temp.mbw_PRPHOptions			end		-- Select * From Temp.mbwNew_PRPHOptions
			if object_id('Temp.mbw_FullProvisionOption')		is not null begin drop table Temp.mbw_FullProvisionOption	end
			if object_id('Temp.mbw_FinalProvisionOptions')		is not null begin drop table Temp.mbw_FinalProvisionOptions	end
		end else begin
			if object_id('Temp.mbwNew_PRPHOptions')				is not null begin truncate table Temp.mbwNew_PRPHOptions			;select 'truncated table 1' end 
			if object_id('Temp.mbwNew_FullProvisionOption')		is not null begin truncate table Temp.mbwNew_FullProvisionOption	;select 'truncated table 2' end
			if object_id('Temp.mbwNew_FinalProvisionOptions')	is not null begin truncate table Temp.mbwNew_FinalProvisionOptions	;select 'truncated table 3' end
			
			if object_id('Temp.mbwNew_PRPHOptions')				is     null begin RAISERROR('must create table 1.', 16, 1); end 
--			if object_id('Temp.mbwNew_FullProvisionOption')		is     null begin RAISERROR('must create table 2.', 16, 1); end 
--			if object_id('Temp.mbwNew_FinalProvisionOptions')	is     null begin RAISERROR('must create table 3.', 16, 1); end 
		end


-- Showing equivalence
--		--Generating Provisions data
--		; WITH svh  As  (
--			-- Second: Get the values from [sv_medical_service] for the identified [svh_medical_service_history] records
--			Select	distinct	A.sv_id, c.PARN_SV_ID, c.SV_STRC_C, A.sv_nm
--			From		[MASTER].[svh_medical_service_history]	A
--			Inner Join	(	-- First, get unique 'A' = Active records, grouped by sv_id and get the max effective from date
--							Select		A.sv_id, Max(A.sv_eff_frm_dt) as sv_eff_frm_dt
--							From		[MASTER].[svh_medical_service_history] A
--							Where		A.sv_stus_c	= 'A'
--							Group  By	A.sv_id
--							)										B On	A.sv_id = B.sv_id and A.sv_eff_frm_dt = B.sv_eff_frm_dt
--			inner join	[MASTER].[sv_medical_service]			c on	a.SV_ID = c.SV_ID
--			/* was commented out										vvv not needed vvvvvv So, clear why it was commented out since it doesn't connect ot A, B or C table...
--			inner join	[MASTER].[PRS_PRODUCT_SERVICE]			d on	a.SV_ID	= b.SV_ID and d.pr_id =	Case When @PR_ID IS NOT NULL Then @PR_ID Else d.pr_id End
--			*/
--			Where		 A.sv_stus_c		=	'A'-- Might be redundant b/c the subquery filter for this but can't guarantee that in the data so use it...
--		)
--		,
--		-- Recursive CTE using hierarchical traversal to get the a -> b -> c -> d, etc.
--		--	Note: Structually, this can be pulled out of the CTE set into a separate entry that is used to make a table that allows field 7 to be updated b/c svh_heirarchy is used for B only 
--		svh_hierarchy as (
--			-- Anchor member 
--			SELECT P0.sv_id, CAST(P0.SV_NM AS VarChar(Max))                            as LevelWithName, CAST(P0.SV_ID AS VarChar(Max))                          as LevelWithID --, P.PARN_SV_ID
--			FROM   svh P0
--			WHERE  P0.PARN_SV_ID IS NULL -- Top-level servicefs
--
--			UNION ALL
--			-- recursive member
--			SELECT P1.sv_id, CAST(P1.SV_NM AS VarChar(Max)) + ' -> ' + M.LevelWithName as LevelWithName, CAST(P1.SV_ID AS VarChar(Max)) + ' -> ' + M.LevelWithID as LevelWithID --, P1.PARN_SV_ID
--			FROM		svh			  P1 
--			INNER JOIN	svh_hierarchy M  ON M.sv_id = P1.PARN_SV_ID -- Find childredn	mbw: the -> seems backwards...
--		)
--select 'orig',* from svh_hierarchy

		-- Generate the svn_hierarchy = e.g., 
		--	sv_id		LevelWithName																								LevelWithID
		--	----------	----------------------------------------------------------------------------------------------------------	----------------------------------------------------
		--	2094436048	Skilled Nursing Facility (Public & Private) -> Inpatient Facility Services									2094436048 -> 2094436043
		--	2094436049	Inpatient Mental Health and Substance Abuse Services -> Inpatient Facility Services							2094436049 -> 2094436043
		--	2094436045	Inpatient Rehabilitation Therapy -> Inpatient Hospital Facility Services -> Inpatient Facility Services		2094436045 -> 2094436044 -> 2094436043
		--	2094436046	Maternity -> Inpatient Hospital Facility Services -> Inpatient Facility Services							2094436046 -> 2094436044 -> 2094436043
		--	2138821075	Nursery Care -> Maternity -> Inpatient Hospital Facility Services -> Inpatient Facility Services			2138821075 -> 2094436046 -> 2094436044 -> 2094436043

insert into #mbwTime (StepName) VALUES ('svh_heirarchy CTE');
		--Generating Provisions data
		;with 
		-- First, get unique 'A' = Active records from the history, grouped by sv_id and get the max effective from date
		latest_active ( sv_id,     sv_eff_frm_dt  ) as (
			Select		sv_id, Max(sv_eff_frm_dt)
			From		[MASTER].[svh_medical_service_history]
			Where		sv_stus_c	= 'A'
			Group  By	sv_id
		)
		--select * From latest_active
		, -- Second: Get the values from [sv_medical_service] for the identified [svh_medical_service_history] records
		svh (                 sv_id,   PARN_SV_ID,   SV_STRC_C,   sv_nm ) as (
			Select distinct	A.sv_id, c.PARN_SV_ID, c.SV_STRC_C, A.sv_nm
            From		[MASTER].[svh_medical_service_history]	A
            Inner Join	latest_active							B On	A.sv_id = B.sv_id and A.sv_eff_frm_dt = B.sv_eff_frm_dt
			inner join	[MASTER].[sv_medical_service]			c on	a.SV_ID = c.SV_ID
			/* Add back in if @PR_ID is used
			inner join	[MASTER].[PRS_PRODUCT_SERVICE]			d on	a.SV_ID	= d.SV_ID and d.pr_id = @PR_ID  -- Make "and (@PR_ID is null or d.pr_id = @PR_ID)" to leave it in always
			*/
            Where 1=1 
			and A.sv_stus_c	= 'A'-- Might be redundant b/c the subquery filter for this but can't guarantee that in the data so use it...
		)
		,
		-- Recursive CTE using hierarchical traversal to get the a -> b -> c -> d, etc.
		--	Note: Structually, this can be pulled out of the CTE set into a separate entry that is used to make a table that allows field 7 to be updated b/c svh_heirarchy is used for B only 
		svh_hierarchy as (
			-- Anchor member 
			SELECT P0.sv_id, CAST(P0.SV_NM AS VarChar(Max))                            as LevelWithName, CAST(P0.SV_ID AS VarChar(Max))                          as LevelWithID --, P.PARN_SV_ID
			FROM   svh P0
			WHERE  P0.PARN_SV_ID IS NULL -- Top-level service

			UNION ALL -- recursive member
			SELECT P1.sv_id, CAST(P1.SV_NM AS VarChar(Max)) + ' -> ' + M.LevelWithName as LevelWithName, CAST(P1.SV_ID AS VarChar(Max)) + ' -> ' + M.LevelWithID as LevelWithID --, P1.PARN_SV_ID
			FROM		svh			  P1 
			INNER JOIN	svh_hierarchy M  ON M.sv_id = P1.PARN_SV_ID -- Find childredn	mbw: the -> seems backwards, but hey...
		)
select 'new, to move below and use later',count(1) as 'count' from svh_hierarchy


		-- Note: This big table is the final answer, except for needing to add "options" which is done using...
		--							1      2              3                  4               5
		--			select DISTINCT pr_id, APL_TO_PRP_ID, service_provision, prp_eff_frm_dt, prp_eff_to_dt,   plus the dbo.StringConcat on TextOption generated here
		--		 ... so find out if there are multiple TextOption for a given combo of thoes 


		declare @first			bigint
			,	@last			bigint
			,	@numRows		bigint
			,	@BATCH_COUNT	bigint = 100000
			,	@m				varchar(100)

		select @first = min(PRPH_REC_ID), @last = max(PRPH_REC_ID), @numRows = count(1) from RPTeBS_enGen_UAT.[MASTER].[prph_product_provision_history_1015]
		select @m = 'insert into Temp.mbwNew_PRPHOptions' + convert(varchar(20),@numRows) +' total rows, ['+convert(varchar(20),@first) + '..' + convert(varchar(20),@last) + '] by ' + convert(varchar(20),@BATCH_COUNT)
insert into #mbwTime (StepName) VALUES (@m);
print @m




		-- Step 1: Create the temp table with IDENTITY and data
		if object_id('tempdb..idList')				is not null begin drop table #idList end			-- Select * From #idList			
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

		-- This is the range to use
		declare @row_a bigint = 0
		declare @row_b bigint = 0

		while @keepGoing > 0 begin
			select @num = @num + @BATCH_SIZE
			select @lastID = PRPH_REC_ID from #idList where rownum = @num
			if (@@ROWCOUNT = 0) begin 
				select top 1 @num = rownum, @lastID = PRPH_REC_ID from #idList  order by rownum desc
				set @keepGoing = 0
			end
			select @s = RIGHT('              ' + FORMAT(@num, '#,##0'),11) + ' = '  +  RIGHT('              ' + FORMAT(@row_a, '#,##0'), 14)
																		   + ' .. ' +  RIGHT('              ' + FORMAT(@row_b, '#,##0'), 14)
			print @s

			set @row_a = @row_b + 1
			set @row_b = @lastID

insert into #mbwTime (StepName) values (@s)

---- Early terminate to check 		
--if (@row_a >  5001472357) begin
--	set @keepGoing = 0
--end

			-- Just see how many records there are from the inner joins
			insert into Temp.mbwNew_PRPHOptions
			-- Specify the "A" and "c" table entries
			(			
				/*  0    */		/*A */PRPH_REC_ID,
				/*  1	  */	/*A.*/pr_id,															-- 1 of 5/6		A
				/*  2	1 */	/*c3 .COPTT_DESC_T					as */TemplateType,
				/*  4  10 */	/*A.*/apl_to_prp_ord_n,
				/*  5	8 */	/*A.*/apl_to_prp_id,													-- 2 of 5/6		A
				/*  6	9 */	/*A.*/prp_id,
				/* 10	  */	/*A.*/sv_id,
				/* 11	  */	/*A.*/prp_stus_c,
				/* 12	7 */	/*A  .prp_eff_frm_dt				As */prp_eff_frm_dt,				-- 4 of 5/6		A
				/* 13	  */	/*A  .prp_eff_to_dt					As */prp_eff_to_dt,					-- 5 of 5/6		A
				/* 18	  */	/*convert(varchar(50),A.prp_vlu)	AS */prp_vlu,
				/* 19	  */	/*A.*/mnm_prp_vlu,
				/* 20	  */	/*A.*/max_prp_vlu,
				/* 21	  */	/*A.*/prp_prd_vincrm_vlu,
				/* 23	  */	/*A.*/prp_vlu_t_set_id,
				/* 30	  */	/*A  .prp_prd_vlu					As */[Period Number(PRP_PRD_VLU)],
				/* 32	  */	/*A  .p_prp_vlu_t_set_id			As */[Period TextSet],
				/* 33	  */	/*A  .mnm_prp_prd_vlu				As */[Period Min],
				/* 34	  */	/*A  .max_prp_prd_vlu				As */[Period Max],
				/* 35	  */	/*A  .PRP_VLU_INCRM_VLU				AS */[Period Increment Value],
				/* 36	  */	/*A.*/deps_on_prp_id,
				/* 37	  */	/*A.*/deps_on_prp_ord_n,
				/* 38	  */	/*A.*/prp_inter_dep_prp_id,
				/* 39	3 */	/*A.*/prp_lim_for_prp_id,
				/* 40	  */	/*A.*/prph_prsn_ord_n
				-- Extra fields from "A" that need to be saved to run the Master.GetProvisionTextOptions func later
				/* 42     */ ,	/*A.prp_vlu							as */[prp_vlu_InOrigDecimal]
				-- Extra int fields from "A" that are used in the left join replacements
				/* 43     */ ,	/*A.*/bnt_id
				/* 44     */ ,	/*A.*/PRP_TYP_C			
				/* 45     */ ,	/*A.*/prp_typ_qlfr_c		
				/* 46     */ ,	/*A.*/prp_lin_typ_c		
				/* 47     */ ,	/*A.*/prp_stdz_lvl_c		
				/* 48     */ ,	/*A.*/prp_vlu_clmn_c		
				/* 49     */ ,	/*A.*/prp_vlu_typ_c		
				/* 50     */ ,	/*A.*/p_prp_vlu_t_id		
				/* 51     */ ,	/*A.*/apl_to_prp_rel_c	
				/* 52     */ ,	/*A.*/deps_on_prp_rel_c	
				/* 53     */ ,	/*A.*/prp_vlu_t_id		
				/* 54     */ ,	/*A.*/prp_vlu_uom_c		
				/* 55     */ ,	/*A.*/prp_prd_vlu_clmn_c	
				/* 56     */ ,	/*A.*/prp_prd_vlu_uom_c	

			)
			Select Distinct		-- mbw: crazy computionally to do the sort this way  ?? Are there sort orders on any of the lookup tables?  Could select the fields in sorted order from lookups and index this table by those ints for sort field 1,2
				/* fld srt*/
				/*  0    */		A  .PRPH_REC_ID, -- PK Clustered
				/*  1	  */	A  .pr_id,															-- 1 of 5/6		A
				/*  2	1 */	c3 .COPTT_DESC_T				as TemplateType,
	--			/*  3	2 */	c2 .COPTC_DESC_T				as ProductType,
	--								-- << Here is where "options" as a filtered version of TextOption will go
				/*  4  10 */	A  .apl_to_prp_ord_n,
				/*  5	8 */	A  .apl_to_prp_id,													-- 2 of 5/6		A
				/*  6	9 */	A  .prp_id,
	--			/*  7	4 */	Ltrim(Rtrim(B.LevelWithName))	AS [Service Name],
	--			/*  8	5 */	Ltrim(Rtrim(B1.bnt_nm))			as [Network Name],									
	--			/*  9	6 */	Ltrim(Rtrim(B2.copptc_desc_t))	As SERVICE_PROVISION,				-- 3 of 5/6		B2	(is left joined)
				/* 10	  */	A  .sv_id,
				/* 11	  */	A  .prp_stus_c,
				/* 12	7 */	A  .prp_eff_frm_dt				As prp_eff_frm_dt,					-- 4 of 5/6		A
				/* 13	  */	A  .prp_eff_to_dt				As prp_eff_to_dt,					-- 5 of 5/6		A
	--			/* 14	  */	B3 .copptq_desc_t				As Qualifier,
	--			/* 15	  */	B4 .coplt_desc_t				As LineType,
	--			/* 16	  */	B7 .copvt_desc_t				As [Value Relativity(COPVT)],
	--			/* 17	  */	B12.copvu_desc_t				As [Value Unit(COPVU)],
				/* 18	  */	convert(varchar(50),A.prp_vlu)	AS prp_vlu,
				/* 19	  */	A  .mnm_prp_vlu,
				/* 20	  */	A  .max_prp_vlu,
				/* 21	  */	A  .prp_prd_vincrm_vlu,
	--			/* 22	  */	B11.prptv_nm					As [TextValue (PRPTV)],
				/* 23	  */	A  .prp_vlu_t_set_id,
	--			/* 24	  */	B9 .coppr_desc_t				AS [Applies To (COPPR)],
	--			/* 25	  */	B10.coppr_desc_t				AS [Depends On (COPPR)],
	--			/* 26	  */	B5 .cobsl_desc_t				As [Standardization level (COBSL)],
	--			/* 27	  */	B6 .copvc_desc_t				As [Value Type(COPVC)] ,
	--			/* 28	  */	B13.coppvc_desc_t				As [Period Type(COPPVC)],
	--			/* 29	  */	B14.coppvu_desc_t				As [Period Unit(COPPVU)],
				/* 30	  */	A  .prp_prd_vlu					As [Period Number(PRP_PRD_VLU)],
	--			/* 31	  */	B8 .prpptv_nm					As [Period TextValue(PRPPTV)],
				/* 32	  */	A  .p_prp_vlu_t_set_id			As [Period TextSet],
				/* 33	  */	A  .mnm_prp_prd_vlu				As [Period Min],
				/* 34	  */	A  .max_prp_prd_vlu				As [Period Max],
				/* 35	  */	A  .PRP_VLU_INCRM_VLU			AS [Period Increment Value],
				/* 36	  */	A  .deps_on_prp_id,
				/* 37	  */	A  .deps_on_prp_ord_n,
				/* 38	  */	A  .prp_inter_dep_prp_id,
				/* 39	3 */	A  .prp_lim_for_prp_id,
				/* 40	  */	A  .prph_prsn_ord_n,
	--							-- mbw: Take the calculation out of the distinct.  This func should be deterministic on the inputs, and shouldn't need to be synced
	--							--		TODO: Figure whether pulling it out can work, since not all fields are in the table, and the TextOption fields is in the distinct 41 field...
	--							--		TODO: Decide whether to do this here or if it's pulled out here, or to do this below in a 7 field new table fixing the 6 field CTE
	--							--				dbo.StringConcat(ISNULL(TextOption,''),'','','','','','','','','','','','','','','','','','','','','','','','',APL_TO_PRP_ORD_N)  as options
	--							Master.GetProvisionTextOptions	(	
	--								/* Tbl it is from, or 1015 if not in this resultset */
	--								/* b4   */	coplt_desc_t,			-- As LineType
	--								/* b2   */	copptc_desc_t,			-- As SERVICE_PROVISION		
	--								/* b3   */	copptq_desc_t,			-- As Qualifier
	--								/* 1015 */	prp_vlu_clmn_c,			--									1015 field NOT in results so need to add to table
	--								/* in   */	prp_vlu,				--									1015 field     in the results, but func needs float not char
	--								/* b12  */	copvu_desc_t,			-- As [Value Unit(COPVU)]
	--								/* in   */	mnm_prp_vlu,			--									1015 field
	--								/* in   */	max_prp_vlu,			-fs-									1015 field
	--								/* b11  */	prptv_nm,				-- As [TextValue (PRPTV)]
	--								/* in   */	prp_vlu_incrm_vlu,		-- as [Period Increment Value]		1015 field 
	--								/* 1015 */	prp_prd_vlu_clmn_c,		--									1015 field NOT in results so need to add to table
	--								/* in   */	prp_prd_vlu,			-- as [Period Number(PRP_PRD_VLU)]	1015 field
	--								/* b14  */	coppvu_desc_t,			-- As [Period Unit(COPPVU)]
	--								/* in   */	mnm_prp_prd_vlu,		-- as [Period Min] name				1015 field
	--								/* in   */	max_prp_prd_vlu,		-- as [Period Max] name				1015 field
	--								/* b8   */	prpptv_nm,				-- As [Period TextValue(PRPPTV)]
	--								/* b9   */	B9.coppr_desc_t,		-- AS [Applies To (COPPR)],
	--								/* b10  */	B10.coppr_desc_t ,		-- AS [Depends On (COPPR)],
	--								/* in   */	prp_prd_vincrm_vlu,
	--								/*      */	1,
	--								/*      */	1,
	--								/* in   */	a.p_prp_vlu_t_set_id	-- This 1015 field is in the results (as [Period TextSet] name)
	--			/* 41     */	)								as TextOption						-- 6 of 5/6

				-- Extra fields from "A" that need to be saved to run the Master.GetProvisionTextOptions func later
				/* 42     */ 	A.prp_vlu						as [prp_vlu_InOrigDecimal]

				-- Extra int fields from "A" that are used in the left join replacements
				/* 43     */ ,	A.bnt_id
				/* 44     */ ,	A.PRP_TYP_C			
				/* 45     */ ,	A.prp_typ_qlfr_c		
				/* 46     */ ,	A.prp_lin_typ_c		
				/* 47     */ ,	A.prp_stdz_lvl_c		
				/* 48     */ ,	A.prp_vlu_clmn_c		
				/* 49     */ ,	A.prp_vlu_typ_c		
				/* 50     */ ,	A.p_prp_vlu_t_id		
				/* 51     */ ,	A.apl_to_prp_rel_c	
				/* 52     */ ,	A.deps_on_prp_rel_c	
				/* 53     */ ,	A.prp_vlu_t_id		
				/* 54     */ ,	A.prp_vlu_uom_c		
				/* 55     */ ,	A.prp_prd_vlu_clmn_c	
				/* 56     */ ,	A.prp_prd_vlu_uom_c	
			


						-- mbw: On all the straight lookups, just do individual bulk inserts on the values
			From		[MASTER].[prph_product_provision_history_1015]					A
			Inner Join	[MASTER].[pr_product]											c	On a.pr_id				=	c.pr_id
			Inner Join	[MASTER].[prh_product_history]									D	On a.pr_id				=	d.pr_id					And d.pr_stus_c						=	'A'
			inner join	[MASTER].[COPTT]												c3	on d.PR_TMPLT_TYP_C		=	c3.COPTT_C				and c3.COPTT_STUS_C					=	'A' 


			-- Add the limitation on the rows
			where A.PRPH_REC_ID between @row_a and @row_b

			order by PRPH_REC_ID -- The PK on both tables
			/* If want to use @sv_id param add the where here... on A.SV_ID 

				-- mbw: there's no reason to join these here... not used in further joins, unless there is a need to check for @PR_ID, @SERVICE_PROVISION or @PRODUCTtYPE which are not in play
				--		AND: even worse, these 2 tables together are cross-joined 
				--			 (c2 was in the "and" that is commented out...)
				--	SO...they are gonna create incorrect data in the Temp.PRPHOptions table!!!
				Left Join	[MASTER].[copt_producttype]										e	On c.pr_typ_c			=	e.copt_c				And e.copt_stus_c					=	'A'
				left join	[MASTER].[COPTC_PRODUCT_TYPE_CATEGORIZATION]					c2	on c2.COPTC_C			=	e.COPT_PR_AFL_TYP_C		and c2.COPTC_STUS_C					=	'A'
			*/



			-- Now update with bulk updates what was originally in the crazy big distinct join with all 40+ fields and the crazy left-joins all over
			-- Now update with bulk updates what was originally in the crazy big distinct join with all 40+ fields and the crazy left-joins all over

		  --Left Join	svh_hierarchy													B	On A.sv_id				=	B.sv_id					    
			-- svh_hierarchy was first, but we'll do that at the bottom

		  --Left Join	[MASTER].[bnt_benefit_tier]								 B1	On A.bnt_id				=	B1.bnt_id				And B1.bnt_stus_c					=	'A'
		  --Left Join	[MASTER].[copptc_product_provision_type]				 B2	On A.prp_typ_c			=	B2.copptc_c				And Ltrim(Rtrim(B2.copptc_stus_c))	=	'A'
		  --Left Join	[MASTER].[copptq_product_provision_type_qualifier]		 B3	On A.prp_typ_qlfr_c		=	B3.copptq_c				And B3.copptq_stus_c				=	'A'
		  --Left Join	[MASTER].[coplt_product_provision_line_type]			 B4	On A.prp_lin_typ_c		=	B4.coplt_c				And B4.coplt_stus_c					=	'A'
		  --Left Join	[MASTER].[cobsl_product_provision_standardization_level] B5	On A.prp_stdz_lvl_c		=	B5.cobsl_c				And B5.cobsl_stus_c					=	'A'
		  --Left Join	[MASTER].[copvc_product_value_type]						 B6	On A.prp_vlu_clmn_c		=	B6.copvc_c				And B6.copvc_stus_c					=	'A'
		  --Left Join	[MASTER].[copvt_product_provision_value_relativity]		 B7	On A.prp_vlu_typ_c		=	B7.copvt_c				And B7.copvt_stus_c					=	'A'
		  --Left Join	[MASTER].[prpptv_product_provision_period_text_value]	 B8	On A.p_prp_vlu_t_set_id	=	B8.p_prp_vlu_t_set_id	And 
		  --																		   A.p_prp_vlu_t_id		=	B8.p_prp_vlu_t_id		And	B8.prpptv_stus_c				=	'A'
insert into #mbwTime (StepName) VALUES ('B1');
	--		update a SET [Network Name]					 = LTRIM(RTRIM(B1.bnt_nm))			from Temp.mbwNew_PRPHOptions a inner join [MASTER].[bnt_benefit_tier]								B1 ON a.bnt_id			= B1.bnt_id;
			update m SET [Network Name]					 = LTRIM(RTRIM(B1.bnt_nm))			from Temp.mbwNew_PRPHOptions m inner join [MASTER].[prph_product_provision_history_1015] a on m.prph_rec_id = a.prph_rec_id and a.PRPH_REC_ID between @row_a and @row_b inner join [MASTER].[bnt_benefit_tier]								B1 ON a.bnt_id			= B1.bnt_id;


insert into #mbwTime (StepName) VALUES ('B2');
			update m SET SERVICE_PROVISION				 = LTRIM(RTRIM(B2.copptc_desc_t))	from Temp.mbwNew_PRPHOptions m inner join [MASTER].[prph_product_provision_history_1015] a on m.prph_rec_id = a.prph_rec_id and a.PRPH_REC_ID between @row_a and @row_b inner join [MASTER].[copptc_product_provision_type]					B2 ON a.prp_typ_c		= B2.copptc_c			And Ltrim(Rtrim(B2.copptc_desc_t))	= 'A'
insert into #mbwTime (StepName) VALUES ('B3');
			update m SET Qualifier						 = copptq_desc_t					from Temp.mbwNew_PRPHOptions m inner join [MASTER].[prph_product_provision_history_1015] a on m.prph_rec_id = a.prph_rec_id and a.PRPH_REC_ID between @row_a and @row_b inner join [MASTER].[copptq_product_provision_type_qualifier]		B3 On a.prp_typ_qlfr_c	= B3.copptq_c			And				B3.copptq_stus_c	= 'A'
insert into #mbwTime (StepName) VALUES ('B4');
			update m SET LineType						 = B4 .coplt_desc_t					from Temp.mbwNew_PRPHOptions m inner join [MASTER].[prph_product_provision_history_1015] a on m.prph_rec_id = a.prph_rec_id and a.PRPH_REC_ID between @row_a and @row_b inner join [MASTER].[coplt_product_provision_line_type]				B4 On A.prp_lin_typ_c	= B4.coplt_c			And B4.coplt_stus_c					= 'A'
insert into #mbwTime (StepName) VALUES ('B5');
			update m SET [Standardization level (COBSL)] = B5.cobsl_desc_t					from Temp.mbwNew_PRPHOptions m inner join [MASTER].[prph_product_provision_history_1015] a on m.prph_rec_id = a.prph_rec_id and a.PRPH_REC_ID between @row_a and @row_b inner join [MASTER].[cobsl_product_provision_standardization_level]	B5 On A.prp_stdz_lvl_c	= B5.cobsl_c			And B5.cobsl_stus_c					= 'A'
insert into #mbwTime (StepName) VALUES ('B3');
			update m SET [Value Type(COPVC)]			 = B6 .copvc_desc_t					from Temp.mbwNew_PRPHOptions m inner join [MASTER].[prph_product_provision_history_1015] a on m.prph_rec_id = a.prph_rec_id and a.PRPH_REC_ID between @row_a and @row_b inner join [MASTER].[copvc_product_value_type]						B6 On A.prp_vlu_clmn_c	= B6.copvc_c			And B6.copvc_stus_c					= 'A'
insert into #mbwTime (StepName) VALUES ('B6');
			update m SET [Value Relativity(COPVT)]		 = B7 .copvt_desc_t					from Temp.mbwNew_PRPHOptions m inner join [MASTER].[prph_product_provision_history_1015] a on m.prph_rec_id = a.prph_rec_id and a.PRPH_REC_ID between @row_a and @row_b inner join [MASTER].[copvt_product_provision_value_relativity]		B7 On A.prp_vlu_typ_c	= B7.copvt_c			And B7.copvt_stus_c					= 'A'
insert into #mbwTime (StepName) VALUES ('B8');
			update m SET [Period TextValue(PRPPTV)]		 = B8.prpptv_nm						from Temp.mbwNew_PRPHOptions m inner join [MASTER].[prph_product_provision_history_1015] a on m.prph_rec_id = a.prph_rec_id and a.PRPH_REC_ID between @row_a and @row_b inner join [MASTER].[prpptv_product_provision_period_text_value]	B8 On A.p_prp_vlu_t_set_id
																																																																								/*[Period TextSet]*/= B8.p_prp_vlu_t_set_id	And 
      																																																																							A.p_prp_vlu_t_id	= B8.p_prp_vlu_t_id		And	B8.prpptv_stus_c				= 'A'
		  --Left Join	[MASTER].[coppr_product_provision_relationship]					B9	On A.apl_to_prp_rel_c	=	B9.coppr_c				And B9.coppr_stus_c					=	'A'
		  --Left Join	[MASTER].[coppr_product_provision_relationship]					B10	On A.deps_on_prp_rel_c	=	B10.coppr_c				And B10.coppr_stus_c				=	'A'
		  --Left Join	[MASTER].[prptv_product_provision_text_value]					B11	On A.prp_vlu_t_set_id	=	B11.prp_vlu_t_set_id	And 
		  --																				   A.prp_vlu_t_id		=	B11.prp_vlu_t_id		And	B11.prptv_stus_c				=	'A'
		  --Left Join	[MASTER].[copvu_product_provision_value_unit]					B12	On A.prp_vlu_uom_c		=	B12.copvu_c				And B12.copvu_stus_c				=	'A'
		  --Left Join	[MASTER].[coppvc_product_provision_period]						B13	On A.prp_prd_vlu_clmn_c	=	B13.coppvc_c			And B13.coppvc_stus_c				=	'A'
		  --Left Join   [MASTER].[coppvu_product_provision_period_value_unit_of_measure]B14	On A.prp_prd_vlu_uom_c	=	B14.coppvu_c			And B14.coppvu_stus_c				=	'A'
insert into #mbwTime (StepName) VALUES ('B9');
			update m SET [Applies To (COPPR)]	= B9 .coppr_desc_t	from Temp.mbwNew_PRPHOptions m inner join [MASTER].[prph_product_provision_history_1015] a on m.prph_rec_id = a.prph_rec_id and a.PRPH_REC_ID between @row_a and @row_b inner join [MASTER].[coppr_product_provision_relationship]					B9	On A.apl_to_prp_rel_c	=	B9.coppr_c				And B9.coppr_stus_c		=	'A'
insert into #mbwTime (StepName) VALUES ('B10');
			update m SET [Depends On (COPPR)]	= B10.coppr_desc_t	from Temp.mbwNew_PRPHOptions m inner join [MASTER].[prph_product_provision_history_1015] a on m.prph_rec_id = a.prph_rec_id and a.PRPH_REC_ID between @row_a and @row_b inner join [MASTER].[coppr_product_provision_relationship]					B10	On A.deps_on_prp_rel_c	=	B10.coppr_c				And B10.coppr_stus_c	=	'A'
insert into #mbwTime (StepName) VALUES ('B11');
			update m SET [TextValue (PRPTV)]	= B11.prptv_nm		from Temp.mbwNew_PRPHOptions m inner join [MASTER].[prph_product_provision_history_1015] a on m.prph_rec_id = a.prph_rec_id and a.PRPH_REC_ID between @row_a and @row_b inner join [MASTER].[prptv_product_provision_text_value]					B11	On A.prp_vlu_t_set_id	=	B11.prp_vlu_t_set_id	And 
	  																																																																			   A.prp_vlu_t_id		=	B11.prp_vlu_t_id		And	B11.prptv_stus_c	=	'A'
insert into #mbwTime (StepName) VALUES ('B12');
			update m SET [Value Unit(COPVU)]	= B12.copvu_desc_t	from Temp.mbwNew_PRPHOptions m inner join [MASTER].[prph_product_provision_history_1015] a on m.prph_rec_id = a.prph_rec_id and a.PRPH_REC_ID between @row_a and @row_b inner join [MASTER].[copvu_product_provision_value_unit]					B12	On A.prp_vlu_uom_c		=	B12.copvu_c				And B12.copvu_stus_c	=	'A'
insert into #mbwTime (StepName) VALUES ('B13');
			update m SET [Period Type(COPPVC)]	= B13.coppvc_desc_t	from Temp.mbwNew_PRPHOptions m inner join [MASTER].[prph_product_provision_history_1015] a on m.prph_rec_id = a.prph_rec_id and a.PRPH_REC_ID between @row_a and @row_b inner join [MASTER].[coppvc_product_provision_period]						B13	On A.prp_prd_vlu_clmn_c	=	B13.coppvc_c			And B13.coppvc_stus_c	=	'A'
insert into #mbwTime (StepName) VALUES ('B14');
			update m SET [Period Unit(COPPVU)]	= B14.coppvu_desc_t from Temp.mbwNew_PRPHOptions m inner join [MASTER].[prph_product_provision_history_1015] a on m.prph_rec_id = a.prph_rec_id and a.PRPH_REC_ID between @row_a and @row_b inner join [MASTER].[coppvu_product_provision_period_value_unit_of_measure]	B14	On A.prp_prd_vlu_uom_c	=	B14.coppvu_c			And B14.coppvu_stus_c	=	'A'


			-- Now need to d svh_hierarchy
		  --Left Join	svh_hierarchy	B	On A.sv_id				=	B.sv_id					    

			-- Move up
			select @row_a = @row_a + @BATCH_COUNT
			select @row_b = @row_b + @BATCH_COUNT
			
		end -- On looping

/* This is execution on RPTeBS)enGen_SHC_DEV as wgsuser...
	--- Execution Time Summary ---
	Step 1 Duration:     5,180 ms (21.13%)
	Step 2 Duration:    12,255 ms (49.98%)
	Step 3 Duration:     7,084 ms (28.89%)
	Total  Duration:    24,519 ms

	Completion time: 2025-06-15T00:00:12.5465483-04:00

  But original was this (faster...!):
	--- Execution Time Summary ---
	Step 1 Duration:    13,351 ms (71.19%)
	Step 2 Duration:     1,794 ms (9.57%)
	Step 3 Duration:     3,609 ms (19.24%)
	Total  Duration:    18,754 ms

	Completion time: 2025-06-14T16:35:56.6557134-04:00

  -------------------------------------------------------------------------------- new is all step 1 in old	-------------------------------------------------------------------------------------------------------------------
  And now adding indexes (first for B1)					And now with all of them									And orig at same time				(w/o 2 order by)
	--- Execution Time Summary ---						--- Execution Time Summary ---							--- Execution Time Summary ---						--- Execution Time Summary ---
	Step 1 Duration:     6,177 ms (31.89%)				Step 1 Duration:    16,636 ms (65.41%)					Step 1 Duration:    13,141 ms (71.50%)				Step 1 Duration:    13,440 ms (70.72%)
	Step 2 Duration:     8,440 ms (43.57%)				Step 2 Duration:     6,249 ms (24.57%)					Step 2 Duration:     1,427 ms (7.76%)				Step 2 Duration:     1,666 ms (8.77%)
	Step 3 Duration:     4,752 ms (24.53%)				Step 3 Duration:     2,547 ms (10.01%)					Step 3 Duration:     3,810 ms (20.73%)				Step 3 Duration:     3,899 ms (20.52%)
	Total  Duration:    19,369 ms						Total  Duration:    25,432 ms							Total  Duration:    18,378 ms						Total  Duration:    19,005 ms

	Completion time: 2025-06-15T00:09:25.6223281-04:00	Completion time: 2025-06-15T00:29:26.9360341-04:00		Completion time: 2025-06-15T00:20:49.1980743-04:00	Completion time: 2025-06-15T00:23:07.3231603-04:00










*/


--if 123=456 begin
--	work through the rest of them, updaing the table forthe value
--	
--	then create the TextOption (after seeing if there are more select 5 than select distint 5 input fields... to know whether to combine wit the dbo.StringConcat
--	then see if the dbo.StringConcat is needed.
--	then see if it is blowing things out with the 5 = 6 -> 7
--	then make sure distinct is there


--		Where A.prp_stus_c =	'A'
--		--     And					A.pr_id = 
--		--						Case
--		--						When @PR_ID IS NOT NULL Then @PR_ID
--		--                           Else A.pr_id
--		--						End
--		--     And					B2.copptc_desc_t = 
--		--						Case
--		--                           When @SERVICE_PROVISION IS NOT NULL Then
--		--                                @SERVICE_PROVISION
--		--                           Else B2.copptc_desc_t
--		--                           End
--		-- AND					A.SV_ID	=	CASE WHEN @sv_id IS NOT NULL THEN @sv_id
--		--									ELSE A.SV_ID	END
--		--and					   c2.COPTC_DESC_T  = 
--		--						 case when @ProductType is not null then
--		--						        @ProductType else c2.COPTC_DESC_T
--		--							end
--		Order By				2, 3,39, 7,8,9, 12,5, 6,4	-- mbw: No need to have this if you have the table created with an index on this...  And WHY this order... not used...
	



	--	-- This is the CTE above -pull that out
	--	Left Join	svh_hierarchy													B	On A.sv_id				=	B.sv_id					    
		-- svh_hierarchy was first, but we'll do that at the bottom










--		-- mbW: look further at what this is pulling from the above table...
--		-- mbw: The distinct is not needed, and it's forcing SQL to do what it needn't do, unless the TextOptions varies across for a given first 5 fields... check that
--		--		POINT: The only purpose here is to swap TextOption for the dboStringConcat() verion called options.  
--		--		So:    This should be a table with the 5 plus TextOption - insert those 6 with distinct, and then create 7th by dbo.StringConcat() to get the options formatted one, then grab that below
--		--
--		--		POINT: It's use below is to apply EVERY version of TextOptions/options that is in the 5-field combo to every one of the combos
--		select DISTINCT pr_id, APL_TO_PRP_ID, service_provision, prp_eff_frm_dt, prp_eff_to_dt,
--						-- mbw: look at what this func is doing
--						dbo.StringConcat(ISNULL(TextOption,''),'','','','','','','','','','','','','','','','','','','','','','','','',APL_TO_PRP_ORD_N)  as options
--		into Temp.mbwNew_FullProvisionOption
--		from Temp.mbwNew_PRPHOptions
--		GROUP BY		pr_id, APL_TO_PRP_ID, service_provision, prp_eff_frm_dt, prp_eff_to_dt

--		-- mbw: Note: any field not specified as A. is from A.  (A and B share everyhing marked A and B only has options field to add here)
--		select
--			/* fld srt*/
--			/*  1	1 */	A.[pr_id]
--			/*  2	2 */,	  [TemplateType]
--			/*  3	3 */,	  [ProductType]
--			/*  4     */,	b.[options]			-- << The only thing we get from Temp.FullProvisionOption = if we do the dbo.StringConcat() up there this is all irrelevant code...
--			/*  5	9 */,	  [apl_to_prp_ord_n]
--			/*  6	8 */,	A.[apl_to_prp_id]
--			/*  7	  */,	A.[prp_id]
--			/*  8	5 */,	  [Service Name]
--			/*  9	6 */,	  [Network Name]
--			/* 10	7 */,	A.[SERVICE_PROVISION]
--			/* 11	  */,	  [sv_id]
--			/* 12	  */,	  [prp_stus_c]
--			/* 13	  */,	A.[prp_eff_frm_dt]
--			/* 14	  */,	A.[prp_eff_to_dt]
--			/* 15	  */,	  [Qualifier]
--			/* 16	  */,	  [LineType]
--			/* 17	  */,	  [Value Relativity(COPVT)]
--			/* 18	  */,	  [Value Unit(COPVU)]
--			/* 19	  */,	  [prp_vlu]
--			/* 20	  */,	  [mnm_prp_vlu]
--			/* 21	  */,	  [max_prp_vlu]
--			/* 22	  */,	  [prp_prd_vincrm_vlu]
--			/* 23	  */,	  [TextValue (PRPTV)]
--			/* 24	  */,	  [prp_vlu_t_set_id]
--			/* 25	  */,	  [Applies To (COPPR)]
--			/* 26	  */,	  [Depends On (COPPR)]
--			/* 27	  */,	  [Standardization level (COBSL)]
--			/* 28	  */,	  [Value Type(COPVC)]
--			/* 29	  */,	  [Period Type(COPPVC)]
--			/* 30	  */,	  [Period Unit(COPPVU)]
--			/* 31	  */,	  [Period Number(PRP_PRD_VLU)]
--			/* 32	  */,	  [Period TextValue(PRPPTV)]
--			/* 33	  */,	  [Period TextSet]
--			/* 34	  */,	  [Period Min]
--			/* 35	  */,	  [Period Max]
--			/* 36	  */,	  [Period Increment Value]
--			/* 37	  */,	  [deps_on_prp_id]
--			/* 38	  */,	  [deps_on_prp_ord_n]
--			/* 39	  */,	  [prp_inter_dep_prp_id]
--			/* 40   4 */,	  [prp_lim_for_prp_id]
--			/* 41     */,	  [prph_prsn_ord_n]
--		into Temp.mbwNew_FinalProvisionOptions
--		from		Temp.mbwNew_PRPHOptions			A
--		inner join	Temp.mbwNew_FullProvisionOption	B	on  A.pr_id						=  b.pr_id
--													and A.APL_TO_PRP_ID				=  b.APL_TO_PRP_ID
--													and A.service_provision			=  b.service_provision
--													and A.prp_eff_frm_dt			=  b.prp_eff_frm_dt
--													and isnull(A.prp_eff_to_dt,'')	=  isnull(b.prp_eff_to_dt,'')
--		-- mbw: again, figure the value here and just use a real table with an index...
--		-- And, the temp table Temp.FullProvisionOption could just have an index...even clustered if needed...
--		order by 1,2,3,40,8,9,10,6,5
	

--		/*	* /	
--		-- Review: Here's the order by Temp.PRPHOptions
--			/*  2	1 */	c3 .COPTT_DESC_T				as TemplateType,
--			/*  3	2 */	c2 .COPTC_DESC_T				as ProductType,
--			/* 39	3 */	A  .prp_lim_for_prp_id,
--			/*  7	4 */	Ltrim(Rtrim(B.LevelWithName))	AS [Service Name],
--			/*  8	5 */	Ltrim(Rtrim(B1.bnt_nm))			as [Network Name],
--			/*  9	6 */	Ltrim(Rtrim(B2.copptc_desc_t))	As SERVICE_PROVISION,				-- 3 of 5/6
--			/* 12	7 */	A  .prp_eff_frm_dt				As prp_eff_frm_dt,					-- 4 of 5/6
--			/*  5	8 */	A  .apl_to_prp_id,													-- 2 of 5/6
--			/*  6	9 */	A  .prp_id,
--			/*  4  10 */	A  .apl_to_prp_ord_n,fs


--		-- Review: And here's the Temp.FinalProvisionOptions
--			/*  1	1 */	A.[pr_id]
--			/*  2	2 */,	  [TemplateType]
--			/*  3	3 */,	  [ProductType]
--			/* 40   4 */,	  [prp_lim_for_prp_id]
--			/*  8	5 */,	  [Service Name]
--			/*  9	6 */,	  [Network Name]
--			/* 10	7 */,	A.[SERVICE_PROVISION]
--			/*  6	8 */,	A.[apl_to_prp_id]
--			/*  5	9 */,	  [apl_to_prp_ord_n]
--		/ * */
--end


		-- Reset the settings to default once the work is complete.
		SET NOCOUNT OFF;	
		SET XACT_ABORT OFF;

insert into #mbwTime (StepName) VALUES ('End');


  END TRY
  BEGIN CATCH -- HAndle all the errors here in this catch block....
		
		Declare @ErrorMessage	Nvarchar(MAX) ='' 	
		Declare @LINE			Int               
		Declare @SEVERITY		Int                
		Declare @STATE			Int
		Declare @PROCEDURE		Nvarchar(126)
		Declare @NUMBER			Int
		Declare	@MESSAGE		Nvarchar(2048)
		
		Select	 @LINE		=	ERROR_LINE()
				,@SEVERITY	=	ERROR_SEVERITY()
				,@STATE		=	ERROR_STATE()
				,@PROCEDURE =	ERROR_PROCEDURE()
				,@NUMBER	=	ERROR_NUMBER() 
				,@MESSAGE	=	ERROR_MESSAGE()


		
		
		IF (XACT_STATE())	=	1	-- mbw: Why commit this?  It's only valuable if the Temp.PRPHOptions or Temp.FullProvisionOption or Temp.FinalProvisionOptions are used.  Are they?
		BEGIN
			COMMIT TRANSACTION;
		END;

		IF (XACT_STATE())	= - 1
		BEGIN
			ROLLBACK TRANSACTION;
		END
		RAISERROR(@MESSAGE, @SEVERITY, 1, @NUMBER, @SEVERITY, @STATE, @PROCEDURE, @LINE);
	 END CATCH
		
--End	






-- Compute final columns
UPDATE t SET StepDurationMs = DATEDIFF(MILLISECOND, t.StepStartTime, t2.StepStartTime) FROM #mbwTime t       JOIN #mbwTime t2 ON t.StepNumber = t2.StepNumber - 1;
UPDATE t SET TotalTimeMs    = DATEDIFF(MILLISECOND, s.StartTime,      t.StepStartTime) FROM #mbwTime t CROSS JOIN (SELECT MIN(StepStartTime) AS StartTime FROM #mbwTime) s;

-- Now shift TotalTimeMs down by 1 row to reflect the end of the step
UPDATE t SET TotalTimeMs = t2.TotalTimeMs FROM #mbwTime t JOIN #mbwTime t2 ON t.StepNumber = t2.StepNumber - 1;

WITH Total AS ( SELECT MAX(TotalTimeMs) AS TotalDuration FROM #mbwTime )
SELECT 
    StepNumber,
    StepName,
    StepDurationMs,
    DurationSec = FORMAT(StepDurationMs / 1000.0, 'N2'),
    TotalTimeSec = FORMAT(TotalTimeMs / 1000.0, 'N2'),
    StepPct = FORMAT(StepDurationMs * 100.0 / t.TotalDuration, 'N2'),
    CumulativePct = FORMAT(TotalTimeMs * 100.0 / t.TotalDuration, 'N2')
FROM #mbwTime
CROSS JOIN Total t
ORDER BY StepNumber;

--			-- Clean up
--			DROP TABLE #mbwTime;
--			

/*
with all indexes over 30??

43 mins

StepName	DurationMs	DurationSec	DurationSec2	Pct
svh_heirarchy CTE	90	0.09	        0.09	0.00
insert into Temp.mbwNew_PRPHOptions	1557614	1,557.61	    1,557.61	60.38
B1	171031	171.03	      171.03	6.63
B2	283	0.28	        0.28	0.01
B3	16917	16.92	       16.92	0.66
B4	6859	6.86	        6.86	0.27
B5	275507	275.51	      275.51	10.68
B3	226139	226.14	      226.14	8.77
B6	39759	39.76	       39.76	1.54
B8	12359	12.36	       12.36	0.48
B9	36142	36.14	       36.14	1.40
B10	6698	6.70	        6.70	0.26
B11	158562	158.56	      158.56	6.15
B12	40291	40.29	       40.29	1.56
B13	15409	15.41	       15.41	0.60
B14	16098	16.10	       16.10	0.62



Without indexs 22:36 total

StepName	DurationMs	DurationSec	DurationSec2	Pct
svh_heirarchy CTE	89	0.09	        0.09	0.01
insert into Temp.mbwNew_PRPHOptions	317550	317.55	      317.55	23.42
B1	145797	145.80	      145.80	10.75
B2	279	0.28	        0.28	0.02
B3	21442	21.44	       21.44	1.58
B4	7621	7.62	        7.62	0.56
B5	220960	220.96	      220.96	16.30
B3	251558	251.56	      251.56	18.56
B6	59344	59.34	       59.34	4.38
B8	11258	11.26	       11.26	0.83
B9	42557	42.56	       42.56	3.14
B10	26338	26.34	       26.34	1.94
B11	166767	166.77	      166.77	12.30
B12	37654	37.65	       37.65	2.78
B13	33195	33.20	       33.20	2.45
B14	13251	13.25	       13.25	0.98

23:03 without indexes with exeuction plan		
StepName	DurationMs	DurationSec	DurationSec2	Pct
svh_heirarchy CTE	105	0.11	        0.11	0.01
insert into Temp.mbwNew_PRPHOptions	310624	310.62	      310.62	22.48
B1	144707	144.71	      144.71	10.47
B2	305	0.31	        0.31	0.02
B3	17595	17.60	       17.60	1.27
B4	9598	9.60	        9.60	0.69
B5	221299	221.30	      221.30	16.01
B3	277516	277.52	      277.52	20.08
B6	55241	55.24	       55.24	4.00
B8	9210	9.21	        9.21	0.67
B9	51547	51.55	       51.55	3.73
B10	25347	25.35	       25.35	1.83
B11	159205	159.21	      159.21	11.52
B12	53005	53.01	       53.01	3.84
B13	35359	35.36	       35.36	2.56
B14	11388	11.39	       11.39	0.82


32:41 with indexes with execution plan
StepName	DurationMs	DurationSec	DurationSec2	Pct
svh_heirarchy CTE	103	0.10	        0.10	0.01
insert into Temp.mbwNew_PRPHOptions	997346	997.35	      997.35	50.86
B1	173657	173.66	      173.66	8.86
B2	570	0.57	        0.57	0.03
B3	25920	25.92	       25.92	1.32
B4	9116	9.12	        9.12	0.46
B5	202895	202.90	      202.90	10.35
B3	194978	194.98	      194.98	9.94
B6	49689	49.69	       49.69	2.53
B8	17916	17.92	       17.92	0.91
B9	21877	21.88	       21.88	1.12
B10	1573	1.57	        1.57	0.08
B11	193882	193.88	      193.88	9.89
B12	35704	35.70	       35.70	1.82
B13	15554	15.55	       15.55	0.79
B14	20144	20.14	       20.14	1.03

UAT
																							Now joining to original table which has FKs to the lookup tables thorugh the PK on 1015 and my new one
																								No indexes on mbwNew			Add indexes
																								Through 1015	add order by	with order by
																							
											No index		With index							
1	svh_heirarchy CTE							0.11	        0.10								     0.10	     0.10        0.10
2	insert into Temp.mbwNew_PRPHOptions	      310.62	      997.35	much larger					   266.96	   258.36      982.13
3	B1									      144.71	      173.66								   320.49	   254.16      379.91
4	B2									        0.31	        0.57								     0.93	     0.67        0.49
5	B3									       17.60	       25.92								    10.62	    11.79       12.54
6	B4									        9.60	        9.12								     4.55	     4.90        5.46
7	B5									      221.30	      202.90								   160.21	   156.50      393.20
8	B3									      277.52	      194.98								   153.11	   157.55      151.47
9	B6									       55.24	       49.69								    33.34	    29.70       31.95
10	B8									        9.21	       17.92								     4.80	     5.80        5.45
11	B9									       51.55	       21.88	quicker						    33.11	    33.06       29.74
12	B10									       25.35	        1.57	much quicker				    26.07	    25.01       25.03
13	B11									      159.21	      193.88								   101.78	   101.13       99.93
14	B12									       53.01	       35.70	quicker						    22.67	    22.56       23.29
15	B13									       35.36	       15.55	much quicker				    27.89	    27.85       22.41
16	B14									       11.39	       20.14								     5.10	     5.05        5.50
																							
											   23:03           32:41									19:34	    18:16		36:11

												

						working				BUT ALSO FIND OUT WHY THE TABLES ARE 16,832 IN UAT WITH THEIR SP AND 19,261,548 FOR MINE...		also no index, NOT thrugh 1015 but with order by
						working				BUT ALSO FIND OUT WHY THE TABLES ARE 16,832 IN UAT WITH THEIR SP AND 19,261,548 FOR MINE...
						working				BUT ALSO FIND OUT WHY THE TABLES ARE 16,832 IN UAT WITH THEIR SP AND 19,261,548 FOR MINE...
						working				BUT ALSO FIND OUT WHY THE TABLES ARE 16,832 IN UAT WITH THEIR SP AND 19,261,548 FOR MINE...
						working				BUT ALSO FIND OUT WHY THE TABLES ARE 16,832 IN UAT WITH THEIR SP AND 19,261,548 FOR MINE...											


Now do 50,000 at a time, all through 1015
																																																							still no index in mbw
Withindexes and order by																														No indexes on mbwNew														all updates 50k each
StepNumber	StepName										StepDurationMs	DurationSec	TotalTimeSec	StepPct		CumulativePct	|	StepNumber	StepDurationMs	DurationSec	TotalTimeSec	StepPct		CumulativePct		!
402			19,956,765 =  8,161,537,709 ..  8,162,150,520	180	0.18		513.60		0.02			67.44						|	402			275	0.28		139.10		0.07			35.72							!
403			B1												84059			84.06		597.66			11.04		78.48			|	403			83242			83.24		222.34			21.38		57.10				!
404			B2												197				0.20		597.86			0.03		78.51			|	404			305				0.31		222.65			0.08		57.18				!
405			B3												3603			3.60		601.46			0.47		78.98			|	405			3701			3.70		226.35			0.95		58.13				!
406			B4												1605			1.61		603.07			0.21		79.19			|	406			1697			1.70		228.05			0.44		58.56				!
407			B5												51245			51.25		654.31			6.73		85.92			|	407			52853			52.85		280.90			13.57		72.14				!
408			B3												50593			50.59		704.90			6.64		92.57			|	408			49540			49.54		330.44			12.72		84.86				!
409			B6												5505			5.51		710.41			0.72		93.29			|	409			5612			5.61		336.05			1.44		86.30				!
410			B8												1960			1.96		712.37			0.26		93.55			|	410			2137			2.14		338.19			0.55		86.85				!
411			B9												3486			3.49		715.86			0.46		94.00			|	411			3702			3.70		341.89			0.95		87.80				!
412			B10												401				0.40		716.26			0.05		94.06			|	412			880				0.88		342.77			0.23		88.03				!
413			B11												33462			33.46		749.72			4.39		98.45			|	413			34530			34.53		377.30			8.87		96.89				!
414			B12												6398			6.40		756.12			0.84		99.29			|	414			6498			6.50		383.80			1.67		98.56				!
415			B13												3342			3.34		759.46			0.44		99.73			|	415			3461			3.46		387.26			0.89		99.45				!
416			B14												2055			2.06		761.51			0.27		100.00			|	416			2139			2.14		389.40			0.55		100.00				!
417			End												NULL			NULL		761.51			NULL		100.00			|	417			NULL			NULL		389.40			NULL		100.00				!		total was 13:26  6003   805.68
																					all slightly smaller														all slightly bigger
																					but the first insert														but first insert way better
																					is much larger																is way better


																					




StepNumber	StepName										StepDurationMs	DurationSec	TotalTimeSec	StepPct		CumulativePct
402			19,956,765 =  8,161,537,710 ..  8,162,150,520	275	0.28		139.10		0.07			35.72
403			B1												83242			83.24		222.34			21.38		57.10
404			B2												305				0.31		222.65			0.08		57.18
405			B3												3701			3.70		226.35			0.95		58.13
406			B4												1697			1.70		228.05			0.44		58.56
407			B5												52853			52.85		280.90			13.57		72.14
408			B3												49540			49.54		330.44			12.72		84.86
409			B6												5612			5.61		336.05			1.44		86.30
410			B8												2137			2.14		338.19			0.55		86.85
411			B9												3702			3.70		341.89			0.95		87.80
412			B10												880				0.88		342.77			0.23		88.03
413			B11												34530			34.53		377.30			8.87		96.89
414			B12												6498			6.50		383.80			1.67		98.56
415			B13												3461			3.46		387.26			0.89		99.45
416			B14												2139			2.14		389.40			0.55		100.00
417			End												NULL			NULL		389.40			NULL		100.00




        0.10
      982.13
      379.91fs
        0.49
       12.54
        5.46
      393.20
      151.47
       31.95
        5.45
       29.74
       25.03
       99.93
       23.29
       22.41
        5.50



Through 1015

StepName	DurationMs	DurationSec	DurationSec2	Pct
svh_heirarchy CTE	101	0.10	        0.10	0.01
insert into Temp.mbwNew_PRPHOptions	266959	266.96	      266.96	22.78
B1	320494	320.49	      320.49	27.35
B2	934	0.93	        0.93	0.08
B3	10616	10.62	       10.62	0.91
B4	4547	4.55	        4.55	0.39
B5	160209	160.21	      160.21	13.67
B3	153111	153.11	      153.11	13.07
B6	33342	33.34	       33.34	2.85
B8	4797	4.80	        4.80	0.41
B9	33110	33.11	       33.11	2.83
B10	26072	26.07	       26.07	2.23
B11	101776	101.78	      101.78	8.69
B12	22665	22.67	       22.67	1.93
B13	27886	27.89	       27.89	2.38
B14	5101	5.10	        5.10	0.44


        0.10
      266.96
      320.49
        0.93
       10.62
        4.55
      160.21
      153.11
       33.34
        4.80
       33.11
       26.07
      101.78
       22.67
       27.89
        5.10


StepName	DurationMs	DurationSec	DurationSec2	Pct
svh_heirarchy CTE	102	0.10	        0.10	0.01
insert into Temp.mbwNew_PRPHOptions	258359	258.36	      258.36	23.61
B1	254160	254.16	      254.16	23.23
B2	674	0.67	        0.67	0.06
B3	11785	11.79	       11.79	1.08
B4	4895	4.90	        4.90	0.45
B5	156500	156.50	      156.50	14.30
B3	157551	157.55	      157.55	14.40
B6	29703	29.70	       29.70	2.71
B8	5804	5.80	        5.80	0.53
B9	33057	33.06	       33.06	3.02
B10	25008	25.01	       25.01	2.29
B11	101131	101.13	      101.13	9.24
B12	22560	22.56	       22.56	2.06
B13	27853	27.85	       27.85	2.55
B14	5049	5.05	        5.05	0.46

        0.10
      258.36
      254.16
        0.67
       11.79
        4.90
      156.50
      157.55
       29.70
        5.80
       33.06
       25.01
      101.13
       22.56
       27.85
        5.05


*/