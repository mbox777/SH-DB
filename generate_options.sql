--USE [RPTeBS_enGen_UAT]
--GO
--USE [RPTeBS_enGen_SHC_DEV]
--GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


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
	--Try block added for error handling if any
	BEGIN TRY 

		if 1=2 begin
			-- mbw: Why is this drop and recreate without any indexes or table structure?  Just truncate the tables that exist with indexes, types
			-- Clear all the temp tables that we need will dump things into  
			if object_id('Temp.mbw_PRPHOptions')				is not null begin drop table Temp.mbw_PRPHOptions			end
			if object_id('Temp.mbw_FullProvisionOption')		is not null begin drop table Temp.mbw_FullProvisionOption	end
			if object_id('Temp.mbw_FinalProvisionOptions')		is not null begin drop table Temp.mbw_FinalProvisionOptions	end
		end else begin
			if object_id('Temp.mbwNew_PRPHOptions')				is not null begin truncate table Temp.mbwNew_PRPHOptions			;select 'truncated table 1' end 
			if object_id('Temp.mbwNew_FullProvisionOption')		is not null begin truncate table Temp.mbwNew_FullProvisionOption	;select 'truncated table 2' end
			if object_id('Temp.mbwNew_FinalProvisionOptions')	is not null begin truncate table Temp.mbwNew_FinalProvisionOptions	;select 'truncated table 3' end
			
			if object_id('Temp.mbwNew_PRPHOptions')				is     null begin RAISERROR('must create table 1.', 16, 1); end 
			if object_id('Temp.mbwNew_FullProvisionOption')		is     null begin RAISERROR('must create table 2.', 16, 1); end 
			if object_id('Temp.mbwNew_FinalProvisionOptions')	is     null begin RAISERROR('must create table 3.', 16, 1); end 
		end


-- Showing e
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
		--select 'new',* from svh_hierarchy


--if 123=456 begin
--		-- Note: This big table is the final answer, except for needing to add "options" which is done using...
--		--							1      2              3                  4               5
--		--			select DISTINCT pr_id, APL_TO_PRP_ID, service_provision, prp_eff_frm_dt, prp_eff_to_dt,   plus the dbo.StringConcat on TextOption generated here
--		--		 ... so find out if there are multiple TextOption for a given combo of thoes 

