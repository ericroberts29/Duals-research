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

global medicaid_income_var 			inc_fpl_mcd_x_ssi // inc_fpl_mcd_x_ssi
global msp_income_var 				inc_fpl_msp_x_ssi // inc_fpl_qmb_x_ssi
global lis_income_var 				inc_fpl_lis_x_ssi // inc_fpl_lis_x_ssi
global fixed_income_var				fixed_income_ind_x_ssi //  fixed_income_ind_x_ssi

global medicaid_income_diff_var 	inc_diff_mcd_x_ssi 		// inc_diff_mcd_x_ssi
global qmb_income_diff_var 			inc_diff_qmb_x_ssi 		// inc_diff_qmb_x_ssi
global qmb_income_diff_var_ca		qmb_income_diff_var_ca  //=inc_diff_qmb_x_ssi if stateusps!="CA" and =inc_diff_mcd_x_ssi if stateusps=="CA"
global slmb_income_diff_var 		inc_diff_slmb_x_ssi 	// inc_diff_slmb_x_ssi
global qi_income_diff_var 			inc_diff_qi_x_ssi 		// inc_diff_qi_x_ssi
global lis_full_income_diff_var 	inc_diff_lis_full_x_ssi // inc_diff_lis_full_x_ssi
global lis_part_income_diff_var 	inc_diff_lis_part_x_ssi // inc_diff_lis_part_x_ssi


***************************************************************************************************************
** Data management and define analytic sample
***************************************************************************************************************

* Exclusions:

	* Exclusions of states
		* Exclude people in DC -- DC's QMB program subsumes SLMB and QI and the QMB eligibility threshold is effectively coterminuous with the LIS threshold
		drop if stateusps=="DC"
		* Exclude people in CD -- eligibility thresholds in CT differ by region and we can't model that in LIS
		drop if stateusps=="CT"
		* Exclude Maine -- additional income disregards for MSPs
		*drop if stateusps=="ME"

	* Exclude individuals >250% of FPL per LIS counting definition
		summ $medicaid_income_var $msp_income_var $lis_income_var if $lis_income_var <=250
		keep if $lis_income_var <=250
		tab $fixed_income_var, missing
		/* keep if $fixed_income_var==1 */

	* Exclude Medicare Advantage recipients
		keep if medicare_advantage==0
		
	* Exclude individuals receiving retiree drug subsidies -- will eliminate observations predating the MBSF (which contains RDS indicators)
		tab2 year any_rds, missing
		tab2 year hrs_wave, missing
		*keep if any_rds==0

	* Exclude individuals with any household business income (~1% of obs, but ambiguous to categorize)
		*keep if any_hhbiz_inc==0

* Check distribution of HH dependents
tab hh_dep if year>=$yearfrom

* Look at waves and years represented
tab in_mbsf, missing
tab2 hrs_wave year if in_mbsf==1, missing

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
	
* Construct an indicator for being above/below the QMB threshold OR the Mediciaid threshold in California (which disregards additional income to raise full Medicaid eligibility well above 100% of FPL)
	gen qmb_income_diff_var_ca=$qmb_income_diff_var if stateusps!="CA"
	replace qmb_income_diff_var_ca=$medicaid_income_diff_var if stateusps=="CA"
	gen above_qmb_threshold_ca=(($qmb_income_diff_var>0 & stateusps!="CA") | ($medicaid_income_diff_var>0 & stateusps=="CA")) // in California, treat the Medicaid income threshold as the QMB income threshold
	gen below_qmb_threshold_ca=(($qmb_income_diff_var<0 & stateusps!="CA") | ($medicaid_income_diff_var<0 & stateusps=="CA"))
	gen chk_below=($qmb_income_diff_var_ca<0)
	gen chk_above=($qmb_income_diff_var_ca>0)
	tab2 below_qmb_threshold_ca chk_below, missing
	tab2 above_qmb_threshold_ca chk_above, missing
	
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
	tab2 above_qmb_threshold_ca mcd_qmb_thold_100_flag if in_qmb_thold_analysis==1, missing

	* Around QI/full LIS eligibility threshold (with/without coterminous full LIS threshold)
	gen in_qi_thold_analysis=(($qmb_income_diff_var>0 & $lis_part_income_diff_var<0 & any_hh_dep==0) | ($qmb_income_diff_var>0 & $lis_full_income_diff_var<0 & any_hh_dep==1))
	tab2 above_qi_threshold any_hh_dep if in_qi_thold_analysis==1, missing
	
	gen in_lis_full_thold_analysis=(($qmb_income_diff_var>0 & $lis_part_income_diff_var<0)) // edited out the dependent distinction on 6/9/2019 after I corrected the dependent calculation.... & any_hh_dep==0) | ($qi_income_diff_var>0 & $lis_part_income_diff_var<0 & any_hh_dep==1))
	tab2 above_lis_full_threshold any_hh_dep if in_lis_full_thold_analysis==1, missing
	
	* Around partial LIS eligibility threshold
	gen in_lis_part_thold_analysis=($lis_full_income_diff_var>0)
	tab2 above_lis_part_threshold above_qi_threshold if in_lis_part_thold_analysis==1, missing
	tab stateusps if above_qi_threshold==0 & in_lis_part_thold_analysis==1 // some folks from ME, IN, and MS appear in sample because their QI eligibility threshold is higher than 135% of FPL

	gen in_lis_thold_analysis=(in_lis_full_thold_analysis==1 | in_lis_part_thold_analysis==1)
	tab2 above_lis_full_threshold above_lis_part_threshold if in_lis_thold_analysis==1, missing


***************************************************************************************************************
** Examine program eligibility thresholds, and sample sizes available for RD analysis around these thresholds
***************************************************************************************************************

