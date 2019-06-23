***************************************************************************************************************
* HRS-linked Medicare claims snalyses for research letter examining Medicaid/LIS enrollment as a function of
*  income.  Analyses prepared for a research letter targeting JAMA/JAMA-IM
* Eric Roberts, University of Pittsburgh (eric.roberts@pitt.edu)
* June 20, 2019
***************************************************************************************************************

clear all
cd "C:\Users\HRSdata\Desktop\HRS\HRS Analyses\Analytic files"
use hrs_mcare_mcaid_merged_2.dta, clear


***************************************************************************************************************
** Define some parameters
***************************************************************************************************************

global donut 3
global bw 100
global nplotquantiles 25
global yearfrom 2013
global maxincome 135 // in pp of the FPL

global medicaid_income_var 			inc_fpl_mcd_x_ssi // inc_fpl_mcd_x_ssi
global msp_income_var 				inc_fpl_msp_x_ssi // inc_fpl_qmb_x_ssi
global lis_income_var 				inc_fpl_lis_x_ssi // inc_fpl_lis_x_ssi
global fixed_income_var				fixed_income_ind_x_ssi //  fixed_income_ind_x_ssi

global medicaid_income_diff_var 	inc_diff_mcd_x_ssi 		// inc_diff_mcd_x_ssi
global qmb_income_diff_var 			inc_diff_qmb_x_ssi 		// inc_diff_qmb_x_ssi
global slmb_income_diff_var 		inc_diff_slmb_x_ssi 	// inc_diff_slmb_x_ssi
global qi_income_diff_var 			inc_diff_qi_x_ssi 		// inc_diff_qi_x_ssi
global lis_full_income_diff_var 	inc_diff_lis_full_x_ssi // inc_diff_lis_full_x_ssi
global lis_part_income_diff_var 	inc_diff_lis_part_x_ssi // inc_diff_lis_part_x_ssi


***************************************************************************************************************
** Data management and define analytic sample
***************************************************************************************************************

* Exclusions:
	* Keep HRS waves 11-12 only, limiting to benes in MBSF, and excluding benes with income >135% of FPL
		keep if year>=2013 & (hrs_wave==11 | hrs_wave==12) & in_mbsf==1 & $medicaid_income_var <= $maxincome
		tab2 year hrs_wave, missing
		
	* Exclusions of states:
		tab stateusps, missing
		* Exclude people in DC -- DC's QMB program subsumes SLMB and QI and the QMB eligibility threshold is effectively coterminuous with the LIS threshold
		drop if stateusps=="DC"
		* Exclude people in CD -- eligibility thresholds in CT differ by region and we can't model that in LIS
		drop if stateusps=="CT"
		* Exclude Maine -- additional income disregards for MSPs
		drop if stateusps=="ME"

	* Exclude individuals receiving retiree drug subsidies -- will eliminate observations predating the MBSF (which contains RDS indicators)
		tab2 any_rds year, missing
		keep if any_rds==0

	* Exclude Medicare Advantage recipients
		tab2 medicare_advantage year, missing
		*keep if medicare_advantage==0
		
	* Exclude individuals with any household business income (~1% of obs, but ambiguous to categorize)
		tab2 any_hhbiz_inc year, missing
		*keep if any_hhbiz_inc==0

* Look at waves and years represented
tab2 hrs_wave year, missing
tab2 year survey_yr, mis // if year=survry_yr, then I linked Medicare enrollment data to contemporaneous HRS.  Otherwise, I would have linked Medicare enrollment data from the previous year to the HRS (since HRS asks about income in previous year)

* Check distribution of HH dependents
tab hh_dep if year>=$yearfrom

* Top and bottom code countable assets at 1st and 99th percentiles
summ countable_asset, d
scalar p1=r(p1)
scalar p99=r(p99)
gen countable_asset_t=countable_asset if p1<=countable_asset & countable_asset<=p99
replace countable_asset_t=p1  if countable_asset<p1
replace countable_asset_t=p99 if countable_asset>p99
summ countable_asset_t, d

* Construct indicator that the state's QMB and Medicaid income eligibility thresholds are both 100% of FPL
gen mcd_qmb_thold_100_flag=(mcd_inc_t==100 & qmb_inc_t==100) // recall I've aligned income eligibility thresholds with the year for which income was assessed (year prior to interview)
tab2 stateusps year if mcd_qmb_thold_100_flag