--		-- Use the CTE
--		Select Distinct		-- mbw: crazy computionally to do the sort this way  ?? Are there sort orders on any of the lookup tables?  Could select the fields in sorted order from lookups and index this table by those ints for sort field 1,2
--			/* fld srt*/
--			/*  1	  */	A  .pr_id,															-- 1 of 5/6		A
--			/*  2	1 */	c3 .COPTT_DESC_T				as TemplateType,
--			/*  3	2 */	c2 .COPTC_DESC_T				as ProductType,
--								-- << Here is where "options" as a filtered version of TextOption will go
--			/*  4  10 */	A  .apl_to_prp_ord_n,
--			/*  5	8 */	A  .apl_to_prp_id,													-- 2 of 5/6		A
--			/*  6	9 */	A  .prp_id,
--			/*  7	4 */	Ltrim(Rtrim(B.LevelWithName))	AS [Service Name],
--			/*  8	5 */	Ltrim(Rtrim(B1.bnt_nm))			as [Network Name],									
--			/*  9	6 */	Ltrim(Rtrim(B2.copptc_desc_t))	As SERVICE_PROVISION,				-- 3 of 5/6		B2	(is left joined)
--			/* 10	  */	A  .sv_id,
--			/* 11	  */	A  .prp_stus_c,
--			/* 12	7 */	A  .prp_eff_frm_dt				As prp_eff_frm_dt,					-- 4 of 5/6		A
--			/* 13	  */	A  .prp_eff_to_dt				As prp_eff_to_dt,					-- 5 of 5/6		A
--			/* 14	  */	B3 .copptq_desc_t				As Qualifier,
--			/* 15	  */	B4 .coplt_desc_t				As LineType,
--			/* 16	  */	B7 .copvt_desc_t				As [Value Relativity(COPVT)],
--			/* 17	  */	B12.copvu_desc_t				As [Value Unit(COPVU)],
--			/* 18	  */	convert(varchar(50),A.prp_vlu)	AS prp_vlu,
--			/* 19	  */	A  .mnm_prp_vlu,
--			/* 20	  */	A  .max_prp_vlu,
--			/* 21	  */	A  .prp_prd_vincrm_vlu,
--			/* 22	  */	B11.prptv_nm					As [TextValue (PRPTV)],
--			/* 23	  */	A  .prp_vlu_t_set_id,
--			/* 24	  */	B9 .coppr_desc_t				AS [Applies To (COPPR)],
--			/* 25	  */	B10.coppr_desc_t				AS [Depends On (COPPR)],
--			/* 26	  */	B5 .cobsl_desc_t				As [Standardization level (COBSL)],
--			/* 27	  */	B6 .copvc_desc_t				As [Value Type(COPVC)] ,
--			/* 28	  */	B13.coppvc_desc_t				As [Period Type(COPPVC)],
--			/* 29	  */	B14.coppvu_desc_t				As [Period Unit(COPPVU)],
--			/* 30	  */	A  .prp_prd_vlu					As [Period Number(PRP_PRD_VLU)],
--			/* 31	  */	B8 .prpptv_nm					As [Period TextValue(PRPPTV)],
--			/* 32	  */	A  .p_prp_vlu_t_set_id			As [Period TextSet],
--			/* 33	  */	A  .mnm_prp_prd_vlu				As [Period Min],
--			/* 34	  */	A  .max_prp_prd_vlu				As [Period Max],
--			/* 35	  */	A  .PRP_VLU_INCRM_VLU			AS [Period Increment Value],
--			/* 36	  */	A  .deps_on_prp_id,
--			/* 37	  */	A  .deps_on_prp_ord_n,
--			/* 38	  */	A  .prp_inter_dep_prp_id,
--			/* 39	3 */	A  .prp_lim_for_prp_id,
--			/* 40	  */	A  .prph_prsn_ord_n,
--							-- mbw: Take the calculation out of the distinct.  This func should be deterministic on the inputs, and shouldn't need to be synced
--							--		TODO: Figure whether pulling it out can work, since not all fields are in the table, and the TextOption fields is in the distinct 41 field...
--							--		TODO: Decide whether to do this here or if it's pulled out here, or to do this below in a 7 field new table fixing the 6 field CTE
--							--				dbo.StringConcat(ISNULL(TextOption,''),'','','','','','','','','','','','','','','','','','','','','','','','',APL_TO_PRP_ORD_N)  as options
--							Master.GetProvisionTextOptions	(	
--								/* Tbl it is from, or 1015 if not in this resultset */
--								/* b4   */	coplt_desc_t,			-- As LineType
--								/* b2   */	copptc_desc_t,			-- As SERVICE_PROVISION		
--								/* b3   */	copptq_desc_t,			-- As [Value Unit(COPVU)]
--								/* 1015 */	prp_vlu_clmn_c,			-- This 1015 fiels is not in results so need to add to table if we use a bulk updates later
--								/* in   */	prp_vlu,				-- This 1015 field is in the results
--								/* b12  */	copvu_desc_t,			-- As [Value Unit(COPVU)]
--								/* in   */	mnm_prp_vlu,			-- This 1015 field is in the results
--								/* in   */	max_prp_vlu,			-- This 1015 field is in the results
--								/* b11  */	prptv_nm,				-- As [TextValue (PRPTV)]
--								/* in   */	prp_vlu_incrm_vlu,		-- This 1015 field is in the results (as [Period Increment Value] name)
--								/* 1015 */	prp_prd_vlu_clmn_c,		-- This 1015 field is not in results so need to add to table if we use a bulk updates later
--								/* in   */	prp_prd_vlu,			-- This 1015 field is in the results (as [Period Number(PRP_PRD_VLU)] name)
--								/* b14  */	coppvu_desc_t,			-- As [Period Unit(COPPVU)]
--								/* in   */	mnm_prp_prd_vlu,		-- This 1015 field is in the results (as [Period Min] name)
--								/* in   */	max_prp_prd_vlu,		-- This 1015 field is in the results (as [Period Max] name)
--								/* b8   */	prpptv_nm,				-- As [Period TextValue(PRPPTV)]
--								/* b9   */	B9.coppr_desc_t,		-- AS [Applies To (COPPR)],
--								/* b10  */	B10.coppr_desc_t ,		-- AS [Depends On (COPPR)],
--								/* in   */	prp_prd_vincrm_vlu,
--								/*      */	1,
--								/*      */	1,
--								/* in   */	a.p_prp_vlu_t_set_id	-- This 1015 field is in the results (as [Period TextSet] name)
--			/* 41     */	)								as TextOption						-- 6 of 5/6