*** Medicaid and QMB thresholds ***********************************************
*tab2 in_qmb_thold_analysis in_mcd_thold_analysis if in_qmb_thold_analysis==1, missing // Mcd threshold analytic sample is subset of QMB threshold analytic sample

	* Plot income relative to Medicaid and QMB thresholds
		twoway	(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==1 & flagstate_msp==0, mcolor(navy) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==1 & flagstate_msp==0 & stateusps=="CA", mcolor(bluishgray) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==0 & flagstate_msp==0, mcolor(maroon) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & flagstate_msp==1, xline(0) yline(0) mcolor(sand) msize(vsmall) ///
				title("Distribution of income relative to" "full Medicaid and QMB eligibility thresholds") ///
				ytitle("Income relative to QMB elig. threshold") xtitle("Income relative to full Medicaid elig. threshold") ///
				legend(lab(1 "Mcd=MSP=100% FPL") lab(2 "Mcd=MSP=100% FPL, CA") lab(3 "Mcd<MSP=100% FPL") lab(4 "States with expanded MSPs")) note("States with expanded MSPs: CT, DC, IN, ME."  "Income in percentage points of the FPL, counted using SSI methodology (single or couple households)." "California disregards additional income to increase Medicaid eligibility."))
		graph export medicaid_msp_gph.png, replace

	* Overlay RD subsamples
		gen in_donut_mcd   =(($medicaid_income_diff_var<0 & $medicaid_income_diff_var>-$donut) | ($medicaid_income_diff_var>0 & $medicaid_income_diff_var<$donut))
		gen in_donut_qmb   =(($qmb_income_diff_var<0 & $qmb_income_diff_var>-$donut) | ($qmb_income_diff_var>0 & $qmb_income_diff_var<$donut))
		gen in_donut_qmb_ca=((stateusps!="CA" & in_donut_qmb==1) | (stateusps=="CA" & in_donut_mcd==1))

		gen t_mcd    =(in_mcd_thold_analysis==1 & ($medicaid_income_diff_var>-$bw & $medicaid_income_diff_var<$bw)) * (1-in_donut_mcd)
		gen t_qmb    =(in_qmb_thold_analysis==1 & ($qmb_income_diff_var>-$bw & $qmb_income_diff_var<$bw)) * (1-in_donut_qmb)
		gen t_qmb_ca =(in_qmb_thold_analysis==1 & ((stateusps!="CA" & $qmb_income_diff_var>-$bw & $qmb_income_diff_var<$bw) | (stateusps=="CA" & $medicaid_income_diff_var>-$bw & $medicaid_income_diff_var<$bw))) * (1-in_donut_qmb_ca)
		
		tab2 above_mcd_threshold mcd_qmb_thold_100_flag if t_mcd==1
		tab2 above_qmb_threshold_ca mcd_qmb_thold_100_flag if t_qmb_ca==1

		qui summ above_mcd_threshold if t_mcd==1 // eligibility threshold isolating effect of full Medicaid limited to states without coterminuous Medicaid and QMB thresholds
		local n_mcd=r(N)
		qui summ above_qmb_threshold_ca if t_qmb_ca==1 & mcd_qmb_thold_100_flag==1
		local n_qmb_plus_mcd=r(N)
		qui summ above_qmb_threshold if t_qmb==1 & mcd_qmb_thold_100_flag==0
		local n_qmb_only=r(N)
	
		twoway	(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==1 & flagstate_msp==0, mcolor(navy) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==1 & flagstate_msp==0 & stateusps=="CA", mcolor(bluishgray) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==0 & flagstate_msp==0, mcolor(maroon) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & flagstate_msp==1, xline(0) yline(0) mcolor(sand) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & t_mcd==1, mcolor(dkgreen) msymbol(Oh) msize(vsmall) ///
				title("Distribution of income relative to" "full Medicaid and QMB eligibility thresholds") ///
				ytitle("Income relative to QMB elig. threshold") xtitle("Income relative to full Medicaid elig. threshold") ///
				legend(lab(1 "Mcd=MSP=100% FPL") lab(2 "Mcd=MSP=100% FPL, CA") lab(3 "Mcd<MSP=100% FPL") lab(4 "States with expanded MSPs") lab(5 "RD: Medicaid only")) ///
				note("States with expanded MSPs: CT, DC, IN, ME."  "Income in percentage points of the FPL, counted using SSI methodology (single or couple households)." "RD N for Medicaid only threshold=`n_mcd' at bw up to +/- $bw."))
		graph export medicaid_msp_gph_rd_mcd.png, replace

		tab2 above_mcd_threshold mcd_qmb_thold_100_flag if t_mcd==1 // model 1
		tab2 above_mcd_threshold mcd_qmb_thold_100_flag if t_mcd==1 & year>=$yearfrom // model 1

		twoway	(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==1 & flagstate_msp==0, mcolor(navy) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==1 & flagstate_msp==0 & stateusps=="CA", mcolor(bluishgray) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==0 & flagstate_msp==0, mcolor(maroon) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & flagstate_msp==1, xline(0) yline(0) mcolor(sand) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==1 & t_qmb_ca==1 , mcolor(dkgreen) msymbol(Oh) msize(vsmall)) ///
				(scatter $qmb_income_diff_var $medicaid_income_diff_var if (in_mcd_thold_analysis==1 | in_qmb_thold_analysis==1) & mcd_qmb_thold_100_flag==0 & t_qmb==1 , mcolor(mint) msymbol(Oh) msize(vsmall) ///
				title("Distribution of income relative to" "full Medicaid and QMB eligibility thresholds") ///
				ytitle("Income relative to QMB elig. threshold") xtitle("Income relative to full Medicaid elig. threshold") ///
				legend(lab(1 "Mcd=MSP=100% FPL") lab(2 "Mcd=MSP=100% FPL, CA") lab(3 "Mcd<MSP=100% FPL") lab(4 "States with expanded MSPs") lab(5 "RD: QMB with Medicaid") lab(6 "RD: QMB without Medicaid")) ///
				note("States with expanded MSPs: CT, DC, IN, ME."  "Income in percentage points of the FPL, counted using SSI methodology (single or couple households)." "RD N for: QMB only threshold=`n_qmb_only', QMB+Mcd threshold=`n_qmb_plus_mcd' at bw up to +/- $bw."))
		graph export medicaid_msp_gph_rd_qmb.png, replace

		tab2 above_qmb_threshold_ca mcd_qmb_thold_100_flag if t_qmb_ca==1 // models 2a-2b
		tab2 above_qmb_threshold_ca mcd_qmb_thold_100_flag if t_qmb_ca==1 & year>=$yearfrom // models 2a-2b

		* How many of these individuals above/below the effectively 'joint' QMB/Medicaid threshold are in California?
		tab2 above_qmb_threshold_ca mcd_qmb_thold_100_flag if t_qmb_ca==1 & stateusps=="CA" // models 2a-2b
		tab2 above_qmb_threshold_ca mcd_qmb_thold_100_flag if t_qmb_ca==1 & stateusps=="CA" & year>=$yearfrom // models 2a-2b


