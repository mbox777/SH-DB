
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
