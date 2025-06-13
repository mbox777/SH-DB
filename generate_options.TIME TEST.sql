--	USE RPTeBS_enGen_UAT
--	GO



-- Declare variables to store timestamps
DECLARE @StartTime DATETIME2 = SYSDATETIME();
DECLARE @Step1Time DATETIME2;
DECLARE @Step2Time DATETIME2;
DECLARE @Step3Time DATETIME2;
DECLARE @EndTime   DATETIME2;




--	/****** Object:  StoredProcedure [Temp].[Getproductprovisionlines]    Script Date: 6/12/2025 8:59:18 AM ******/
--	SET ANSI_NULLS ON
--	GO
--	SET QUOTED_IDENTIFIER ON
--	GO
--	
--	
--	/**************************************************************************************************
--	Name
--			[Temp].[Getproductprovisionlines]
--	Purpose
--		 To fetch Provision data for given Product or Service ID or service provision
--		
--	Assumption
--		data exists in the provision master table for given input parameters
--	
--	Params
--		See below for defn
--		
--	History
--		2019-10-16	Sunil K Created
--		2019-12-08  Sunil K Added Period Increment value in the select column list
--		
--	Test Run : 
--	exec [Temp].[Getproductprovisionlines] null,'Out-of-Pocket Excludes Copayments'
--	
--	**************************************************************************************************/
--	ALTER PROCEDURE [Temp].[Getproductprovisionlines] 
declare
	@PR_ID					Bigint			=	NULL,
	@SERVICE_PROVISION		Varchar (500)	=	NULL,
	@sv_id					bigint			=	NULL,
	@ProductType            Varchar (500)   =   NULL