*** MSP(QI)/LIS thresholds ***********************************************
twoway 	(scatter $lis_income_var $qi_income_diff_var if ((in_qi_thold_analysis==1 | in_lis_thold_analysis==1) & $lis_part_income_diff_var>0), mcolor(ltblue) msize(vsmall)) ///
		(scatter $lis_income_var $qi_income_diff_var if ((in_qi_thold_analysis==1 | in_lis_thold_analysis==1) & $lis_part_income_diff_var<0) & any_hh_dep==0, mcolor(navy) msize(vsmall)) ///
		(scatter $lis_income_var $qi_income_diff_var if ((in_qi_thold_analysis==1 | in_lis_thold_analysis==1) & $lis_part_income_diff_var<0) & any_hh_dep==1, mcolor(maroon) msize(vsmall)) ///
		(scatter $lis_income_var $qi_income_diff_var if ((in_qi_thold_analysis==1 | in_lis_thold_analysis==1) & $lis_part_income_diff_var<0) & flagstate_msp==1, xline(0) yline(135 150) mcolor(sand) msize(vsmall) ///
		title("Distribution of income relative to" "QI and LIS eligibility thresholds") ///
		ytitle("Income") xtitle("Income relative to QI elig. threshold") ///
		legend(lab(1 "Not eligible for subsidies") lab(2 "No dependents in household") lab(3 "Dependents in household") lab(4 "States with expanded MSPs")) note("States with expanded MSPs: CT, DC, IN, ME." "Income in percentage points of the FPL. For the MSPs, FPL is based on a 1- or 2-person family." "For the LIS, FPL is calculated including dependents."))
		graph export msp_lis_gph.png, replace

	* Overlay RD subsamples
		gen in_donut_slmb=(($slmb_income_diff_var<0 & $slmb_income_diff_var>-$donut) | ($slmb_income_diff_var>0 & $slmb_income_diff_var<$donut))
		gen in_donut_qi=(($qi_income_diff_var<0 & $qi_income_diff_var>-$donut) | ($qi_income_diff_var>0 & $qi_income_diff_var<$donut))
		gen in_donut_lis_full=(($lis_full_income_diff_var<0 & $lis_full_income_diff_var>-$donut) | ($lis_full_income_diff_var>0 & $lis_full_income_diff_var<$donut))
		gen in_donut_lis_part=(($lis_part_income_diff_var<0 & $lis_part_income_diff_var>-$donut) | ($lis_part_income_diff_var>0 & $lis_part_income_diff_var<$donut))
		gen t_qi=(in_qi_thold_analysis==1 & ($qi_income_diff_var>-$bw & $qi_income_diff_var<$bw)) * (1-in_donut_qi)
		gen t_lis_full=(in_lis_full_thold_analysis==1 & $lis_full_income_diff_var>-$bw & $lis_full_income_diff_var<$bw ) * (1-in_donut_lis_full)
		gen t_lis_part=(in_lis_part_thold_analysis==1 & $lis_part_income_diff_var>-$bw & $lis_part_income_diff_var<$bw ) * (1-in_donut_lis_part)
		gen lis_washout=(below_lis_full_threshold==0 & below_lis_part_threshold==1) // & year>=$yearfrom

		qui summ above_lis_full_threshold if (t_lis_full==1 | t_lis_part==1) & lis_washout==0
		local n_lis=r(N)

twoway 	(scatter $lis_income_var $qi_income_diff_var if ((in_qi_thold_analysis==1 | in_lis_thold_analysis==1) & $lis_part_income_diff_var>0), mcolor(ltblue) msize(vsmall)) ///
		(scatter $lis_income_var $qi_income_diff_var if ((in_qi_thold_analysis==1 | in_lis_thold_analysis==1) & $lis_part_income_diff_var<0) & any_hh_dep==0 & flagstate_msp==0, mcolor(navy) msize(vsmall)) ///
		(scatter $lis_income_var $qi_income_diff_var if ((in_qi_thold_analysis==1 | in_lis_thold_analysis==1) & $lis_part_income_diff_var<0) & any_hh_dep==1 & flagstate_msp==0, mcolor(maroon) msize(vsmall) xline(0) yline(135 150)) ///
		(scatter $lis_income_var $qi_income_diff_var if ((t_lis_full==1 | t_lis_part==1) & lis_washout==0), mcolor(dkgreen) msymbol(Oh) msize(vsmall)) ///
		(scatter $lis_income_var $qi_income_diff_var if ((in_qi_thold_analysis==1 | in_lis_thold_analysis==1) & $lis_part_income_diff_var>0 & flagstate_msp==1), mcolor(sand) msymbol(Oh) msize(vsmall) ///
		title("Distribution of income relative to" "QI and LIS eligibility thresholds") ///
		ytitle("Income") xtitle("Income relative to QI elig. threshold") ///
		legend(lab(1 "Not eligible for subsidies") lab(2 "No dependents in household") lab(3 "Dependents in household") lab(4 "RD: full LIS with/without QI") lab(5 "States with expanded MSPs")) note("Income in percentage points of the FPL. For the MSPs, FPL is based on a 1- or 2-person family." "For the LIS, FPL is calculated including dependents." "RD N: LIS threshold (omitting washout)=`n_lis' at bw up to +/- $bw."))
		graph export msp_lis_gph_rd.png, replace

		tab2 above_lis_full_threshold above_lis_part_threshold if (t_lis_full==1 | t_lis_part==1) //& lis_washout==0 // model 3
		tab2 above_lis_full_threshold above_lis_part_threshold if (t_lis_full==1 | t_lis_part==1) & year>=$yearfrom // model 3
		tab2 above_lis_full_threshold above_lis_part_threshold if (t_lis_full==1 | t_lis_part==1) & lis_washout==0 & year>=$yearfrom & any_hh_dep==0 // model 3 (excluding HHs with dependents)

		* Replicate the above graph but highlight the washout group
		twoway 	(scatter $lis_income_var $qi_income_diff_var if ((in_qi_thold_analysis==1 | in_lis_thold_analysis==1) & $lis_part_income_diff_var>0), mcolor(ltblue) msize(vsmall)) ///
				(scatter $lis_income_var $qi_income_diff_var if ((in_qi_thold_analysis==1 | in_lis_thold_analysis==1) & $lis_part_income_diff_var<0) & any_hh_dep==0 & flagstate_msp==0, mcolor(navy) msize(vsmall)) ///
				(scatter $lis_income_var $qi_income_diff_var if ((in_qi_thold_analysis==1 | in_lis_thold_analysis==1) & $lis_part_income_diff_var<0) & any_hh_dep==1 & flagstate_msp==0, mcolor(maroon) msize(vsmall) xline(0) yline(135 150)) ///
				(scatter $lis_income_var $qi_income_diff_var if ((t_lis_full==1 | t_lis_part==1) & lis_washout==0), mcolor(dkgreen) msymbol(Oh) msize(vsmall)) ///
				(scatter $lis_income_var $qi_income_diff_var if ((in_qi_thold_analysis==1 | in_lis_thold_analysis==1) & $lis_part_income_diff_var>0 & flagstate_msp==1), mcolor(sand) msymbol(Oh) msize(vsmall)) ///
				(scatter $lis_income_var $qi_income_diff_var if ((t_lis_full==1 | t_lis_part==1) & lis_washout==1), mcolor(gs12) msymbol(Oh) msize(vsmall) ///
				title("Distribution of income relative to" "QI and LIS eligibility thresholds") ///
				ytitle("Income") xtitle("Income relative to QI elig. threshold") ///
				legend(lab(1 "Not eligible for subsidies") lab(2 "No dependents in household") lab(3 "Dependents in household") lab(4 "RD: full LIS with/without QI") lab(5 "States with expanded MSPs") lab(6 "Washout")) note("Income in percentage points of the FPL. For the MSPs, FPL is based on a 1- or 2-person family." "For the LIS, FPL is calculated including dependents." "RD N: LIS threshold (omitting washout)=`n_lis' at bw up to +/- $bw."))
				graph export msp_lis_gph_rd_washout.png, replace