--		into Temp.mbwNew_PRPHOptions
--					-- mbw: On all the straight lookups, just do individual bulk inserts on the values
--		From		[MASTER].[prph_product_provision_history_1015]					A
--		Inner Join	[MASTER].[pr_product]											c	On a.pr_id				=	c.pr_id
--		-- mbw: there's no reason to join these here... not used in further joins
--		--		AND: even worse, these 2 tables together are cross-joined 
--		--			 (c2 was in the "and" that is commented out...)
--		--	SO...they are gonna create incorrect data in the Temp.PRPHOptions table!!!
--		Left Join	[MASTER].[copt_producttype]										e	On c.pr_typ_c			=	e.copt_c				And e.copt_stus_c					=	'A'
--		left join	[MASTER].[COPTC_PRODUCT_TYPE_CATEGORIZATION]					c2	on c2.COPTC_C			=	e.COPT_PR_AFL_TYP_C		and c2.COPTC_STUS_C					=	'A'

--		Inner Join	[MASTER].[prh_product_history]									D	On a.pr_id				=	d.pr_id					And d.pr_stus_c						=	'A'
--		inner join	[MASTER].[COPTT]												c3	on d.PR_TMPLT_TYP_C		=	c3.COPTT_C				and c3.COPTT_STUS_C					=	'A' 
--		-- This is the CTE above -pull that out
--		Left Join	svh_hierarchy													B	On A.sv_id				=	B.sv_id					    
--		-- All these can be a bulk update
--		Left Join	[MASTER].[bnt_benefit_tier]										B1	On A.bnt_id				=	B1.bnt_id				And B1.bnt_stus_c					=	'A'
--		Left Join	[MASTER].[copptc_product_provision_type]						B2	On A.prp_typ_c			=	B2.copptc_c				And Ltrim(Rtrim(B2.copptc_stus_c))	=	'A'
--		Left Join	[MASTER].[copptq_product_provision_type_qualifier]				B3	On A.prp_typ_qlfr_c		=	B3.copptq_c				And B3.copptq_stus_c				=	'A'
--		Left Join	[MASTER].[coplt_product_provision_line_type]					B4	On A.prp_lin_typ_c		=	B4.coplt_c				And B4.coplt_stus_c					=	'A'
--		Left Join	[MASTER].[cobsl_product_provision_standardization_level]		B5	On A.prp_stdz_lvl_c		=	B5.cobsl_c				And B5.cobsl_stus_c					=	'A'
--		Left Join	[MASTER].[copvc_product_value_type]								B6	On A.prp_vlu_clmn_c		=	B6.copvc_c				And B6.copvc_stus_c					=	'A'
--		Left Join	[MASTER].[copvt_product_provision_value_relativity]				B7	On A.prp_vlu_typ_c		=	B7.copvt_c				And B7.copvt_stus_c					=	'A'
--		Left Join	[MASTER].[prpptv_product_provision_period_text_value]			B8	On A.p_prp_vlu_t_set_id	=	B8.p_prp_vlu_t_set_id	And 
--																						   A.p_prp_vlu_t_id		=	B8.p_prp_vlu_t_id		And	B8.prpptv_stus_c				=	'A'
--		Left Join	[MASTER].[coppr_product_provision_relationship]					B9	On A.apl_to_prp_rel_c	=	B9.coppr_c				And B9.coppr_stus_c					=	'A'
--		Left Join	[MASTER].[coppr_product_provision_relationship]					B10	On A.deps_on_prp_rel_c	=	B10.coppr_c				And B10.coppr_stus_c				=	'A'
--		Left Join	[MASTER].[prptv_product_provision_text_value]					B11	On A.prp_vlu_t_set_id	=	B11.prp_vlu_t_set_id	And 
--																						   A.prp_vlu_t_id		=	B11.prp_vlu_t_id		And	B11.prptv_stus_c				=	'A'
--		Left Join	[MASTER].[copvu_product_provision_value_unit]					B12	On A.prp_vlu_uom_c		=	B12.copvu_c				And B12.copvu_stus_c				=	'A'
--		Left Join	[MASTER].[coppvc_product_provision_period]						B13	On A.prp_prd_vlu_clmn_c	=	B13.coppvc_c			And B13.coppvc_stus_c				=	'A'
--		Left Join   [MASTER].[coppvu_product_provision_period_value_unit_of_measure]B14	On A.prp_prd_vlu_uom_c	=	B14.coppvu_c			And B14.coppvu_stus_c				=	'A'

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