* Make a numeric state ID
bys stateusps: gen statenum=1 if _n==1
replace statenum=sum(statenum)
	
* Flag states with higher MSP thresholds
	gen flagstate_msp=(qmb_inc_t>100)  // states with expanded MSP eligibility thresholds
	tab2 stateusps flagstate_msp, missing

* Pooled any full Medicaid indicators
	gen any_buyin_full_mcd=max(any_buyin_qmb_plus,any_buyin_slmb_plus,any_buyin_oth_full)
	tab2 any_buyin_full_mcd any_buyin_qmb_plus, missing
	tab2 any_buyin_full_mcd any_buyin_slmb_plus, missing
	tab2 any_buyin_full_mcd any_buyin_oth_full, missing	

	gen max_any_buyin_full_mcd=max(max_any_buyin_qmb_plus,max_any_buyin_slmb_plus,max_any_buyin_oth_full)
	tab2 max_any_buyin_full_mcd max_any_buyin_qmb_plus, missing
	tab2 max_any_buyin_full_mcd max_any_buyin_slmb_plus, missing
	tab2 max_any_buyin_full_mcd max_any_buyin_oth_full, missing		

* Pooled QMB and SLMB/SLMB+QI buy-in indicators	
	gen any_buyin_qmb=max(any_buyin_qmb_only, any_buyin_qmb_plus)
	tab2 any_buyin_qmb any_buyin_qmb_plus, missing
	tab2 any_buyin_qmb any_buyin_qmb_only, missing

	gen max_any_buyin_qmb=max(max_any_buyin_qmb_only, max_any_buyin_qmb_plus)
	tab2 max_any_buyin_qmb max_any_buyin_qmb_plus, missing
	tab2 max_any_buyin_qmb max_any_buyin_qmb_only, missing
	
	gen any_buyin_slmb=max(any_buyin_slmb_only, any_buyin_slmb_plus)
	tab2 any_buyin_slmb any_buyin_slmb_plus, missing
	tab2 any_buyin_slmb any_buyin_slmb_only, missing	

	gen max_any_buyin_slmb=max(max_any_buyin_slmb_only, max_any_buyin_slmb_plus)
	tab2 max_any_buyin_slmb max_any_buyin_slmb_plus, missing
	tab2 max_any_buyin_slmb max_any_buyin_slmb_only, missing	
	
	gen any_buyin_slmb_qi=max(any_buyin_slmb_only, any_buyin_qi)	
	tab2 any_buyin_slmb_qi any_buyin_slmb_only, missing
	tab2 any_buyin_slmb_qi any_buyin_qi, missing	
	
	gen max_any_buyin_slmb_qi=max(max_any_buyin_slmb_only, max_any_buyin_qi)	
	tab2 max_any_buyin_slmb_qi max_any_buyin_slmb_only, missing
	tab2 max_any_buyin_slmb_qi max_any_buyin_qi, missing	
	
* Create indicators that individuals were above relevant thresholds
	gen above_mcd_threshold=($medicaid_income_diff_var>0)
	gen above_qmb_threshold=($qmb_income_diff_var>0)
	gen above_slmb_threshold =($slmb_income_diff_var>0)
	gen above_qi_threshold =($qi_income_diff_var>0)
	gen above_lis_full_threshold=($lis_full_income_diff_var>0)
	gen above_lis_part_threshold=($lis_part_income_diff_var>0)

* Create indicators that individuals were below relevant thresholds
	gen below_mcd_threshold=($medicaid_income_diff_var<0)
	gen below_qmb_threshold=($qmb_income_diff_var<0)
	gen below_slmb_threshold =($slmb_income_diff_var<0)
	gen below_qi_threshold =($qi_income_diff_var<0)
	gen below_lis_full_threshold=($lis_full_income_diff_var<0)
	gen below_lis_part_threshold=($lis_part_income_diff_var<0)
	
* Binary indicator for receiving any partial Medicaid
	gen any_buyin_partial=(any_buyin_qmb_only==1 | any_buyin_slmb_only==1 | any_buyin_qi==1)