***************************************************************************************************************
** Examine first stage of RD models
***************************************************************************************************************

** LINE PLOTS **
* Plot any Medicaid enrollment and program-specific Medicaid enrollment as a function of income
binscatter any_buyin_qmb_plus inc_fpl_mcd_x_ssi if inc_fpl_mcd_x_ssi<150 & year>=$yearfrom, line(connect) nquantiles($nplotquantiles) by(mcd_qmb_thold_100_flag) ylab(0(0.2)1) xline(75 100, lcolor(gs10) lpattern(dash)) ///
	legend(lab(1 "Mcd<QMB=100% FPL") lab(2 "Mcd=QMB=100% FPL")) title("QMB Plus Enrollment") ytitle("Proportion enrolled" "As a function of income measured per SSI standard") xtitle("Income, net of disregards, in percentage points of FPL") note("FPL is based on a one- or two-person family (SSI standard).")
graph export buyin_qmb_plus.png, replace
	
binscatter any_buyin_qmb      inc_fpl_mcd_x_ssi if inc_fpl_mcd_x_ssi<150 & year>=$yearfrom, line(connect) nquantiles($nplotquantiles) xline(100, lcolor(gs10) lpattern(dash)) ylab(0(0.2)1) ///
	title("QMB Enrollment") ytitle("Proportion enrolled" "As a function of income measured per SSI standard") xtitle("Income, net of disregards, in percentage points of FPL") note("FPL is based on a one- or two-person family (SSI standard).")
graph export buyin_qmb_plus.png, replace

	***** Display for JAMA Letter ********************************************************************************
		binscatter any_buyin     inc_fpl_mcd_x_ssi if inc_fpl_mcd_x_ssi<150 & year>=$yearfrom & asset_below_msp==1, line(connect) nquantiles($nplotquantiles) xline(100 120 135, lcolor(gs10) lpattern(dash)) ylab(0(0.2)1) savedata(any_buyin_gph) replace ///
			title("Any Full or Partial Medicaid Enrollment" "As a function of income measured per SSI standard") ytitle("Proportion enrolled") xtitle("Income, net of disregards, in percentage points of FPL") note("Conditional on meeting resource limits for MSPs." "FPL is based on a one- or two-person family (SSI standard).")
		graph export any_buyin.png, replace

		binscatter any_buyin_qmb inc_fpl_mcd_x_ssi if inc_fpl_mcd_x_ssi<150 & year>=$yearfrom & asset_below_msp==1, line(connect) nquantiles($nplotquantiles) xline(100, lcolor(gs10) lpattern(dash)) ylab(0(0.2)1) savedata(any_qmb_gph) replace ///
			title("QMB Enrollment") ytitle("Proportion enrolled" "As a function of income measured per SSI standard") xtitle("Income, net of disregards, in percentage points of FPL") note("Conditional on meeting resource limits for MSPs." "FPL is based on a one- or two-person family (SSI standard).")
		graph export buyin_qmb_plus.png, replace
		
		binscatter any_full_lis  inc_fpl_mcd_x_ssi if inc_fpl_mcd_x_ssi<150 & year>=$yearfrom & asset_below_lis_full==1, line(connect) nquantiles($nplotquantiles) xline(100 135, lcolor(gs10) lpattern(dash)) ylab(0(0.2)1) savedata(any_fulllis_gph) replace ///
			title("Any Full LIS Enrollment" "As a function of income measured per SSI standard") ytitle("Proportion enrolled") xtitle("Income, net of disregards, in percentage points of FPL") note("Conditional on meeting resource limits for MSPs." "FPL is based on a one- or two-person family (SSI standard).")
		graph export any_full_lis_pooled.png, replace
	******************************************************************************************************************
	
binscatter any_full_lis inc_fpl_lis_w_ssi if inc_fpl_lis_w_ssi<150 & year>=$yearfrom, line(connect) nquantiles($nplotquantiles) xline(100 135, lcolor(gs10) lpattern(dash)) ylab(0(0.2)1) ///
	title("Any Full LIS Enrollment" "As a function of income measured per LIS standard") ytitle("Proportion enrolled") xtitle("Income, net of disregards, in percentage points of FPL") note("FPL includes dependents (LIS standard).")
graph export any_full_lis.png, replace


** RD PLOTS **
* Full Medicaid
		/* Ensure that the Medicaid-only discontinuty analysis doesn't capture people on the threshold of QMB eligibility */
			gen th_diff_qmb_mcd=qmb_inc_t-mcd_inc_t // difference in QMB vs. full Medicaid income eligibility thresholds
			tab mcd_qmb_thold_100_flag, summ(th_diff_qmb_mcd)
			table stateusps if t_mcd==1, c(max th_diff_qmb_mcd max $medicaid_income_diff_var) // max difference between person-level income and Medicaid eligibility threshold cannot exceed max difference between QMB and Medicaid eligibility thresholds

	** >> Main RD: Discontinuty in full Medicaid enrollment (without concurrent loss of QMB)
	qui summ any_buyin_qmb if t_mcd==1 & in_donut_mcd==0
	local sampsize=r(N)
	reg any_buyin_full_mcd above_mcd_threshold $medicaid_income_diff_var if t_mcd==1 & in_donut_mcd==0, vce(cluster statenum)
	local beta = round( _b[above_mcd_threshold], 0.01)
	local se   = round(_se[above_mcd_threshold], 0.01)
	binscatter any_buyin_full_mcd $medicaid_income_diff_var if t_mcd==1, nquantiles($nplotquantiles) rd(0) linetype(lfit) xline(-$donut $donut, lcolor(gs5) lpattern(dot)) ylab(0(0.2)1) ///
	title("Any Full Medicaid Enrollment" "As a function of income relative to Medicaid threshold") ytitle("Proportion enrolled in full Medicaid") xtitle("Income in percentage points of FPL relative to eligibility threshold") note("Income net of disregards. FPL is based on a one- or two-person family (SSI standard)." "N in analytic sample: `sampsize'." "Estimated enrollment difference above vs below threshold: `beta', se: `se'")
	graph export rd_full_mcd.png, replace
	