--	As
--	Begin

		-- SET NOCOUNT ON added to prevent extra result sets From
		-- interfering with Select statements.
	  SET NOCOUNT ON;
		-- This XACT_ABORT ON setting will rollback entire transaction if there is any single error & stop further processing of the SP
	  SET XACT_ABORT ON;
		--Try block added for error handling if any
	  BEGIN TRY 
  
		if object_id('Temp.mbw_PRPHOptions') is not null
		drop table Temp.mbw_PRPHOptions

		if object_id('Temp.mbw_FullProvisionOption') is not null
		drop table Temp.mbw_FullProvisionOption

		if object_id('Temp.mbw_FinalProvisionOptions') is not null
		drop table Temp.mbw_FinalProvisionOptions

		--Generating Provisions data
		 ; WITH svh  As
		   (
				--Select		A.sv_id, A.sv_nm
				Select		distinct A.sv_id,c.PARN_SV_ID,c.SV_STRC_C, A.sv_nm
				From		[MASTER].[svh_medical_service_history] A
				Inner Join	(
								Select		A.sv_id, Max(A.sv_eff_frm_dt) sv_eff_frm_dt
								From		[MASTER].[svh_medical_service_history] A
								Where		A.sv_stus_c		=	'A'
								Group  By	A.sv_id
							 ) B
				On			 A.sv_id = B.sv_id
				And			 A.sv_eff_frm_dt	=	B.sv_eff_frm_dt
				inner join
					[MASTER].[sv_medical_service] c
				on a.SV_ID	=	c.SV_ID
				--inner join	
				--	[MASTER].[PRS_PRODUCT_SERVICE] d
				--on a.SV_ID	=	b.SV_ID
				--and			 d.pr_id	=	Case
				--				When @PR_ID IS NOT NULL Then @PR_ID
	   --                         Else d.pr_id
				--				End
				Where		 A.sv_stus_c		=	'A'
			), svh_hierarchy as
		(
		  SELECT P.sv_id, CAST(P.SV_NM AS VarChar(Max)) as LevelWithName  , CAST(P.SV_ID AS VarChar(Max)) as LevelWithID --, P.PARN_SV_ID
		  FROM svh P
		  WHERE P.PARN_SV_ID IS NULL

		  UNION ALL

		  SELECT P1.sv_id, CAST(P1.SV_NM AS VarChar(Max)) + ' -> ' + M.LevelWithName , CAST(P1.SV_ID AS VarChar(Max)) + ' -> ' + M.LevelWithID --, P1.PARN_SV_ID
		  FROM svh P1  
		  INNER JOIN svh_hierarchy M
		  ON M.sv_id = P1.PARN_SV_ID
		 )

		  Select Distinct		A.pr_id,
								c3.COPTT_DESC_T   TemplateType,
								c2.COPTC_DESC_T   ProductType,
								A.apl_to_prp_ord_n,
								A.apl_to_prp_id,
								A.prp_id,
								Ltrim(Rtrim(B.LevelWithName)) AS [Service Name],
								Ltrim(Rtrim(B1.bnt_nm)) as [Network Name],
								Ltrim(Rtrim(B2.copptc_desc_t)) As SERVICE_PROVISION,
								A.sv_id,
								A.prp_stus_c,
								A.prp_eff_frm_dt               As   prp_eff_frm_dt,
								A.prp_eff_to_dt                As	prp_eff_to_dt,
								B3.copptq_desc_t               As	Qualifier,
								B4.coplt_desc_t                As	LineType,
								B7.copvt_desc_t                As	[Value Relativity(COPVT)],
								B12.copvu_desc_t               As	[Value Unit(COPVU)],
								convert(varchar(50),A.prp_vlu) AS	prp_vlu,
								A.mnm_prp_vlu,
								A.max_prp_vlu,
								A.prp_prd_vincrm_vlu,
								B11.prptv_nm                   As	[TextValue (PRPTV)],
								A.prp_vlu_t_set_id,
								B9.coppr_desc_t			       AS   [Applies To (COPPR)],
								B10.coppr_desc_t		       AS   [Depends On (COPPR)],
								B5.cobsl_desc_t                As	[Standardization level (COBSL)],
								B6.copvc_desc_t                As	[Value Type(COPVC)] ,
								B13.coppvc_desc_t              As	[Period Type(COPPVC)],
								B14.coppvu_desc_t			   As	[Period Unit(COPPVU)],
								A.prp_prd_vlu                  As	[Period Number(PRP_PRD_VLU)],
								B8.prpptv_nm                   As	[Period TextValue(PRPPTV)],
								A.p_prp_vlu_t_set_id           As	[Period TextSet],
								A.mnm_prp_prd_vlu              As	[Period Min],
								A.max_prp_prd_vlu              As	[Period Max],
								A.PRP_VLU_INCRM_VLU			   AS   [Period Increment Value],
								A.deps_on_prp_id,
								A.deps_on_prp_ord_n,
								A.prp_inter_dep_prp_id,
								A.prp_lim_for_prp_id,
								A.prph_prsn_ord_n,
								 Master.GetProvisionTextOptions
					   (
							   coplt_desc_t,
							   copptc_desc_t, 
							   copptq_desc_t, 
							   prp_vlu_clmn_c, 
							   prp_vlu,
							   copvu_desc_t,
							   mnm_prp_vlu,
							   max_prp_vlu,
							   prptv_nm,
							   prp_vlu_incrm_vlu, 
							   prp_prd_vlu_clmn_c, 
							   prp_prd_vlu,
							   coppvu_desc_t,
							   mnm_prp_prd_vlu, 
							   max_prp_prd_vlu,
							   prpptv_nm, 
							   B9.coppr_desc_t,       
							   B10.coppr_desc_t ,
							   prp_prd_vincrm_vlu,
							   1,
							   1,
							   a.p_prp_vlu_t_set_id) as TextOption

		  into Temp.mbw_PRPHOptions
		  From					[MASTER].[prph_product_provision_history_1015] A
		  Inner Join			[MASTER].[pr_product] c
		  On					a.pr_id							=	c.pr_id
		  Left Join				[MASTER].[copt_producttype] e
		  On					c.pr_typ_c						=	e.copt_c
		  And					e.copt_stus_c					=	'A'
		 left join				[MASTER].[COPTC_PRODUCT_TYPE_CATEGORIZATION] c2
		 on						c2.COPTC_C	=	e.COPT_PR_AFL_TYP_C
		 and					c2.COPTC_STUS_C	=	'A'
		  Inner Join			[MASTER].[prh_product_history] D
		  On					a.pr_id							=	d.pr_id
		  And					d.pr_stus_c						=	'A'
		 inner join				[MASTER].[COPTT]	c3
		 on						d.PR_TMPLT_TYP_C	=	c3.COPTT_C
		 and					c3.COPTT_STUS_C		=	'A' 
		  Left Join				svh_hierarchy B
		  On					A.sv_id							=	B.sv_id
		  Left Join				[MASTER].[bnt_benefit_tier] B1
		  On					A.bnt_id						=	B1.bnt_id
		  And				    B1.bnt_stus_c					=	'A'
		  Left Join				[MASTER].[copptc_product_provision_type] B2
		  On				    A.prp_typ_c						=	B2.copptc_c
		  And					Ltrim(Rtrim(B2.copptc_stus_c))	=	'A'
		  Left Join				[MASTER].[copptq_product_provision_type_qualifier] B3
		  On					A.prp_typ_qlfr_c				=	B3.copptq_c
		  And					B3.copptq_stus_c				=	'A'
		  Left Join				[MASTER].[coplt_product_provision_line_type] B4
		  On					A.prp_lin_typ_c					=	B4.coplt_c
		  And					B4.coplt_stus_c					=	'A'
		  Left Join				[MASTER].[cobsl_product_provision_standardization_level] B5
		  On					A.prp_stdz_lvl_c				=	B5.cobsl_c
		  And					B5.cobsl_stus_c					=	'A'
		  Left Join				[MASTER].[copvc_product_value_type] B6
		  On					A.prp_vlu_clmn_c				=	B6.copvc_c
		  And					B6.copvc_stus_c					=	'A'
		  Left Join				[MASTER].[copvt_product_provision_value_relativity] B7
		  On					A.prp_vlu_typ_c					=	B7.copvt_c
		  And					B7.copvt_stus_c					=	'A'
		  Left Join				[MASTER].[prpptv_product_provision_period_text_value] B8
		  On					A.p_prp_vlu_t_set_id			=	B8.p_prp_vlu_t_set_id
		  And					A.p_prp_vlu_t_id				=	B8.p_prp_vlu_t_id
		  And					B8.prpptv_stus_c				=	'A'
		  Left Join				[MASTER].[coppr_product_provision_relationship] B9
		  On					A.apl_to_prp_rel_c				=	B9.coppr_c
		  And					B9.coppr_stus_c					=	'A'
		  Left Join				[MASTER].[coppr_product_provision_relationship] B10
		  On					A.deps_on_prp_rel_c				=	B10.coppr_c
		  And					B10.coppr_stus_c				=	'A'
		  Left Join			    [MASTER].[prptv_product_provision_text_value] B11
		  On					A.prp_vlu_t_set_id				=	B11.prp_vlu_t_set_id
		  And					A.prp_vlu_t_id					=	B11.prp_vlu_t_id
		  And					B11.prptv_stus_c				=	'A'
		  Left Join				[MASTER].[copvu_product_provision_value_unit] B12
		  On					A.prp_vlu_uom_c					=	B12.copvu_c
		  And					B12.copvu_stus_c				=	'A'
		  Left Join				[MASTER].[coppvc_product_provision_period] B13
		  On					A.prp_prd_vlu_clmn_c			=	B13.coppvc_c
		  And					B13.coppvc_stus_c				=	'A'
		  Left Join             [MASTER].[coppvu_product_provision_period_value_unit_of_measure] B14
		  On					A.prp_prd_vlu_uom_c				=	B14.coppvu_c
		  And					B14.coppvu_stus_c				=	'A'
		  Where					A.prp_stus_c					=	'A'
	 --     And					A.pr_id = 
		--						Case
		--						When @PR_ID IS NOT NULL Then @PR_ID
	 --                           Else A.pr_id
		--						End
	 --     And					B2.copptc_desc_t = 
		--						Case
	 --                           When @SERVICE_PROVISION IS NOT NULL Then
	 --                                @SERVICE_PROVISION
	 --                           Else B2.copptc_desc_t
	 --                           End
		-- AND					A.SV_ID	=	CASE WHEN @sv_id IS NOT NULL THEN @sv_id
		--									ELSE A.SV_ID	END
		--and					   c2.COPTC_DESC_T  = 
		--						 case when @ProductType is not null then
		--						        @ProductType else c2.COPTC_DESC_T
		--							end
		  Order By				2, 3,39, 7,8,9, 12,5, 6,4  
	