* Binary indicator for receiving any SSI income
gen any_ssi_income=(ssi_income>0)
tab2 below_mcd_threshold any_ssi_income, missing row col
tab2 below_mcd_threshold any_ssi_income if mcd_inc_t<=75, missing row col

* Assess maximum sample sizes around eligibility thresholds
	* Around Medicaid eligibility threshold -- only states where the Medicaid eligibility threshold is unique from the QMB threshold
	gen in_mcd_thold_analysis=($qmb_income_diff_var<0 & mcd_qmb_thold_100_flag==0)
	tab2 above_mcd_threshold mcd_qmb_thold_100_flag if in_mcd_thold_analysis==1, missing
	
	* Around QMB eligibility threshold (with/without the coterminous Medicaid threshold, identified via mcd_qmb_thold_100_flag)
	gen in_qmb_thold_analysis=(($qi_income_diff_var<0 & mcd_qmb_thold_100_flag==1) | ($medicaid_income_diff_var>0 & $qi_income_diff_var<0 & mcd_qmb_thold_100_flag==0))
	tab2 above_qmb_threshold mcd_qmb_thold_100_flag if in_qmb_thold_analysis==1, missing
	
	* Around QI/full LIS eligibility threshold (with/without coterminous full LIS threshold)
	gen in_qi_thold_analysis=(($qmb_income_diff_var>0 & $lis_part_income_diff_var<0 & any_hh_dep==0) | ($qmb_income_diff_var>0 & $lis_full_income_diff_var<0 & any_hh_dep==1))
	tab2 above_qi_threshold any_hh_dep if in_qi_thold_analysis==1, missing
	
	gen in_lis_full_thold_analysis=(($qmb_income_diff_var>0 & $lis_part_income_diff_var<0)) // edited out the dependent distinction on 6/9/2019 after I corrected the dependent calculation.... & any_hh_dep==0) | ($qi_income_diff_var>0 & $lis_part_income_diff_var<0 & any_hh_dep==1))
	tab2 above_lis_full_threshold any_hh_dep if in_lis_full_thold_analysis==1, missing
	
	* Around partial LIS eligibility threshold
	gen in_lis_part_thold_analysis=($lis_full_income_diff_var>0)
	tab2 above_lis_part_threshold above_qi_threshold if in_lis_part_thold_analysis==1, missing
	tab stateusps if above_qi_threshold==0 & in_lis_part_thold_analysis==1 // some folks from ME & IN appear in sample because their QI eligibility threshold is higher than 135% of FPL

	gen in_lis_thold_analysis=(in_lis_full_thold_analysis==1 | in_lis_part_thold_analysis==1)

	
***************************************************************************************************************
** Examine program eligibility thresholds, and sample sizes available for RD analysis around these thresholds
***************************************************************************************************************