* QMB with/without full Medicaid
		/* Ensure that the QMB-only discontinuty analysis doesn't capture people on the threshold of Medicaid eligibility */
			gen th_diff_mcd_qmb=mcd_inc_t-qmb_inc_t // difference in full Medicaid vs. QMB income eligibility thresholds
			table stateusps if t_qmb_ca==1 & mcd_qmb_thold_100_flag==0, c(min th_diff_mcd_qmb min $qmb_income_diff_var) // min difference between Medicaid and QMB eligibility threshold must be at least as large (in abs value) as the min difference between person-level income and the QMB eligibility threshold

	***** Display for lesser of paper ********************************************************************************
	qui summ any_buyin_qmb if /*t_qmb_ca==1 &*/ in_donut_qmb_ca==0
	local sampsize=r(N)
	reg any_buyin_qmb above_qmb_threshold_ca $qmb_income_diff_var_ca if /*t_qmb_ca==1 &*/ in_donut_qmb_ca==0, vce(cluster statenum)
	local beta = round( _b[above_qmb_threshold_ca], 0.01)
	local se   = round(_se[above_qmb_threshold_ca], 0.01)
	binscatter any_buyin_qmb $qmb_income_diff_var_ca if /*t_qmb_ca==1 &*/ in_donut_qmb_ca==0 & $qmb_income_diff_var<100, nquantiles($nplotquantiles) rd(0) linetype(lfit) xline(-$donut $donut, lcolor(gs5) lpattern(dot)) ylab(0(0.2)1) ///
	title("Any QMB Enrollment (all states)" "As a function of income relative to QMB eligibility threshold") ytitle("Proportion enrolled in QMB") xtitle("Income in percentage points of FPL relative to QMB eligibility threshold") note("Income net of disregards. FPL is based on a one- or two-person family (SSI standard)." "N in analytic sample: `sampsize'." "Estimated enrollment difference above vs below threshold: `beta', se: `se'")
	graph export rd_any_qmb_lesserof.png, replace
	tab2 any_buyin_qmb above_qmb_threshold_ca if asset_below_msp==1 & $qmb_income_diff_var<100, col
	tab2 any_buyin_qmb above_qmb_threshold_ca if asset_below_msp==0 & $qmb_income_diff_var<100, col
	******************************************************************************************************************
	
	** >> Main RD: Discontinuty in any QMB enrollment (pooled across states)
	qui summ any_buyin_qmb if t_qmb_ca==1 & in_donut_qmb_ca==0
	local sampsize=r(N)
	reg any_buyin_qmb above_qmb_threshold_ca $qmb_income_diff_var_ca if t_qmb_ca==1 & in_donut_qmb_ca==0, vce(cluster statenum)
	local beta = round( _b[above_qmb_threshold_ca], 0.01)
	local se   = round(_se[above_qmb_threshold_ca], 0.01)
	binscatter any_buyin_qmb $qmb_income_diff_var_ca if t_qmb_ca==1 & in_donut_qmb_ca==0, nquantiles($nplotquantiles) rd(0) linetype(lfit) xline(-$donut $donut, lcolor(gs5) lpattern(dot)) ylab(0(0.2)1) ///
	title("Any QMB Enrollment (all states)" "As a function of income relative to QMB eligibility threshold") ytitle("Proportion enrolled in QMB") xtitle("Income in percentage points of FPL relative to eligibility threshold") note("Income net of disregards. FPL is based on a one- or two-person family (SSI standard)." "N in analytic sample: `sampsize'." "Estimated enrollment difference above vs below threshold: `beta', se: `se'")
	graph export rd_any_qmb_pooled.png, replace

	* Placebo test: Discontinuty in full LIS enrollment at QMB eligibility threshold
	qui summ any_buyin_qmb if t_qmb_ca==1 & in_donut_qmb_ca==0
	local sampsize=r(N)
	reg any_full_lis above_qmb_threshold_ca $qmb_income_diff_var_ca if t_qmb==1 & in_donut_qmb==0, vce(cluster statenum)
	local beta = round( _b[above_qmb_threshold_ca], 0.01)
	local se   = round(_se[above_qmb_threshold_ca], 0.01)
	binscatter any_full_lis $qmb_income_diff_var_ca if t_qmb_ca==1 & in_donut_qmb_ca==0, nquantiles($nplotquantiles) rd(0) linetype(lfit) xline(-$donut $donut, lcolor(gs5) lpattern(dot)) ylab(0(0.2)1) ///
	title("Any Full LIS Enrollment (all states)" "As a function of income relative to QMB threshold") ytitle("Proportion enrolled in the full LIS") note("Income net of disregards. FPL is based on a one- or two-person family (SSI standard)." "N in analytic sample: `sampsize'." "Estimated enrollment difference above vs below threshold: `beta', se: `se'")
	graph export rd_full_lis_vs_qmb.png, replace