-- Step 1: First query with CTEs
SET @Step1Time = SYSDATETIME();


		select DISTINCT pr_id,APL_TO_PRP_ID,service_provision,prp_eff_frm_dt,prp_eff_to_dt,
		dbo.StringConcat(ISNULL(TextOption,''),'','','','','','','','','','','','','','','','','','','','','','','','',APL_TO_PRP_ORD_N)  as options
		into Temp.mbw_FullProvisionOption
		from Temp.mbw_PRPHOptions
		GROUP BY pr_id,APL_TO_PRP_ID,service_provision,prp_eff_frm_dt,prp_eff_to_dt

-- Step 2: Create the "dbo-StringConcat"-cleansed value
SET @Step2Time = SYSDATETIME();


		select A.[pr_id],[TemplateType],[ProductType],b.[options],[apl_to_prp_ord_n],A.[apl_to_prp_id],A.[prp_id],[Service Name],[Network Name],A.[SERVICE_PROVISION],[sv_id],[prp_stus_c],A.[prp_eff_frm_dt],A.[prp_eff_to_dt],[Qualifier],[LineType],[Value Relativity(COPVT)],[Value Unit(COPVU)],[prp_vlu],[mnm_prp_vlu],[max_prp_vlu],[prp_prd_vincrm_vlu],[TextValue (PRPTV)],[prp_vlu_t_set_id],[Applies To (COPPR)],[Depends On (COPPR)],[Standardization level (COBSL)],[Value Type(COPVC)],[Period Type(COPPVC)],[Period Unit(COPPVU)],[Period Number(PRP_PRD_VLU)],[Period TextValue(PRPPTV)],[Period TextSet],[Period Min],[Period Max],[Period Increment Value],[deps_on_prp_id],[deps_on_prp_ord_n],[prp_inter_dep_prp_id],[prp_lim_for_prp_id],[prph_prsn_ord_n]
		into Temp.mbw_FinalProvisionOptions
		from Temp.mbw_PRPHOptions A
		inner join
			Temp.mbw_FullProvisionOption B
		on  A.pr_id					=  b.pr_id
		and A.APL_TO_PRP_ID			=  b.APL_TO_PRP_ID
		and A.service_provision		=  b.service_provision
		and A.prp_eff_frm_dt		=  b.prp_eff_frm_dt
		and isnull(A.prp_eff_to_dt,'')			=  isnull(b.prp_eff_to_dt,'')
		order by 1,2,3,40,8,9,10,6,5