*** Medicaid and QMB thresholds ***********************************************
*tab2 in_qmb_thold_analysis in_mcd_thold_analysis if in_qmb_thold_analysis==1, missing // Mcd threshold analytic sample is subset of QMB threshold analytic sample

	* Plot income relative to Medicaid and QMB thresholds
		twoway	(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==1 & flagstate_msp==0, mcolor(navy) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==0 & flagstate_msp==0, mcolor(maroon) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & flagstate_msp==1, xline(0) yline(0) mcolor(sand) msize(vsmall) ///
				title("Distribution of income relative to" "full Medicaid and QMB eligibility thresholds") ///
				ytitle("Income relative to QMB elig. threshold") xtitle("Income relative to full Medicaid elig. threshold") ///
				legend(lab(1 "Mcd=MSP=100% FPL") lab(2 "Mcd<MSP=100% FPL") lab(3 "States with expanded MSPs")) note("States with expanded MSPs: CT, DC, IN, ME."  "Income in percentage points of the FPL, counted using SSI methodology (single or couple households)."))
		graph export medicaid_msp_gph.png, replace

	* Overlay RD subsamples
		gen in_donut_mcd=(($medicaid_income_diff_var<0 & $medicaid_income_diff_var>-$donut) | ($medicaid_income_diff_var>0 & $medicaid_income_diff_var<$donut))
		gen in_donut_qmb=(($qmb_income_diff_var<0 & $qmb_income_diff_var>-$donut) | ($qmb_income_diff_var>0 & $qmb_income_diff_var<$donut))
		gen t_mcd=(in_mcd_thold_analysis==1 & ($medicaid_income_diff_var>-$bw & $medicaid_income_diff_var<$bw)) * (1-in_donut_mcd)
		gen t_qmb=(in_qmb_thold_analysis==1 & ($qmb_income_diff_var>-$bw & $qmb_income_diff_var<$bw)) * (1-in_donut_qmb)
		tab2 above_mcd_threshold mcd_qmb_thold_100_flag if t_mcd==1
		tab2 above_qmb_threshold mcd_qmb_thold_100_flag if t_qmb==1

		qui summ above_mcd_threshold if t_mcd==1 // eligibility threshold isolating effect of full Medicaid limited to states without coterminuous Medicaid and QMB thresholds
		local n_mcd=r(N)
		qui summ above_qmb_threshold if t_qmb==1 & mcd_qmb_thold_100_flag==1
		local n_qmb_plus_mcd=r(N)
		qui summ above_qmb_threshold if t_qmb==1 & mcd_qmb_thold_100_flag==0
		local n_qmb_only=r(N)
	
		// Note on this graph: plotting on the range of in_qmb_thhold_analysis for comparability with prior grants
		twoway	(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==1 & flagstate_msp==0, mcolor(navy) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==0 & flagstate_msp==0, mcolor(maroon) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & flagstate_msp==1, xline(0) yline(0) mcolor(sand) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & t_mcd==1, mcolor(dkgreen) msymbol(Oh) msize(vsmall) ///
				title("Distribution of income relative to" "full Medicaid and QMB eligibility thresholds") ///
				ytitle("Income relative to QMB elig. threshold") xtitle("Income relative to full Medicaid elig. threshold") ///
				legend(lab(1 "Mcd=MSP=100% FPL") lab(2 "Mcd<MSP=100% FPL") lab(3 "States with expanded MSPs") lab(4 "RD: Medicaid only")) ///
				note("States with expanded MSPs: CT, DC, IN, ME."  "Income in percentage points of the FPL, counted using SSI methodology (single or couple households)." "RD N for Medicaid only threshold=`n_mcd' at bw up to +/- $bw."))
		graph export medicaid_msp_gph_rd_mcd.png, replace
		
		tab2 above_mcd_threshold mcd_qmb_thold_100_flag if t_mcd==1 // model 1
		tab2 above_mcd_threshold mcd_qmb_thold_100_flag if t_mcd==1 & year>=$yearfrom // model 1
		
		twoway	(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==1 & flagstate_msp==0, mcolor(navy) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==0 & flagstate_msp==0, mcolor(maroon) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & flagstate_msp==1, xline(0) yline(0) mcolor(sand) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==1 & t_qmb==1 , mcolor(dkgreen) msymbol(Oh) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==0 & t_qmb==1 , mcolor(mint) msymbol(Oh) msize(vsmall) ///
				title("Distribution of income relative to" "full Medicaid and QMB eligibility thresholds") ///
				ytitle("Income relative to QMB elig. threshold") xtitle("Income relative to full Medicaid elig. threshold") ///
				legend(lab(1 "Mcd=MSP=100% FPL") lab(2 "Mcd<MSP=100% FPL") lab(3 "States with expanded MSPs") lab(4 "RD: QMB with Medicaid") lab(5 "RD: QMB without Medicaid")) ///
				note("States with expanded MSPs: CT, DC, IN, ME."  "Income in percentage points of the FPL, counted using SSI methodology (single or couple households)." "RD N for: QMB only threshold=`n_qmb_only', QMB+Mcd threshold=`n_qmb_plus_mcd' at bw up to +/- $bw."))
		graph export medicaid_msp_gph_rd_qmb.png, replace

		tab2 above_qmb_threshold mcd_qmb_thold_100_flag if t_qmb==1 // models 2a-2b
		tab2 above_qmb_threshold mcd_qmb_thold_100_flag if t_qmb==1 & year>=$yearfrom // models 2a-2b

		
