--	USE [RPTeBS_enGen_SHC_DEV]
--	GO

USE RPTeBS_enGen_UAT
go

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

if object_id('Temp.mbwNew_PRPHOptions')				is     null begin
	PRINT 'CREATING TABLE 1'
	-- Create the first table		DROP TABLE [Temp].[mbwNew_PRPHOptions]
		CREATE TABLE [Temp].[mbwNew_PRPHOptions](
			[PRPH_REC_ID]					[bigint]			NOT NULL,	-- Clusterd pk

			[pr_id]							[bigint]			NOT NULL,
			[TemplateType]					[varchar](150)			NULL,	-- was NOT NULL,
			[ProductType]					[varchar](150)			NULL,
			[apl_to_prp_ord_n]				[bigint]				NULL,
			[apl_to_prp_id]					[bigint]				NULL,
			[prp_id]						[bigint]			NOT NULL,
			[Service Name]					[varchar](max)			NULL,
			[Network Name]					[varchar](150)			NULL,
			[SERVICE_PROVISION]				[varchar](150)			NULL,
			[sv_id]							[bigint]			NOT NULL,
			[prp_stus_c]					[varchar](1)		NOT NULL,
			[prp_eff_frm_dt]				[datetime2](7)		NOT NULL,
			[prp_eff_to_dt]					[datetime2](7)			NULL,
			[Qualifier]						[varchar](150)			NULL,
			[LineType]						[varchar](150)			NULL,
			[Value Relativity(COPVT)]		[varchar](150)			NULL,
			[Value Unit(COPVU)]				[varchar](150)			NULL,
			[prp_vlu]						[varchar](50)			NULL,
			[mnm_prp_vlu]					[decimal](11, 2)		NULL,
			[max_prp_vlu]					[decimal](11, 2)		NULL,
			[prp_prd_vincrm_vlu]			[decimal](5, 2)			NULL,
			[TextValue (PRPTV)]				[varchar](100)			NULL,
			[prp_vlu_t_set_id]				[bigint]				NULL,
			[Applies To (COPPR)]			[varchar](150)			NULL,
			[Depends On (COPPR)]			[varchar](150)			NULL,
			[Standardization level (COBSL)] [varchar](150)			NULL,
			[Value Type(COPVC)]				[varchar](150)			NULL,
			[Period Type(COPPVC)]			[varchar](150)			NULL,
			[Period Unit(COPPVU)]			[varchar](150)			NULL,
			[Period Number(PRP_PRD_VLU)]	[smallint]				NULL,
			[Period TextValue(PRPPTV)]		[varchar](100)			NULL,
			[Period TextSet]				[bigint]				NULL,
			[Period Min]					[smallint]				NULL,
			[Period Max]					[smallint]				NULL,
			[Period Increment Value]		[decimal](14, 2)		NULL,
			[deps_on_prp_id]				[bigint]				NULL,
			[deps_on_prp_ord_n]				[bigint]				NULL,
			[prp_inter_dep_prp_id]			[bigint]				NULL,
			[prp_lim_for_prp_id]			[bigint]				NULL,
			[prph_prsn_ord_n]				[bigint]				NULL,
			[TextOption]					[varchar](250)			NULL

			-- Extra fields needed to run Master.GetProvisionTextOptions() func 
		,	[prp_vlu_InOrigDecimal]			[decimal](11,2)			NULL
		,	[options]						[nvarchar](max)			NULL
			-- Extra fields from [MASTER].[prph_product_provision_history_1015] to get lookup values
		,	[BNT_ID]						[bigint]				NULL
		,	[PRP_TYP_C]						[bigint]				NULL
		,	[PRP_TYP_QLFR_C]				[bigint]				NULL
		,	[PRP_LIN_TYP_C]					[bigint]				NULL
		,	[PRP_STDZ_LVL_C] 				[bigint]				NULL
		,	[PRP_VLU_CLMN_C] 				[bigint]				NULL
		,	[PRP_VLU_TYP_C] 				[bigint]				NULL
		,	[P_PRP_VLU_T_ID] 				[bigint]				NULL
		,	[APL_TO_PRP_REL_C] 				[bigint]				NULL
		,	[DEPS_ON_PRP_REL_C] 			[bigint]				NULL
		,	[PRP_VLU_T_ID] 					[bigint]				NULL
		,	[PRP_VLU_UOM_C] 				[bigint]				NULL
		,	[PRP_PRD_VLU_CLMN_C] 			[bigint]				NULL
		,	[PRP_PRD_VLU_UOM_C] 			[bigint]				NULL





		CONSTRAINT [mbwNew_PRPHOptions_PK] PRIMARY KEY CLUSTERED  ( [PRPH_REC_ID] ASC )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

	-- Create indexes to make the join faster for the SP 
	CREATE NONCLUSTERED INDEX Temp__mbwNew_PRPHOptions__Idx_to_B   ON [Temp].[mbwNew_PRPHOptions] (bnt_id)
	CREATE NONCLUSTERED INDEX Temp__mbwNew_PRPHOptions__Idx_to_B2  ON [Temp].[mbwNew_PRPHOptions] ( prp_typ_c						)
	CREATE NONCLUSTERED INDEX Temp__mbwNew_PRPHOptions__Idx_to_B3  ON [Temp].[mbwNew_PRPHOptions] ( prp_typ_qlfr_c					)
	CREATE NONCLUSTERED INDEX Temp__mbwNew_PRPHOptions__Idx_to_B4  ON [Temp].[mbwNew_PRPHOptions] ( prp_lin_typ_c					)
	CREATE NONCLUSTERED INDEX Temp__mbwNew_PRPHOptions__Idx_to_B5  ON [Temp].[mbwNew_PRPHOptions] ( prp_stdz_lvl_c					)
	CREATE NONCLUSTERED INDEX Temp__mbwNew_PRPHOptions__Idx_to_B6  ON [Temp].[mbwNew_PRPHOptions] ( prp_vlu_clmn_c					)
	CREATE NONCLUSTERED INDEX Temp__mbwNew_PRPHOptions__Idx_to_B7  ON [Temp].[mbwNew_PRPHOptions] ( prp_vlu_typ_c					)
	CREATE NONCLUSTERED INDEX Temp__mbwNew_PRPHOptions__Idx_to_B8  ON [Temp].[mbwNew_PRPHOptions] ([Period TextSet], p_prp_vlu_t_id	)
	CREATE NONCLUSTERED INDEX Temp__mbwNew_PRPHOptions__Idx_to_B9  ON [Temp].[mbwNew_PRPHOptions] (apl_to_prp_rel_c					)
	CREATE NONCLUSTERED INDEX Temp__mbwNew_PRPHOptions__Idx_to_B10 ON [Temp].[mbwNew_PRPHOptions] (deps_on_prp_rel_c				)
	CREATE NONCLUSTERED INDEX Temp__mbwNew_PRPHOptions__Idx_to_B11 ON [Temp].[mbwNew_PRPHOptions] ([prp_vlu_t_set_id],[PRP_VLU_T_ID])
	CREATE NONCLUSTERED INDEX Temp__mbwNew_PRPHOptions__Idx_to_B12 ON [Temp].[mbwNew_PRPHOptions] (prp_vlu_uom_c					)
	CREATE NONCLUSTERED INDEX Temp__mbwNew_PRPHOptions__Idx_to_B13 ON [Temp].[mbwNew_PRPHOptions] (prp_prd_vlu_clmn_c				)
	CREATE NONCLUSTERED INDEX Temp__mbwNew_PRPHOptions__Idx_to_B14 ON [Temp].[mbwNew_PRPHOptions] (prp_prd_vlu_uom_c				)

	PRINT 'Table 1 created'
end 
if object_id('Temp.mbwNew_FullProvisionOption')		is     null  begin

	print 'table 2 create not ready'

end 
if object_id('Temp.mbwNew_FinalProvisionOptions')	is     null  begin

	print 'table 3 create not ready'


end 


GO

select count(1) from  [Temp].[mbw_PRPHOptions]
select count(1) from  [Temp].[mbwNew_PRPHOptions]
select [Network Name], count(1) from [Temp].[mbwNew_PRPHOptions] group by [Network Name]