* LIS
	* Confirming some sample characteristics
	tab2 below_lis_full_threshold below_lis_part_threshold if (t_lis_full==1 | t_lis_part==1) & year>=$yearfrom, missing
	tab2 below_lis_full_threshold below_lis_part_threshold if (t_lis_full==1 | t_lis_part==1) & year>=$yearfrom & in_donut_lis_full==0, missing
	tab2 below_lis_full_threshold below_lis_part_threshold if (t_lis_full==1 | t_lis_part==1) & year>=$yearfrom & in_donut_lis_part==0, missing
	
		/*
		below_lis_ | below_lis_part_thresh
		full_thres |          old
			  hold |         0          1 |     Total
		-----------+----------------------+----------
				 0 |     1,452        277 |     1,729 
				 1 |         0        624 |       624 
		-----------+----------------------+----------
			 Total |     1,452        901 |     2,353 
		*/
	summ inc_fpl_lis_x_ssi if lis_washout==1
	
	* >> Main RD (preferred approach): examine loss of the LIS (essentially, full LIS) comparing individuals below 135% of FPL vs those above 150% of FPL
		reg any_lis      $lis_income_var above_lis_part_threshold if (t_lis_full==1 | t_lis_part==1) & lis_washout==0 & in_donut_lis_part==0 & in_donut_lis_full==0
			local beta1 = round( _b[above_lis_part_threshold], 0.01)
			local se1   = round(_se[above_lis_part_threshold], 0.01)
		reg any_full_lis $lis_income_var above_lis_part_threshold if (t_lis_full==1 | t_lis_part==1) & lis_washout==0 & in_donut_lis_part==0 & in_donut_lis_full==0
			local beta2 = round( _b[above_lis_part_threshold], 0.01)
			local se2   = round(_se[above_lis_part_threshold], 0.01)

			local donutl=135-$donut
			local donutu=150+$donut // washout is 135-150% of FPL
			qui summ any_lis if (lis_washout==0 & in_donut_lis_full==0 & in_donut_lis_part==0 & (t_lis_full==1 | t_lis_part==1))
			local sampsize=r(N)

		binscatter any_lis      $lis_income_var if /*any_partd==1 &*/ in_donut_lis_full==0 & in_donut_lis_part==0 & (t_lis_full==1 | t_lis_part==1),  nquantiles($nplotquantiles) rd(135 150) linetype(none) ylab(0(0.2)1) xline(`donutl' `donutu', lcolor(gs5) lpattern(dot)) ///
		title("Any LIS Enrollment") xtitle("Income in pp. of FPL") ytitle("Proportion enrolled in the LIS")
		graph save gany1, replace // this version doesn't overlay a fitted regression line and doesn't omit data in the washout income range (135-150% FPL)
		binscatter any_lis      $lis_income_var if /*any_partd==1 &*/ in_donut_lis_full==0 & in_donut_lis_part==0 & (t_lis_full==1 | t_lis_part==1) & lis_washout==0,  nquantiles($nplotquantiles) rd(135 150) linetype(lfit) ylab(0(0.2)1) xline(`donutl' `donutu', lcolor(gs5) lpattern(dot)) ///
		title("Any LIS Enrollment") xtitle("Income in pp. of FPL") ytitle("Proportion enrolled in the LIS") note("Estimated enrollment diff. <135% vs >150% FPL: `beta1', se: `se1'")
		graph save gany2, replace // this version overlays a fitted regression line, omitting data in the washout income range (135-150% FPL)
		
		binscatter any_full_lis $lis_income_var if /*any_partd==1 &*/ in_donut_lis_full==0 & in_donut_lis_part==0 & (t_lis_full==1 | t_lis_part==1),  nquantiles($nplotquantiles) rd(135 150) linetype(none)  ylab(0(0.2)1) xline(`donutl' `donutu', lcolor(gs5) lpattern(dot)) ///
		title("Any Full LIS Enrollment") xtitle("Income in pp. of FPL") ytitle("Proportion enrolled in the Full LIS")
		graph save gfull1, replace  // this version doesn't overlay a fitted regression line and doesn't omit data in the washout income range (135-150% FPL)
		binscatter any_full_lis $lis_income_var if /*any_partd==1 &*/ in_donut_lis_full==0 & in_donut_lis_part==0 & (t_lis_full==1 | t_lis_part==1) & lis_washout==0,  nquantiles($nplotquantiles) rd(135 150) linetype(lfit) ylab(0(0.2)1) xline(`donutl' `donutu', lcolor(gs5) lpattern(dot)) ///
		title("Any Full LIS Enrollment") xtitle("Income in pp. of FPL") ytitle("Proportion enrolled in the Full LIS") note("Estimated enrollment diff. <135% vs >150% FPL: `beta2', se: `se2'")
		graph save gfull2, replace // this version overlays a fitted regression line, omitting data in the washout income range (135-150% FPL)
		
			graph combine gany1.gph gfull1.gph, ycommon note("N in analytic sample (net of washout at 135-150% FPL): `sampsize'." "FPL is based on family size including dependent relatives.")
			graph export rd_lis_no_overlay_main.png, replace

			graph combine gany2.gph gfull2.gph, ycommon note("N in analytic sample (net of washout at 135-150% FPL): `sampsize'." "FPL is based on family size including dependent relatives.")
			graph export rd_lis_overlay_main.png, replace

			
	* Alternative RD approach #1: examine loss of any LIS/the full LIS at the 135% of FPL threshold
		reg any_lis      $lis_income_var above_lis_full_threshold if (t_lis_full==1 | t_lis_part==1) & in_donut_lis_full==0
			local beta1 = round( _b[above_lis_full_threshold], 0.01)
			local se1   = round(_se[above_lis_full_threshold], 0.01)
		reg any_full_lis $lis_income_var above_lis_full_threshold if (t_lis_full==1 | t_lis_part==1) & in_donut_lis_full==0
			local beta2 = round( _b[above_lis_full_threshold], 0.01)
			local se2   = round(_se[above_lis_full_threshold], 0.01)

			local donutl=135-$donut
			local donutu=135+$donut
			qui summ any_lis if (in_donut_lis_full==0 & (t_lis_full==1 | t_lis_part==1))
			local sampsize=r(N)

		binscatter any_lis      $lis_income_var if (in_donut_lis_full==0 & (t_lis_full==1 | t_lis_part==1)), nquantiles($nplotquantiles) rd(135) linetype(none) ylab(0(0.2)1) xline(`donutl' `donutu' 150, lcolor(gs5) lpattern(dot)) ///
		title("Any LIS Enrollment") xtitle("Income in pp. of FPL") ytitle("Proportion enrolled in the LIS")
		graph save gany1, replace // this version doesn't overlay a fitted regression line
		binscatter any_lis      $lis_income_var if (in_donut_lis_full==0 & (t_lis_full==1 | t_lis_part==1)), nquantiles($nplotquantiles) rd(135) linetype(lfit) ylab(0(0.2)1) xline(`donutl' `donutu' 150, lcolor(gs5) lpattern(dot)) ///
		title("Any LIS Enrollment") xtitle("Income in pp. of FPL") ytitle("Proportion enrolled in the LIS") note("Estimated enrollment diff. at 135% FPL: `beta1', se: `se1'")
		graph save gany2, replace // this version overlays a fitted regression line
		
		binscatter any_full_lis $lis_income_var if (in_donut_lis_full==0 & (t_lis_full==1 | t_lis_part==1)), nquantiles($nplotquantiles) rd(135) linetype(none)  ylab(0(0.2)1) xline(`donutl' `donutu' 150, lcolor(gs5) lpattern(dot)) ///
		title("Any Full LIS Enrollment") xtitle("Income in pp. of FPL") ytitle("Proportion enrolled in the Full LIS")
		graph save gfull1, replace  // this version doesn't overlay a fitted regression line
		binscatter any_full_lis $lis_income_var if (in_donut_lis_full==0 & (t_lis_full==1 | t_lis_part==1)), nquantiles($nplotquantiles) rd(135) linetype(lfit) ylab(0(0.2)1) xline(`donutl' `donutu' 150, lcolor(gs5) lpattern(dot)) ///
		title("Any Full LIS Enrollment") xtitle("Income in pp. of FPL") ytitle("Proportion enrolled in the Full LIS") note("Estimated enrollment diff. at 135% FPL: `beta2', se: `se2'")
		graph save gfull2, replace // this version overlays a fitted regression line
		
			graph combine gany1.gph gfull1.gph, ycommon note("N in analytic sample: `sampsize'." "FPL is based on family size including dependent relatives.")
			graph export rd_lis_no_overlay_alt1.png, replace

			graph combine gany2.gph gfull2.gph, ycommon note("N in analytic sample: `sampsize'." "FPL is based on family size including dependent relatives.")
			graph export rd_lis_overlay_alt1.png, replace

			
	* Alternative RD approach #2: examine loss of any LIS at the 150% of FPL threshold
		reg any_lis      $lis_income_var above_lis_part_threshold if (t_lis_full==1 | t_lis_part==1) & in_donut_lis_part==0
			local beta1 = round( _b[above_lis_part_threshold], 0.01)
			local se1   = round(_se[above_lis_part_threshold], 0.01)

			local donutl=150-$donut
			local donutu=150+$donut
			qui summ any_lis if (in_donut_lis_part==0 & (t_lis_full==1 | t_lis_part==1))
			local sampsize=r(N)

		binscatter any_lis      $lis_income_var if (in_donut_lis_part==0 & (t_lis_full==1 | t_lis_part==1)), nquantiles($nplotquantiles) rd(150) linetype(none) ylab(0(0.2)1) xline(135 `donutl' `donutu', lcolor(gs5) lpattern(dot)) ///
		title("Any LIS Enrollment") xtitle("Income in pp. of FPL") ytitle("Proportion enrolled in the LIS")
		graph save gany1, replace // this version doesn't overlay a fitted regression line
		binscatter any_lis      $lis_income_var if (in_donut_lis_part==0 & (t_lis_full==1 | t_lis_part==1)), nquantiles($nplotquantiles) rd(150) linetype(lfit) ylab(0(0.2)1) xline(135 `donutl' `donutu', lcolor(gs5) lpattern(dot)) ///
		title("Any LIS Enrollment") xtitle("Income in pp. of FPL") ytitle("Proportion enrolled in the LIS") note("Estimated enrollment diff. at 150% FPL: `beta1', se: `se1'")
		graph save gany2, replace // this version overlays a fitted regression line

			graph combine gany1.gph gany2.gph, ycommon note("N in analytic sample: `sampsize'." "FPL is based on family size including dependent relatives.")
			graph export rd_lis_alt2.png, replace


* Validation check: Receipt of SSI income as a function of Medicaid eligibility
	qui summ any_ssi_income if t_mcd==1 & in_donut_mcd==0 & year>=$yearfrom
	local sampsize=r(N)
	reg any_ssi_income above_mcd_threshold $medicaid_income_diff_var if t_mcd==1 & in_donut_mcd==0, vce(cluster statenum)
	local beta = round( _b[above_mcd_threshold], 0.01)
	local se   = round(_se[above_mcd_threshold], 0.01)
	binscatter any_ssi_income $medicaid_income_diff_var if t_mcd==1 & in_donut_mcd==0, nquantiles($nplotquantiles) rd(0) linetype(lfit) xline(-$donut $donut, lcolor(gs5) lpattern(dot))  ///
	title("Covariate discontinutiy test for Receipt of SSI Income" "Above vs below Medicaid eligibility threshold") ytitle("Proportion Receiving SSI Income") xtitle("Income in percentage points of FPL relative to Medicaid eligibility threshold") note("N in analytic sample: `sampsize'" "FPL is based on a one- or two-person family (SSI standard)." "Estimated difference above vs below threshold: `beta', se: `se'")
	graph export rd_mcd_any_ssi_income1.png, replace

	
***************************************************************************************************************
** Validation checks of RD models -- covariate discontinuity and 'heaping' tests
***************************************************************************************************************

* (1) Covariate discontinuity tests -- plot covariates as a function of income relative to threshold
foreach yvar in /*age race_nonwhite english married_partnered orec_disabled ccw_total*/ ever_smoke drinkwk {
	local ltype none
	
	* Discontinuty for full Medicaid (without concurrent loss of QMB)
	qui summ `yvar' if t_mcd==1 & in_donut_mcd==0 & year>=$yearfrom
	local sampsize=r(N)
	reg `yvar' above_mcd_threshold $medicaid_income_diff_var if t_mcd==1 & in_donut_mcd==0, vce(cluster statenum)
	local beta = round( _b[above_mcd_threshold], 0.01)
	local se   = round(_se[above_mcd_threshold], 0.01)
	binscatter `yvar' $medicaid_income_diff_var if t_mcd==1 & in_donut_mcd==0, nquantiles($nplotquantiles) rd(0) linetype(`ltype') xline(-$donut $donut, lcolor(gs5) lpattern(dot))  ///
	title("Covariate discontinutiy test for `yvar'" "Above vs below Medicaid eligibility threshold") ytitle("`yvar'") xtitle("Income in percentage points of FPL relative to Medicaid eligibility threshold") note("N in analytic sample: `sampsize'" "FPL is based on a one- or two-person family (SSI standard)." "Estimated difference above vs below threshold: `beta', se: `se'")
	graph export rd_mcd_`yvar'.png, replace
	
	* Discontinuty for QMB (pooled across states)
	qui summ `yvar' if t_qmb==1 & in_donut_qmb==0 & year>=$yearfrom
	local sampsize=r(N)
	reg `yvar' above_qmb_threshold $qmb_income_diff_var if t_qmb==1 & in_donut_qmb==0, vce(cluster statenum)
	local beta = round( _b[above_qmb_threshold], 0.01)
	local se   = round(_se[above_qmb_threshold], 0.01)
	binscatter `yvar' $qmb_income_diff_var if t_qmb==1 & in_donut_qmb==0, nquantiles($nplotquantiles) rd(0) linetype(`ltype') xline(-$donut $donut, lcolor(gs5) lpattern(dot))  ///
	title("Covariate discontinutiy test for `yvar'" "Above vs below QMB eligibility threshold") ytitle("`yvar'") xtitle("Income in percentage points of FPL relative to QMB eligibility threshold") note("N in analytic sample: `sampsize'" "FPL is based on a one- or two-person family (SSI standard)." "Estimated difference above vs below threshold: `beta', se: `se'")
	graph export rd_qmb_`yvar'.png, replace
	
	* Discontinuty for the LIS -- full LIS threshold
	qui summ `yvar' if (t_lis_full==1 | t_lis_part==1) & in_donut_lis_full==0 & year>=$yearfrom
	local sampsize=r(N)
	reg `yvar' $lis_income_var above_lis_full_threshold if (t_lis_full==1 | t_lis_part==1) & in_donut_lis_full==0
	local beta = round( _b[above_lis_full_threshold], 0.01)
	local se   = round(_se[above_lis_full_threshold], 0.01)
	local donutl=135-$donut
	local donutu=135+$donut
	binscatter `yvar'      $lis_income_var if ((t_lis_full==1 | t_lis_part==1) & in_donut_lis_full==0), nquantiles($nplotquantiles) rd(135) linetype(`ltype') xline(`donutl' `donutu', lcolor(gs5) lpattern(dot)) ///
	title("Covariate discontinutiy test for `yvar'" "Above vs below full LIS eligibility threshold") xtitle("Income in pp. of FPL") ytitle("`yvar'") note("N in analytic sample: `sampsize'" "FPL is based on family size including dependent relatives." "Estimated difference above vs below 135% FPL: `beta', se: `se'")
	graph export rd_lis_full_`yvar'.png, replace

	* Discontinuty for the LIS -- partial LIS threshold
	qui summ `yvar' if (t_lis_full==1 | t_lis_part==1) & in_donut_lis_part==0 & year>=$yearfrom
	local sampsize=r(N)
	reg `yvar' $lis_income_var above_lis_part_threshold if (t_lis_full==1 | t_lis_part==1) & in_donut_lis_part==0
	local beta = round( _b[above_lis_part_threshold], 0.01)
	local se   = round(_se[above_lis_part_threshold], 0.01)
	local donutl=150-$donut
	local donutu=150+$donut
	binscatter `yvar'      $lis_income_var if ((t_lis_full==1 | t_lis_part==1) & in_donut_lis_part==0), nquantiles($nplotquantiles) rd(150) linetype(`ltype') xline(`donutl' `donutu', lcolor(gs5) lpattern(dot)) ///
	title("Covariate discontinutiy test for `yvar'" "Above vs below partial LIS eligibility threshold") xtitle("Income in pp. of FPL") ytitle("`yvar'") note("N in analytic sample: `sampsize'" "FPL is based on family size including dependent relatives." "Estimated difference above vs below 150% FPL: `beta', se: `se'")
	graph export rd_lis_part_`yvar'.png, replace
}

* (2) Check for discontinuities in assets around program eligibility thresholds

	* Discontinuty for full Medicaid (without concurrent loss of QMB)
	qui summ asset_below_mcd if t_mcd==1 & in_donut_mcd==0 & year>=$yearfrom
	local sampsize=r(N)
	reg asset_below_mcd above_mcd_threshold $medicaid_income_diff_var if t_mcd==1 & in_donut_mcd==0, vce(cluster statenum)
	local beta = round( _b[above_mcd_threshold], 0.01)
	local se   = round(_se[above_mcd_threshold], 0.01)
	binscatter asset_below_mcd $medicaid_income_diff_var if t_mcd==1 & in_donut_mcd==0, nquantiles($nplotquantiles) rd(0) linetype(lfit) xline(-$donut $donut, lcolor(gs5) lpattern(dot))  ///
	title("Assets below full Medicaid threshold") ytitle("Proportion with assets below full Medicaid threshold") xtitle("Income in percentage points of FPL relative to Medicaid eligibility threshold") note("N in analytic sample: `sampsize'" "FPL is based on a one- or two-person family (SSI standard)." "Estimated difference above vs below threshold: `beta', se: `se'")
	graph export rd_mcd_asset_below_mcd.png, replace
	
	* Discontinuty for QMB (pooled across states)
	qui summ asset_below_msp if t_qmb==1 & in_donut_qmb==0 & year>=$yearfrom
	local sampsize=r(N)
	reg asset_below_msp above_qmb_threshold $qmb_income_diff_var if t_qmb==1 & in_donut_qmb==0, vce(cluster statenum)
	local beta = round( _b[above_qmb_threshold], 0.01)
	local se   = round(_se[above_qmb_threshold], 0.01)
	binscatter asset_below_msp $qmb_income_diff_var if t_qmb==1 & in_donut_qmb==0, nquantiles($nplotquantiles) rd(0) linetype(lfit) xline(-$donut $donut, lcolor(gs5) lpattern(dot))  ///
	title("Assets below QMB (MSP) threshold") ytitle("Proportion with assets below QMB (MSP) threshold") xtitle("Income in percentage points of FPL relative to QMB eligibility threshold") note("N in analytic sample: `sampsize'" "FPL is based on a one- or two-person family (SSI standard)." "Estimated difference above vs below threshold: `beta', se: `se'")
	graph export rd_qmb_asset_below_msp.png, replace
	
	* Discontinuty for the LIS -- full LIS threshold
	qui summ asset_below_lis_full if (t_lis_full==1 | t_lis_part==1) & in_donut_lis_full==0 & year>=$yearfrom
	local sampsize=r(N)
	reg asset_below_lis_full $lis_income_var above_lis_full_threshold if (t_lis_full==1 | t_lis_part==1) & in_donut_lis_full==0
	local beta = round( _b[above_lis_full_threshold], 0.01)
	local se   = round(_se[above_lis_full_threshold], 0.01)
	local donutl=135-$donut
	local donutu=135+$donut
	binscatter asset_below_lis_full      $lis_income_var if ((t_lis_full==1 | t_lis_part==1) & in_donut_lis_full==0), nquantiles($nplotquantiles) rd(135) linetype(lfit) xline(`donutl' `donutu', lcolor(gs5) lpattern(dot)) ///
	title("Assets below full LIS eligibility threshold") xtitle("Income in pp. of FPL") ytitle("`yvar'") note("N in analytic sample: `sampsize'" "FPL is based on family size including dependent relatives." "Estimated difference above vs below 135% FPL: `beta', se: `se'")
	graph export rd_lis_full_asset_below.png, replace

	* Discontinuty for the LIS -- partial LIS threshold
	qui summ asset_below_lis_part if (t_lis_full==1 | t_lis_part==1) & in_donut_lis_part==0 & year>=$yearfrom
	local sampsize=r(N)
	reg asset_below_lis_part $lis_income_var above_lis_part_threshold if (t_lis_full==1 | t_lis_part==1) & in_donut_lis_part==0
	local beta = round( _b[above_lis_part_threshold], 0.01)
	local se   = round(_se[above_lis_part_threshold], 0.01)
	local donutl=150-$donut
	local donutu=150+$donut
	binscatter asset_below_lis_part      $lis_income_var if ((t_lis_full==1 | t_lis_part==1) & in_donut_lis_part==0), nquantiles($nplotquantiles) rd(150) linetype(lfit) xline(`donutl' `donutu', lcolor(gs5) lpattern(dot)) ///
	title("Assets below below partial LIS eligibility threshold") xtitle("Income in pp. of FPL") ytitle("`yvar'") note("N in analytic sample: `sampsize'" "FPL is based on family size including dependent relatives." "Estimated difference above vs below 150% FPL: `beta', se: `se'")
	graph export rd_lis_part_asset_below.png, replace
	
* Check for 'heaping' around program eligibility thresholds

hist $medicaid_income_diff_var if t_mcd==1 & year>=$yearfrom, xline(0) freq bin(20) kdensity ///
	title("Income distribution around" "full Medicaid eligibility threshold") xtitle("Income in percentage points of FPL relative to Medicaid eligibility threshold")
graph export heap_inc_mcd.png, replace

hist $qmb_income_diff_var if t_qmb==1 & year>=$yearfrom, xline(0) freq bin(20) kdensity ///
	title("Income distribution around" "QMB eligibility threshold") xtitle("Income in percentage points of FPL relative to QMB eligibility threshold")
graph export heap_inc_qmb.png, replace
	
hist $lis_income_var if (t_lis_full==1 | t_lis_part==1) & year>=$yearfrom, xline(135 150) freq bin(20) kdensity ///
	title("Income distribution around" "LIS eligibility threshold") xtitle("Income in pp. of FPL")
graph export heap_inc_lis.png, replace


	 