***************************************************************************************************************
** Analyses for JAMA Letter
***************************************************************************************************************


	***** Full Medicaid / Full LIS enrollment relative to full Medicaid elig threshold  ******************************
	gen runvar1 = round($medicaid_income_diff_var/10,1)*10
		* Force override to collapse small groups
			replace runvar1 = -90 if runvar1==-80 | runvar1==-90 | runvar1==-100
			replace runvar1 = -65 if runvar1==-60 | runvar1==-70
			replace runvar1 = -45 if runvar1==-40 | runvar1==-50
		
	table runvar1 if asset_below_mcd==1 & runvar1<60, c(n $medicaid_income_diff_var  min $medicaid_income_diff_var max $medicaid_income_diff_var mean any_full_lis)
	
		binscatter any_buyin         runvar1 if asset_below_mcd==1 & runvar1<60 [fweight=hrs_weight_cmty], line(connect) xline(0, lcolor(gs10) lpattern(dash)) ylab(0(0.2)1) savedata(any_buyin_gph) replace ///
			title("Any Medicaid Enrollment") ytitle("Proportion enrolled in Medicaid (full or partial)") xtitle("Income (percentage points of FPL) relative to state-specific ABD eligibility threshold") note("Conditional on meeting resource limits for full Medicaid." "FPL is based on a one- or two-person family (SSI standard).")
		graph export full_mcd_1.png, replace
		
		binscatter any_buyin_full    runvar1 if asset_below_mcd==1 & runvar1<60 [fweight=hrs_weight_cmty], line(connect) xline(0, lcolor(gs10) lpattern(dash)) ylab(0(0.2)1) savedata(any_buyin_gph) replace ///
			title("Full Medicaid Enrollment") ytitle("Proportion enrolled in full Medicaid") xtitle("Income (percentage points of FPL) relative to state-specific ABD eligibility threshold") note("Conditional on meeting resource limits for full Medicaid." "FPL is based on a one- or two-person family (SSI standard).")
		graph export full_mcd_2.png, replace

		binscatter any_full_lis      runvar1 if asset_below_mcd==1 & runvar1<60 [fweight=hrs_weight_cmty], line(connect) xline(0, lcolor(gs10) lpattern(dash)) ylab(0(0.2)1) savedata(any_buyin_gph) replace ///
			title("Part D LIS Enrollment") ytitle("Proportion receiving the full LIS") xtitle("Income (percentage points of FPL) relative to state-specific ABD eligibility threshold") note("Conditional on meeting resource limits for full Medicaid." "FPL is based on a one- or two-person family (SSI standard).")
		graph export full_mcd_3.png, replace

		mean any_buyin if asset_below_mcd==1 & runvar1<60 [pweight=hrs_weight_cmty], over(runvar1)
			/*corresp samp sizes*/ table runvar1 if asset_below_mcd==1 & runvar1<60
			
		mean any_buyin_full if asset_below_mcd==1 & runvar1<60 [pweight=hrs_weight_cmty], over(runvar1)
		mean any_full_lis if asset_below_mcd==1 & runvar1<60 [pweight=hrs_weight_cmty], over(runvar1)
		
		reg any_buyin above_mcd_threshold $medicaid_income_diff_var male age_64under age_70_74 age_75_79 age_80_84 age_85plus orec_disabled curr_esrd ccw_eq_2 ccw_eq_3 ccw_eq_4 ccw_eq_5 ccw_6up medicare_advantage i.year if asset_below_mcd==1 [pweight=hrs_weight_cmty], vce(cluster statenum)
		reg any_full_lis above_mcd_threshold $medicaid_income_diff_var male age_64under age_70_74 age_75_79 age_80_84 age_85plus orec_disabled curr_esrd ccw_eq_2 ccw_eq_3 ccw_eq_4 ccw_eq_5 ccw_6up medicare_advantage i.year if asset_below_mcd==1 [pweight=hrs_weight_cmty], vce(cluster statenum)
		
		egen totn1=sum(hrs_weight_cmty) if asset_below_mcd==1
		summ totn1 inc_fpl_mcd_x_ssi if asset_below_mcd==1
		******************************************************************************************************************

	
	***** Partial Medicaid / Full LIS enrollment relative to partial Medicaid elig threshold  ************************
	gen runvar2 = round(inc_fpl_mcd_x_ssi/5,1)*5
		* Force override to collapse small groups
			replace runvar2 = 12.5 if runvar2==5  | runvar2==10 | runvar2==15 | runvar2==20
			replace runvar2 = 30   if runvar2==25 | runvar2==30 | runvar2==35
			replace runvar2 = 45   if runvar2==40 | runvar2==45 | runvar2==50
			replace runvar2 = 60   if runvar2==55 | runvar2==60 | runvar2==65
			
	table runvar2 if asset_below_msp==1, c(n inc_fpl_mcd_x_ssi min inc_fpl_mcd_x_ssi max inc_fpl_mcd_x_ssi mean any_full_lis)

		binscatter any_buyin           runvar2 if $medicaid_income_diff_var>0 & asset_below_msp==1 & runvar2>60 [fweight=hrs_weight_cmty], discrete line(connect) xline(100, lcolor(gs10) lpattern(dash)) ylab(0(0.2)1) savedata(any_buyin_gph) replace ///
			title("Any Medicaid Enrollment") ytitle("Proportion enrolled in Medicaid (full or partial)") xtitle("Income in percentage points of FPL") note("Among beneficiaries who are ineligible for full Medicaid based on income." "Conditional on meeting resource limits for partial Medicaid." "FPL is based on a one- or two-person family (SSI standard).")
		graph export part_mcd_1.png, replace
		
		binscatter any_buyin_partial   runvar2 if $medicaid_income_diff_var>0 & asset_below_msp==1 & runvar2>60 [fweight=hrs_weight_cmty], discrete line(connect) xline(100, lcolor(gs10) lpattern(dash)) ylab(0(0.2)1) savedata(any_buyin_gph) replace ///
			title("Partial Medicaid Enrollment") ytitle("Proportion enrolled in partial Medicaid") xtitle("Income in percentage points of FPL") note("Among beneficiaries who are ineligible for full Medicaid based on income." "Conditional on meeting resource limits for full Medicaid." "FPL is based on a one- or two-person family (SSI standard).")
		graph export part_mcd_2.png, replace

		binscatter any_full_lis        runvar2 if $medicaid_income_diff_var>0 & asset_below_msp==1 & runvar2>60 [fweight=hrs_weight_cmty], discrete line(connect) xline(100, lcolor(gs10) lpattern(dash)) ylab(0(0.2)1) savedata(any_buyin_gph) replace ///
			title("Part D LIS Enrollment") ytitle("Proportion receiving the full LIS") xtitle("Income in percentage points of FPL") note("Among beneficiaries who are ineligible for full Medicaid based on income." "Conditional on meeting resource limits for partial Medicaid." "FPL is based on a one- or two-person family (SSI standard).")
		graph export part_mcd_3.png, replace
		
		mean any_buyin if asset_below_msp==1 [pweight=hrs_weight_cmty], over(runvar2)
			/*corresp samp sizes*/ table runvar2 if asset_below_msp==1
			
		mean any_buyin_full if asset_below_msp==1 [pweight=hrs_weight_cmty], over(runvar2)
			/*corresp samp sizes*/ table runvar2 if asset_below_msp==1
			
		mean any_buyin_partial if asset_below_msp==1 & $medicaid_income_diff_var>0 [pweight=hrs_weight_cmty], over(runvar2)
			/*corresp samp sizes*/ table runvar2 if asset_below_msp==1 & $medicaid_income_diff_var>0
		
		mean any_full_lis if asset_below_msp==1 [pweight=hrs_weight_cmty], over(runvar2)
		
		reg any_buyin above_qmb_threshold $qmb_income_diff_var male age_64under age_70_74 age_75_79 age_80_84 age_85plus orec_disabled curr_esrd ccw_eq_2 ccw_eq_3 ccw_eq_4 ccw_eq_5 ccw_6up medicare_advantage i.year if asset_below_msp==1 [pweight=hrs_weight_cmty], vce(cluster statenum)
		reg any_full_lis above_qmb_threshold $qmb_income_diff_var male age_64under age_70_74 age_75_79 age_80_84 age_85plus orec_disabled curr_esrd ccw_eq_2 ccw_eq_3 ccw_eq_4 ccw_eq_5 ccw_6up medicare_advantage i.year if asset_below_msp==1 [pweight=hrs_weight_cmty], vce(cluster statenum)

		egen totn2=sum(hrs_weight_cmty) if asset_below_msp==1
		summ totn2 inc_fpl_mcd_x_ssi if asset_below_msp==1
	******************************************************************************************************************