-- Step 3: Create the final result
SET @Step3Time = SYSDATETIME();
	
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


		
		
			IF (XACT_STATE())	=	1
			BEGIN
				COMMIT TRANSACTION;
			END;

			IF (XACT_STATE())	= - 1
			BEGIN
				ROLLBACK TRANSACTION;
			END
			RAISERROR(@MESSAGE, @SEVERITY, 1, @NUMBER, @SEVERITY, @STATE, @PROCEDURE, @LINE);
		 END CATCH
		
--	End	



	

-- Capture end time
SET @EndTime = SYSDATETIME();


-- Calculate durations in milliseconds
DECLARE @Duration1 INT = DATEDIFF(MILLISECOND, @StartTime, @Step1Time);
DECLARE @Duration2 INT = DATEDIFF(MILLISECOND, @Step1Time, @Step2Time);
DECLARE @Duration3 INT = DATEDIFF(MILLISECOND, @Step2Time, @Step3Time);
DECLARE @TotalDuration INT = DATEDIFF(MILLISECOND, @StartTime, @EndTime);

-- Calculate percentages
DECLARE @Pct1 DECIMAL(5,2) = (CAST(@Duration1 AS DECIMAL(10,2)) / @TotalDuration) * 100;
DECLARE @Pct2 DECIMAL(5,2) = (CAST(@Duration2 AS DECIMAL(10,2)) / @TotalDuration) * 100;
DECLARE @Pct3 DECIMAL(5,2) = (CAST(@Duration3 AS DECIMAL(10,2)) / @TotalDuration) * 100;


-- Print summary
PRINT '--- Execution Time Summary ---';
PRINT 'Step 1 Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @Step1Time) AS VARCHAR) + ' ms';
PRINT 'Step 2 Duration: ' + CAST(DATEDIFF(MILLISECOND, @Step1Time, @Step2Time) AS VARCHAR) + ' ms';
PRINT 'Step 3 Duration: ' + CAST(DATEDIFF(MILLISECOND, @Step2Time, @Step3Time) AS VARCHAR) + ' ms';
PRINT 'Total Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR) + ' ms';




-- Print summary
PRINT '--- Execution Time Summary ---';
PRINT 'Step 1 Duration: ' + CAST(@Duration1 AS VARCHAR) + ' ms (' + CAST(@Pct1 AS VARCHAR) + '%)';
PRINT 'Step 2 Duration: ' + CAST(@Duration2 AS VARCHAR) + ' ms (' + CAST(@Pct2 AS VARCHAR) + '%)';
PRINT 'Step 3 Duration: ' + CAST(@Duration3 AS VARCHAR) + ' ms (' + CAST(@Pct3 AS VARCHAR) + '%)';
PRINT 'Total Duration: ' + CAST(@TotalDuration AS VARCHAR) + ' ms';

