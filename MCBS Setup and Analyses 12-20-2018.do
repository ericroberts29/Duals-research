***********************************************************************************
* Setup of MCBS files for dual enrollee characteristics analysis
* This program sets up analytic files and implements analyses of between-state
*  differences in the characteristics of dual Medicare-Medicaid enrollees 
*  using MCBS-linked Medicare claims.
* Author: Eric T. Roberts, University of Pittsburgh, eric.roberts@pitt.edu
* File date: 12/21/2018 - version 4 (final)
***********************************************************************************

clear all
cd "/home/eroberts/MCBS Stata setup files/"

	***************************************************************************
	** Global Macro settings
	set seed 1234
	global month_inc_disregard 20
	global year 2011
	global yr 11
	** Use if year <=2012:
		global sourcefilepath "/data/MCBS/MCBS_Data/$year/Data/SAS Files"
	** Use if year==2013:
		*global sourcefilepath "/data/MCBS/MCBS_Data/$year/Data/SASFiles"
	** Income and asset file
		global iafile ""/data/MCBS/MCBS_Data/2011/Income & Assets/Dataset/ia_2011_supplement.dta""
	***************************************************************************

***********************************************************************************
* (0) Some fixes to the facility interview file
***********************************************************************************

* 2010
use "/data/MCBS/MCBS_Data/2010/Data/SAS Files/ric2f.dta", clear
save ric2f_2010.dta, replace

* 2011
use "/data/MCBS/MCBS_Data/2011/Data/SAS Files/ric2f.dta", clear
save ric2f_2011.dta, replace

* 2012
use "/data/MCBS/MCBS_Data/2012/Data/SAS Files/ric2f.dta", clear
save ric2f_2012.dta, replace

* 2013
use "/data/MCBS/MCBS_Data/2013/Data/SASFiles/ric2f.dta", clear
rename corartds crdvtype
rename cvatiast stroke
rename diabmrn diabmel
gen asthma=asthcopd
gen empcopd=asthcopd
drop asthcopd
save ric2f_2013.dta, replace


***********************************************************************************
* (1) Read in, format, and merge core MCBS survey files
***********************************************************************************

* RIC-X (survey design elements)
use "$sourcefilepath/ricx.dta", clear
rename *, lower
keep baseid sudstrat sudunit cs1yrwgt
sort baseid
gen in_ricx=1
gen year=$year
keep baseid in_ricx year sudstrat sudunit cs1yrwgt
save ricx_fmt_$year.dta, replace

* RIC-1
use "$sourcefilepath/ric1.dta", clear
keep baseid D_DOB D_RACE D_ETHNIC spdegrcv spmarsta income INCOME_C INCOME_H jobstat spdegrcv spchnlnm
rename INCOME_C income_c // continuous income 
rename INCOME_H income_h // household income range
gen race_white=(D_RACE==4 & D_ETHNIC!=1) // white non-hispanic 
gen race_black=(D_RACE==3 & D_ETHNIC!=1) // black non-hispanic
gen race_hispanic=(D_ETHNIC==1) // hispanic
gen race_other=(race_white!=1 & race_black!=1 & race_hispanic!=1)
gen race_nonwhite=(race_black==1 | race_hispanic==1 | race_other==1)
gen married=(spmarsta==1)
gen widowed=(spmarsta==2)
gen divorced_separated=(spmarsta==3 | spmarsta==4)
gen never_married=(spmarsta==5)
gen not_married = (widowed==1 | divorced_separated==1 | never_married==1)
gen educ_lt_hs=(spdegrcv==1 | spdegrcv==2 | spdegrcv==3)
gen educ_hs=(spdegrcv==4)
gen educ_somecoll=(spdegrcv==5 | spdegrcv==6)
gen educ_collhigher=(spdegrcv==7 | spdegrcv==8 | spdegrcv==9)
gen educ_hs_or_less = (educ_lt_hs==1 | educ_hs==1)
gen any_living_children=(spchnlnm>=1)
sort baseid
gen in_ric1=1
keep baseid in_ric1 income_c race_* race_nonwhite not_married married widowed divorced_separated never_married educ_hs_or_less educ_lt_hs educ_hs educ_somecoll educ_collhigher any_living_children
save ric1_fmt_$year.dta, replace

* RIC-2
use "$sourcefilepath/ric2.dta", clear
keep baseid genhelth comphlth helmtact ectroub hctroub eversmok heightft heightin weight ///
difstoop diflift difreach difwrite difwalk ///
prbtele prblhwk prbmeal prbshop prbbils ///
donttele dontlhwk dontmeal dontshop dontbils ///
hppdbath hppdchar hppddres hppdeat hppdtoil hppdwalk ///
dontbath dontchar dontdres donteat donttoil dontwalk ///
fallany D_ADLHNM timesad ///
ochbp ocmyocar occhd ocothhrt ocarth ocstroke occskin occancer ocbetes ocarthrh ///
ocalzmer ocdement ocdeprss ocosteop ocemphys

gen ever_smoke=(eversmok==1) // ever smoked

gen diag_told_hbp=(ochbp==1)
gen diag_told_mi=(ocmyocar==1)
*gen diag_told_chd=(occhd==1)
gen diag_told_stroke=(ocstroke==1)
gen diag_told_diabetes=(ocbetes==1)
gen diag_told_anycancer=(occskin==1 | occancer==1)
gen diag_told_alzh_dement=(ocalzmer==1 | ocdement==1)
gen diag_told_depress=(ocdeprss==1)
gen diag_told_arth=(ocarthrh==1 | ocarth==1)
gen diag_told_osteop=(ocosteop==1)
gen diag_told_asthma_copd=(ocemphys==1)
gen count_told_diag=diag_told_hbp+diag_told_mi+diag_told_stroke+diag_told_diabetes+diag_told_anycancer+diag_told_alzh_dement+diag_told_depress+diag_told_arth+diag_told_osteop+diag_told_asthma_copd

gen gen_hlth_good_to_xlnt=(genhelth==1 | genhelth==2 | genhelth==3) // health is good to excellent
gen gen_hlth_fair_poor=(genhelth==4 | genhelth==5) // health is fair or poor
gen hlth_worse_vs_lastyr=(comphlth==4 | comphlth==5) // health is somewhat or much worse than last year
gen hlth_lim_social=(helmtact==2 | helmtact==3 | helmtact==4) // health limits social activity some to all of the time
gen trouble_see_or_blind=(ectroub==3 | ectroub==4) // a lot of trouble seeing or bindness
gen trouble_hear_or_deaf=(hctroub==3 | hctroub==4) // a lot of trouble hearing or deafness

replace difstoop=(difstoop>=3)
replace diflift=(diflift>=3)
replace difreach=(difreach>=3)
replace difwrite=(difwrite>=3)
replace difwalk=(difwalk>=3)
gen diff_agility_mobility=difstoop+diflift+difreach+difwrite+difwalk

replace prbtele=(prbtele==1 | (prbtele==3 & donttele==1))
replace prblhwk=(prblhwk==1 | (prblhwk==3 & dontlhwk==1))
replace prbmeal=(prbmeal==1 | (prbmeal==3 & dontmeal==1))
replace prbshop=(prbshop==1 | (prbshop==3 & dontshop==1))
replace prbbils=(prbbils==1 | (prbbils==3 & dontbils==1))
gen iadl_lims=prbtele+prblhwk+prbmeal+prbshop+prbbils

replace hppdbath=(hppdbath==1 | (hppdbath==3 & dontbath==1))
replace hppdchar=(hppdchar==1 | (hppdchar==3 & dontchar==1))
replace hppddres=(hppddres==1 | (hppddres==3 & dontdres==1))
replace hppdeat =(hppdeat==1  | (hppdeat==3  & donteat==1 ))
replace hppdtoil=(hppdtoil==1 | (hppdtoil==3 & donttoil==1))
replace hppdwalk=(hppdwalk==1 | (hppdwalk==3 & dontwalk==1))
gen adl_lims=hppdbath+hppdchar+hppddres+hppdeat+hppdtoil+hppdwalk

gen bmi=703*weight/((heightft*12+heightin)^2) if weight>0 & heightft>0

gen any_fall_1yr=(fallany==1)
gen any_helper=(D_ADLHNM>=1 & D_ADLHNM!=.)

sort baseid
gen in_ric2=1
keep baseid in_ric2 bmi diag_told_* count_told_diag gen_hlth_good_to_xlnt gen_hlth_fair_poor hlth_worse_vs_lastyr ///
ever_smoke hlth_lim_social trouble_see_or_blind trouble_hear_or_deaf diff_agility_mobility iadl_lims adl_lims any_fall_1yr any_helper
save ric2_fmt_$year.dta, replace

* RIC-2f // facility file
use ric2f_$year.dta, clear
keep baseid height weight evrsmoke sphealth hlthcomp vision limactiv hchecond  ///
iadstoop iadlift iadreach iadgrasp iadwalk ///
difuseph difshop difmoney ///
reasnoph reasnosh reasnomm ///
pfbathng pftoilet pfeating pfdrssng pftrnsfr pflocomo ///
hypetens myocard crdvtype stroke cnrskin cancer diabmel arthrit alzhmr dement depress osteop asthma empcopd 

gen ever_smoke=(evrsmoke==1)

gen diag_told_hbp=(hypetens==1) 
gen diag_told_mi=(myocard==1) 
*gen diag_told_chd=(crdvtype==1) 
gen diag_told_stroke=(stroke==1) 
gen diag_told_diabetes=(diabmel==1)
gen diag_told_anycancer=(cnrskin==1 | cancer==1)
gen diag_told_alzh_dement=(alzhmr==1 | dement==1)
gen diag_told_depress=(depress==1)
gen diag_told_arth=(arthrit==1)
gen diag_told_osteop=(osteop==1)
gen diag_told_asthma_copd=(asthma==1 | empcopd==1)
gen count_told_diag=diag_told_hbp+diag_told_mi+diag_told_stroke+diag_told_diabetes+diag_told_anycancer+diag_told_alzh_dement+diag_told_depress+diag_told_arth+diag_told_osteop+diag_told_asthma_copd

gen gen_hlth_good_to_xlnt=(sphealth==1 | sphealth==2 | sphealth==3) // health is good to excellent
gen gen_hlth_fair_poor=(sphealth==4 | sphealth==5) // health is fair or poor
gen hlth_worse_vs_lastyr=(hlthcomp==4 | hlthcomp==5) // health is worse or much worse than prior year
gen hlth_lim_social=(limactiv==2 | limactiv==3 | limactiv==4) // health limits social activity some to all of the time
gen trouble_see_or_blind=(vision==4 | vision==5) // vision is severely impaired
gen trouble_hear_or_deaf=(hchecond==3 | hchecond==4) // hearing in special situations only or highly impaired

gen diff_agility_mobility=(iadstoop>=3)+(iadlift>=3)+(iadreach>=3)+(iadgrasp>=3)+(iadwalk>=3)
gen iadl_lims=(difuseph==1 | (difuseph==3 & reasnoph==1))+(difshop==1 | (difshop==3 & reasnosh==1))+(difmoney==1 | (difmoney==3 & reasnomm==1))+2
gen adl_lims=(pfbathng==3 | pfbathng==4 | pfbathng==5) + (pftoilet==3 | pftoilet==4 | pftoilet==5) + (pfeating==3 | pfeating==4 | pfeating==5) + (pfdrssng==3 | pfdrssng==4 | pfdrssng==5) + (pftrnsfr==3 | pftrnsfr==4 | pftrnsfr==5) + (pflocomo==3 | pflocomo==4 | pflocomo==5)

gen bmi=703*weight/((height)^2) if weight>0 & height>0

sort baseid
gen in_ric2f=1
keep baseid in_ric2f bmi ever_smoke gen_hlth_fair_poor hlth_worse_vs_lastyr hlth_lim_social trouble_see_or_blind trouble_hear_or_deaf diff_agility_mobility iadl_lims adl_lims diag_told_* count_told_diag
save ric2f_fmt_$year.dta, replace

	* Stack RIC-2 and RIC-2F - these files should be mutually exclusive on baseid
	use ric2_fmt_$year.dta, clear
	append using ric2f_fmt_$year.dta
	replace in_ric2=0 if in_ric2==.
	replace in_ric2f=0 if in_ric2f==.
	bys baseid: gen t=_n
	save ric2_consol_fmt_$year.dta, replace

* RIC-5
use "$sourcefilepath/ric5.dta", clear
keep baseid D_HHTOT D_HHCOMP
rename D_HHTOT hh_size_temp
sort baseid
gen in_ric5=1
keep baseid in_ric5 D_HHCOMP hh_size_temp
save ric5_fmt_$year.dta, replace

* RIC-9
use "$sourcefilepath/ric9.dta", clear
keep baseid D_CODE* snf
bys baseid: gen t=_n
summ t
gen any_snf=(snf=="Y")
gen any_facility=0
gen any_snf_chk=0
forvalues i=1(1)20{
	replace any_facility=any_facility+(D_CODE`i'=="F" | D_CODE`i'=="G" | D_CODE`i'=="S") // F=facility, G=deemed facility, S=SNF
	replace any_snf_chk=any_snf_chk+(D_CODE`i'=="S")
}
replace any_facility=(any_facility>=1)
replace any_snf_chk=(any_snf_chk>=1)
keep baseid any_snf any_facility
sort baseid
gen in_ric9=1
keep baseid in_ric9 any_facility any_snf
save ric9_fmt_$year.dta, replace

* RIC-K
use "$sourcefilepath/rick.dta", clear
keep baseid type F_DAYS
sort baseid
gen in_rick=1
save rick_fmt_$year.dta, replace

* Merge MCBS survey files together
use ric1_fmt_$year.dta, clear // basic survey file

merge 1:1 baseid using ricx_fmt_$year.dta // basic survey file
drop _merge // all observations match

merge 1:1 baseid using ric2_consol_fmt_$year.dta // health characteristics survey (pooled facility & community survey)
drop _merge // 738 observations don't match

merge 1:1 baseid using ric5_fmt_$year.dta // household composition survey
drop _merge // 859 observations don't match, of which 738 weren't in RIC2 and an additional 123 weren't in RIC5

merge 1:1 baseid using ric9_fmt_$year.dta
drop _merge

merge 1:1 baseid using rick_fmt_$year.dta
drop _merge
tab2 type in_ric2f, missing

/* Populate venn diagram of file overlap (order of results as displayed in venn diagram: left to right, top to bottom)
tab2 in_ric1 in_ric5 if in_ric2!=1 & in_ric2f!=1, missing
tab2 in_ric1 in_ric5 if in_ric2==1 & in_ric2f!=1, missing
tab2 in_ric2 in_ric5 if in_ric1!=1 & in_ric2f!=1, missing
tab2 in_ric1 in_ric5 if in_ric2!=1 & in_ric2f==1, missing
tab2 in_ric1 in_ric5 if in_ric1==1 & in_ric2==1 & in_ric2f==1, missing
tab2 in_ric2 in_ric5 if in_ric2==1 & in_ric2f==1 & in_ric1!=1, missing
tab2 in_ric2f in_ric5 if in_ric1!=1 & in_ric2f==1 & in_ric2!=1, missing
*/
keep if ( in_ric1==1 & in_ricx==1 & (in_ric2==1 | in_ric2f==1) ) // edit 10-21-2018 ... no longer require & in_ric5==1

** Format variables that use underlying data elements from different files

* Living circumstances
gen reside_facility=(in_ric2f==1)
gen reside_alone=(in_ric2f!=1 & D_HHCOMP==1)
gen reside_with_family=(in_ric2f!=1 & (D_HHCOMP==2 | D_HHCOMP==3 | D_HHCOMP==4 | D_HHCOMP==5))
gen reside_with_others=(in_ric2f!=1 & (D_HHCOMP==6 | D_HHCOMP==7))

* Household size
gen hh_size=hh_size_temp if in_ric5==1
replace hh_size=2 if in_ric5!=1 & married==1
replace hh_size=1 if in_ric5!=1 & married==0
*tab2 hh_size married, col missing
save mcbs_merge_$year.dta, replace // this will be the annual consolidated file used for all aubsequent analysis


***********************************************************************************
* (2) Read in and format administrative MCBS file (essentially, the MBSF file)
***********************************************************************************

* Read in MCBS-A file (essentially, the MBSF file)
use "$sourcefilepath/rica.dta", clear
keep baseid H_AGE H_SEX D_STRAT H_ENT* H_DOE H_RESST H_RESCTY H_PDLS* H_DOD H_MCDE* DUAL_* H_PDLS* H_MEDSTA MAFLAG*
destring H_DOE, gen(h_doe)
gen yr_start=round(h_doe/10000,1)
gen new_enrollee=(yr_start==$year)
rename H_RESST ssa_state_cd
rename H_RESCTY ssa_county_cd
rename H_AGE age
gen age_cat=0
replace age_cat=1 if age<=64
replace age_cat=2 if age>=65 & age<=69
replace age_cat=3 if age>=70 & age<=74
replace age_cat=4 if age>=75 & age<=79
replace age_cat=5 if age>=80 & age<=84
replace age_cat=6 if age>=85

gen sex_female=(H_SEX=="2")
gen esrd=(H_MEDSTA=="11" | H_MEDSTA=="21" | H_MEDSTA=="31")
gen disabled=(H_MEDSTA=="20")

gen died=(H_DOD!="")

* Full dual status
gen mcd_full_01=(DUAL_JAN=="02" | DUAL_JAN=="04" | DUAL_JAN=="08")
gen mcd_full_02=(DUAL_FEB=="02" | DUAL_FEB=="04" | DUAL_FEB=="08")
gen mcd_full_03=(DUAL_MAR=="02" | DUAL_MAR=="04" | DUAL_MAR=="08")
gen mcd_full_04=(DUAL_APR=="02" | DUAL_APR=="04" | DUAL_APR=="08")
gen mcd_full_05=(DUAL_MAY=="02" | DUAL_MAY=="04" | DUAL_MAY=="08")
gen mcd_full_06=(DUAL_JUN=="02" | DUAL_JUN=="04" | DUAL_JUN=="08")
gen mcd_full_07=(DUAL_JUL=="02" | DUAL_JUL=="04" | DUAL_JUL=="08")
gen mcd_full_08=(DUAL_AUG=="02" | DUAL_AUG=="04" | DUAL_AUG=="08")
gen mcd_full_09=(DUAL_SEP=="02" | DUAL_SEP=="04" | DUAL_SEP=="08")
gen mcd_full_10=(DUAL_OCT=="02" | DUAL_OCT=="04" | DUAL_OCT=="08")
gen mcd_full_11=(DUAL_NOV=="02" | DUAL_NOV=="04" | DUAL_NOV=="08")
gen mcd_full_12=(DUAL_DEC=="02" | DUAL_DEC=="04" | DUAL_DEC=="08")
gen     full_dual=((mcd_full_01+mcd_full_02+mcd_full_03+mcd_full_04+mcd_full_05+mcd_full_06+mcd_full_07+mcd_full_08+mcd_full_09+mcd_full_10+mcd_full_11+mcd_full_12)>=1)
gen full_dual_maj=((mcd_full_01+mcd_full_02+mcd_full_03+mcd_full_04+mcd_full_05+mcd_full_06+mcd_full_07+mcd_full_08+mcd_full_09+mcd_full_10+mcd_full_11+mcd_full_12)>=6)
	
	* Full dual status disaggregated
	gen qmb_plus_01=(DUAL_JAN=="02")
	gen qmb_plus_02=(DUAL_FEB=="02")
	gen qmb_plus_03=(DUAL_MAR=="02")
	gen qmb_plus_04=(DUAL_APR=="02")
	gen qmb_plus_05=(DUAL_MAY=="02")
	gen qmb_plus_06=(DUAL_JUN=="02")
	gen qmb_plus_07=(DUAL_JUL=="02")
	gen qmb_plus_08=(DUAL_AUG=="02")
	gen qmb_plus_09=(DUAL_SEP=="02")
	gen qmb_plus_10=(DUAL_OCT=="02")
	gen qmb_plus_11=(DUAL_NOV=="02")
	gen qmb_plus_12=(DUAL_DEC=="02")
	gen     qmb_plus=((qmb_plus_01+qmb_plus_02+qmb_plus_03+qmb_plus_04+qmb_plus_05+qmb_plus_06+qmb_plus_07+qmb_plus_08+qmb_plus_09+qmb_plus_10+qmb_plus_11+qmb_plus_12)>=1)
	gen qmb_plus_maj=((qmb_plus_01+qmb_plus_02+qmb_plus_03+qmb_plus_04+qmb_plus_05+qmb_plus_06+qmb_plus_07+qmb_plus_08+qmb_plus_09+qmb_plus_10+qmb_plus_11+qmb_plus_12)>=6)

	gen slmb_plus_01=(DUAL_JAN=="04")
	gen slmb_plus_02=(DUAL_FEB=="04")
	gen slmb_plus_03=(DUAL_MAR=="04")
	gen slmb_plus_04=(DUAL_APR=="04")
	gen slmb_plus_05=(DUAL_MAY=="04")
	gen slmb_plus_06=(DUAL_JUN=="04")
	gen slmb_plus_07=(DUAL_JUL=="04")
	gen slmb_plus_08=(DUAL_AUG=="04")
	gen slmb_plus_09=(DUAL_SEP=="04")
	gen slmb_plus_10=(DUAL_OCT=="04")
	gen slmb_plus_11=(DUAL_NOV=="04")
	gen slmb_plus_12=(DUAL_DEC=="04")
	gen     slmb_plus=((slmb_plus_01+slmb_plus_02+slmb_plus_03+slmb_plus_04+slmb_plus_05+slmb_plus_06+slmb_plus_07+slmb_plus_08+slmb_plus_09+slmb_plus_10+slmb_plus_11+slmb_plus_12)>=1)
	gen slmb_plus_maj=((slmb_plus_01+slmb_plus_02+slmb_plus_03+slmb_plus_04+slmb_plus_05+slmb_plus_06+slmb_plus_07+slmb_plus_08+slmb_plus_09+slmb_plus_10+slmb_plus_11+slmb_plus_12)>=6)

	gen oth_full_dual_01=(DUAL_JAN=="08")
	gen oth_full_dual_02=(DUAL_FEB=="08")
	gen oth_full_dual_03=(DUAL_MAR=="08")
	gen oth_full_dual_04=(DUAL_APR=="08")
	gen oth_full_dual_05=(DUAL_MAY=="08")
	gen oth_full_dual_06=(DUAL_JUN=="08")
	gen oth_full_dual_07=(DUAL_JUL=="08")
	gen oth_full_dual_08=(DUAL_AUG=="08")
	gen oth_full_dual_09=(DUAL_SEP=="08")
	gen oth_full_dual_10=(DUAL_OCT=="08")
	gen oth_full_dual_11=(DUAL_NOV=="08")
	gen oth_full_dual_12=(DUAL_DEC=="08")
	gen     oth_full_dual=((oth_full_dual_01+oth_full_dual_02+oth_full_dual_03+oth_full_dual_04+oth_full_dual_05+oth_full_dual_06+oth_full_dual_07+oth_full_dual_08+oth_full_dual_09+oth_full_dual_10+oth_full_dual_11+oth_full_dual_12)>=1)
	gen oth_full_dual_maj=((oth_full_dual_01+oth_full_dual_02+oth_full_dual_03+oth_full_dual_04+oth_full_dual_05+oth_full_dual_06+oth_full_dual_07+oth_full_dual_08+oth_full_dual_09+oth_full_dual_10+oth_full_dual_11+oth_full_dual_12)>=6)

* Partial dual status
gen mcd_partial_01=(DUAL_JAN=="01" | DUAL_JAN=="03" | DUAL_JAN=="06")
gen mcd_partial_02=(DUAL_FEB=="01" | DUAL_FEB=="03" | DUAL_FEB=="06")
gen mcd_partial_03=(DUAL_MAR=="01" | DUAL_MAR=="03" | DUAL_MAR=="06")
gen mcd_partial_04=(DUAL_APR=="01" | DUAL_APR=="03" | DUAL_APR=="06")
gen mcd_partial_05=(DUAL_MAY=="01" | DUAL_MAY=="03" | DUAL_MAY=="06")
gen mcd_partial_06=(DUAL_JUN=="01" | DUAL_JUN=="03" | DUAL_JUN=="06")
gen mcd_partial_07=(DUAL_JUL=="01" | DUAL_JUL=="03" | DUAL_JUL=="06")
gen mcd_partial_08=(DUAL_AUG=="01" | DUAL_AUG=="03" | DUAL_AUG=="06")
gen mcd_partial_09=(DUAL_SEP=="01" | DUAL_SEP=="03" | DUAL_SEP=="06")
gen mcd_partial_10=(DUAL_OCT=="01" | DUAL_OCT=="03" | DUAL_OCT=="06")
gen mcd_partial_11=(DUAL_NOV=="01" | DUAL_NOV=="03" | DUAL_NOV=="06")
gen mcd_partial_12=(DUAL_DEC=="01" | DUAL_DEC=="03" | DUAL_DEC=="06")
gen     partial_dual=((mcd_partial_01+mcd_partial_02+mcd_partial_03+mcd_partial_04+mcd_partial_05+mcd_partial_06+mcd_partial_07+mcd_partial_08+mcd_partial_09+mcd_partial_10+mcd_partial_11+mcd_partial_12)>=1)
gen partial_dual_maj=((mcd_partial_01+mcd_partial_02+mcd_partial_03+mcd_partial_04+mcd_partial_05+mcd_partial_06+mcd_partial_07+mcd_partial_08+mcd_partial_09+mcd_partial_10+mcd_partial_11+mcd_partial_12)>=6)
gen dual=(full_dual==1 | partial_dual==1)
gen dual_maj=(full_dual_maj==1 | partial_dual_maj==1)

	* Partial dual status disaggregated
	gen qmb_only_01=(DUAL_JAN=="01")
	gen qmb_only_02=(DUAL_FEB=="01")
	gen qmb_only_03=(DUAL_MAR=="01")
	gen qmb_only_04=(DUAL_APR=="01")
	gen qmb_only_05=(DUAL_MAY=="01")
	gen qmb_only_06=(DUAL_JUN=="01")
	gen qmb_only_07=(DUAL_JUL=="01")
	gen qmb_only_08=(DUAL_AUG=="01")
	gen qmb_only_09=(DUAL_SEP=="01")
	gen qmb_only_10=(DUAL_OCT=="01")
	gen qmb_only_11=(DUAL_NOV=="01")
	gen qmb_only_12=(DUAL_DEC=="01")
	gen qmb_only    =((qmb_only_01+qmb_only_02+qmb_only_03+qmb_only_04+qmb_only_05+qmb_only_06+qmb_only_07+qmb_only_08+qmb_only_09+qmb_only_10+qmb_only_11+qmb_only_12)>=1)
	gen qmb_only_maj=((qmb_only_01+qmb_only_02+qmb_only_03+qmb_only_04+qmb_only_05+qmb_only_06+qmb_only_07+qmb_only_08+qmb_only_09+qmb_only_10+qmb_only_11+qmb_only_12)>=6)

	gen slmb_only_01=(DUAL_JAN=="03")
	gen slmb_only_02=(DUAL_FEB=="03")
	gen slmb_only_03=(DUAL_MAR=="03")
	gen slmb_only_04=(DUAL_APR=="03")
	gen slmb_only_05=(DUAL_MAY=="03")
	gen slmb_only_06=(DUAL_JUN=="03")
	gen slmb_only_07=(DUAL_JUL=="03")
	gen slmb_only_08=(DUAL_AUG=="03")
	gen slmb_only_09=(DUAL_SEP=="03")
	gen slmb_only_10=(DUAL_OCT=="03")
	gen slmb_only_11=(DUAL_NOV=="03")
	gen slmb_only_12=(DUAL_DEC=="03")
	gen     slmb_only=((slmb_only_01+slmb_only_02+slmb_only_03+slmb_only_04+slmb_only_05+slmb_only_06+slmb_only_07+slmb_only_08+slmb_only_09+slmb_only_10+slmb_only_11+slmb_only_12)>=1)
	gen slmb_only_maj=((slmb_only_01+slmb_only_02+slmb_only_03+slmb_only_04+slmb_only_05+slmb_only_06+slmb_only_07+slmb_only_08+slmb_only_09+slmb_only_10+slmb_only_11+slmb_only_12)>=6)

	gen qi_01=(DUAL_JAN=="06")
	gen qi_02=(DUAL_FEB=="06")
	gen qi_03=(DUAL_MAR=="06")
	gen qi_04=(DUAL_APR=="06")
	gen qi_05=(DUAL_MAY=="06")
	gen qi_06=(DUAL_JUN=="06")
	gen qi_07=(DUAL_JUL=="06")
	gen qi_08=(DUAL_AUG=="06")
	gen qi_09=(DUAL_SEP=="06")
	gen qi_10=(DUAL_OCT=="06")
	gen qi_11=(DUAL_NOV=="06")
	gen qi_12=(DUAL_DEC=="06")
	gen     qi=((qi_01+qi_02+qi_03+qi_04+qi_05+qi_06+qi_07+qi_08+qi_09+qi_10+qi_11+qi_12)>=1)
	gen qi_maj=((qi_01+qi_02+qi_03+qi_04+qi_05+qi_06+qi_07+qi_08+qi_09+qi_10+qi_11+qi_12)>=6)
	
* LIS Status
gen lis_any_01=( H_PDLS01=="2" | H_PDLS01=="3" | H_PDLS01=="4" | H_PDLS01=="5" )
gen lis_any_02=( H_PDLS02=="2" | H_PDLS02=="3" | H_PDLS02=="4" | H_PDLS02=="5" )
gen lis_any_03=( H_PDLS03=="2" | H_PDLS03=="3" | H_PDLS03=="4" | H_PDLS03=="5" )
gen lis_any_04=( H_PDLS04=="2" | H_PDLS04=="3" | H_PDLS04=="4" | H_PDLS04=="5" )
gen lis_any_05=( H_PDLS05=="2" | H_PDLS05=="3" | H_PDLS05=="4" | H_PDLS05=="5" )
gen lis_any_06=( H_PDLS06=="2" | H_PDLS06=="3" | H_PDLS06=="4" | H_PDLS06=="5" )
gen lis_any_07=( H_PDLS07=="2" | H_PDLS07=="3" | H_PDLS07=="4" | H_PDLS07=="5" )
gen lis_any_08=( H_PDLS08=="2" | H_PDLS08=="3" | H_PDLS08=="4" | H_PDLS08=="5" )
gen lis_any_09=( H_PDLS09=="2" | H_PDLS09=="3" | H_PDLS09=="4" | H_PDLS09=="5" )
gen lis_any_10=( H_PDLS10=="2" | H_PDLS10=="3" | H_PDLS10=="4" | H_PDLS10=="5" )
gen lis_any_11=( H_PDLS11=="2" | H_PDLS11=="3" | H_PDLS11=="4" | H_PDLS11=="5" )
gen lis_any_12=( H_PDLS12=="2" | H_PDLS12=="3" | H_PDLS12=="4" | H_PDLS12=="5" )
gen     lis=((lis_any_01+lis_any_02+lis_any_03+lis_any_04+lis_any_05+lis_any_06+lis_any_07+lis_any_08+lis_any_09+lis_any_10+lis_any_11+lis_any_12)>=1)
gen lis_maj=((lis_any_01+lis_any_02+lis_any_03+lis_any_04+lis_any_05+lis_any_06+lis_any_07+lis_any_08+lis_any_09+lis_any_10+lis_any_11+lis_any_12)>=6)

gen lis_partial_01=(H_PDLS01=="2" | H_PDLS01=="3" | H_PDLS01=="4")
gen lis_partial_02=(H_PDLS01=="2" | H_PDLS01=="3" | H_PDLS01=="4")
gen lis_partial_03=(H_PDLS01=="2" | H_PDLS01=="3" | H_PDLS01=="4")
gen lis_partial_04=(H_PDLS01=="2" | H_PDLS01=="3" | H_PDLS01=="4")
gen lis_partial_05=(H_PDLS01=="2" | H_PDLS01=="3" | H_PDLS01=="4")
gen lis_partial_06=(H_PDLS01=="2" | H_PDLS01=="3" | H_PDLS01=="4")
gen lis_partial_07=(H_PDLS01=="2" | H_PDLS01=="3" | H_PDLS01=="4")
gen lis_partial_08=(H_PDLS01=="2" | H_PDLS01=="3" | H_PDLS01=="4")
gen lis_partial_09=(H_PDLS01=="2" | H_PDLS01=="3" | H_PDLS01=="4")
gen lis_partial_10=(H_PDLS01=="2" | H_PDLS01=="3" | H_PDLS01=="4")
gen lis_partial_11=(H_PDLS01=="2" | H_PDLS01=="3" | H_PDLS01=="4")
gen lis_partial_12=(H_PDLS01=="2" | H_PDLS01=="3" | H_PDLS01=="4")
gen     lis_partial=((lis_partial_01+lis_partial_02+lis_partial_03+lis_partial_04+lis_partial_05+lis_partial_06+lis_partial_07+lis_partial_08+lis_partial_09+lis_partial_10+lis_partial_11+lis_partial_12)>=1)
gen lis_partial_maj=((lis_partial_01+lis_partial_02+lis_partial_03+lis_partial_04+lis_partial_05+lis_partial_06+lis_partial_07+lis_partial_08+lis_partial_09+lis_partial_10+lis_partial_11+lis_partial_12)>=6)

gen lis_full_01=( H_PDLS01=="5" )
gen lis_full_02=( H_PDLS02=="5" )
gen lis_full_03=( H_PDLS03=="5" )
gen lis_full_04=( H_PDLS04=="5" )
gen lis_full_05=( H_PDLS05=="5" )
gen lis_full_06=( H_PDLS06=="5" )
gen lis_full_07=( H_PDLS07=="5" )
gen lis_full_08=( H_PDLS08=="5" )
gen lis_full_09=( H_PDLS09=="5" )
gen lis_full_10=( H_PDLS10=="5" )
gen lis_full_11=( H_PDLS11=="5" )
gen lis_full_12=( H_PDLS12=="5" )
gen lis_full    =((lis_full_01+lis_full_02+lis_full_03+lis_full_04+lis_full_05+lis_full_06+lis_full_07+lis_full_08+lis_full_09+lis_full_10+lis_full_11+lis_full_12)>=1)
gen lis_full_maj=((lis_full_01+lis_full_02+lis_full_03+lis_full_04+lis_full_05+lis_full_06+lis_full_07+lis_full_08+lis_full_09+lis_full_10+lis_full_11+lis_full_12)>=6)

gen ma_01=(MAFLAG01=="MA")
gen ma_02=(MAFLAG02=="MA")
gen ma_03=(MAFLAG03=="MA")
gen ma_04=(MAFLAG04=="MA")
gen ma_05=(MAFLAG05=="MA")
gen ma_06=(MAFLAG06=="MA")
gen ma_07=(MAFLAG07=="MA")
gen ma_08=(MAFLAG08=="MA")
gen ma_09=(MAFLAG09=="MA")
gen ma_10=(MAFLAG10=="MA")
gen ma_11=(MAFLAG11=="MA")
gen ma_12=(MAFLAG12=="MA")
gen any_medicare_advantage=((ma_01+ma_02+ma_03+ma_04+ma_05+ma_06+ma_07+ma_08+ma_09+ma_10+ma_11+ma_12)>=1)

tab2 lis lis_full, missing cell row col
tab2 full_dual any_medicare_advantage, missing cell row col

keep baseid ssa_state_cd ssa_county_cd age age_cat sex_female new_enrollee esrd disabled died ///
full_dual full_dual_maj qmb_plus qmb_plus_maj slmb_plus slmb_plus_maj oth_full_dual oth_full_dual_maj partial_dual partial_dual_maj dual ///
dual_maj qmb_only qmb_only_maj slmb_only slmb_only_maj qi qi_maj lis lis_maj lis_full lis_full_maj  lis_partial lis_partial_maj any_medicare_advantage
sort baseid
save mcbs_bsf_$year.dta, replace

* Merge together with MCBS survey files 
use mcbs_merge_$year.dta, replace
merge 1:1 baseid using mcbs_bsf_$year.dta
keep if _merge==3
drop _merge

save mcbs_merge_$year.dta, replace


***********************************************************************************
* (3) Merge on HCC scores
***********************************************************************************

use "/home/eroberts/MCBS Stata setup files/HCC/HCC_$yr/hcc_$yr.dta", clear
keep hicno score_community score_institutional score_new_enrollee
rename hicno baseid
sort baseid
save hcc_fmt_$yr.dta, replace
use mcbs_merge_$year.dta, clear
merge 1:1 baseid using hcc_fmt_$yr.dta
keep if _merge==3
drop _merge

* Make 2 versions of the HCC score -- one using any_facility==1 to flag institutionalized people and another using in_ric2f==1 to flag inst. people
gen hcc_score=score_community
replace hcc_score=score_new_enrollee if new_enrollee==1
replace hcc_score=score_institutional if any_facility==1

gen hcc_score_2=score_community
replace hcc_score_2=score_new_enrollee if new_enrollee==1
replace hcc_score_2=score_institutional if in_ric2f==1

table dual, c(mean hcc_score mean hcc_score_2 mean score_community mean score_community mean score_institutional)

save mcbs_merge_$year.dta, replace


***********************************************************************************
* (4) Merge on income and asset files and construct income as proportion of FPL
***********************************************************************************

* Read income and asset file
use $iafile, clear
keep baseid F_INCYR D_DATAYR income //ssrrprob - income
rename F_INCYR f_incyr
destring D_DATAYR, gen(d_datayr)
sort baseid
save mcbs_income_asset_$year.dta, replace

* Merge to MCBS survey file
use mcbs_merge_$year.dta, clear
merge 1:1 baseid using mcbs_income_asset_$year.dta
keep if (_merge==1 | _merge==3) // note: a handful of observations (n=65 in 2013) will be in the mcbs_merge file but not the income and asset supplement file
drop _merge

* Examine correlation of income data from income and asset file vs. survey file
* Add a 'discrepant' indicator for income records that differ by more than 10%
summ income if income==. // `income' comes from the income and asset supplement file 
summ income_c if income_c==. // income_c comes from the core MCBS file 
corr income income_c // income from the supplementary file and the RIC-1 file are almost identical in 2012-13 (rho=0.97) but are less correlated in 2010-11 (rho=0.75)
gen discrepant=(abs((income-income_c)/income_c)>0.10 & income_c!=0) if income!=. & income_c!=.
tab discrepant, missing

* Poverty thresholds from ASPE
gen fpl_hh1_2010 = 10830
gen fpl_hh2_2010 = 14570
gen fpl_hh3_2010 = 18310
gen fpl_hh4_2010 = 22050
gen fpl_hh5_2010 = 25790
gen fpl_hh6_2010 = 29530
gen fpl_hh7_2010 = 33270

gen fpl_hh1_2011 = 10890
gen fpl_hh2_2011 = 14710
gen fpl_hh3_2011 = 18530
gen fpl_hh4_2011 = 22350
gen fpl_hh5_2011 = 26170
gen fpl_hh6_2011 = 29990
gen fpl_hh7_2011 = 33810

gen fpl_hh1_2012 = 11170
gen fpl_hh2_2012 = 15130
gen fpl_hh3_2012 = 19090
gen fpl_hh4_2012 = 23050
gen fpl_hh5_2012 = 27010
gen fpl_hh6_2012 = 30970
gen fpl_hh7_2012 = 34930
		
gen fpl_hh1_2013 = 11490
gen fpl_hh2_2013 = 15510
gen fpl_hh3_2013 = 19530
gen fpl_hh4_2013 = 23550
gen fpl_hh5_2013 = 27570
gen fpl_hh6_2013 = 31590
gen fpl_hh7_2013 = 35610

* Convert income to percentage points of the FPL using applicable thresholds from ASPE
gen fpl= .
replace fpl = fpl_hh1_$year if hh_size==1
replace fpl = fpl_hh2_$year if hh_size==2
replace fpl = fpl_hh3_$year if hh_size==3
replace fpl = fpl_hh4_$year if hh_size==4
replace fpl = fpl_hh5_$year if hh_size==5
replace fpl = fpl_hh6_$year if hh_size==6
replace fpl = fpl_hh7_$year if hh_size>=7

gen fpl_ratio = 100 * (income_c / fpl)
gen fpl_disregard = (12*hh_size*$month_inc_disregard)*(100/fpl)
tab hh_size if hh_size<=7, summ(fpl)
tab hh_size if hh_size<=7, summ(fpl_disregard)

* Generate an indicator for being below the FPL plus an income disregard and compare to dual and LIS enrollees
gen  below_fpl=(fpl_ratio<=135) //(fpl_ratio<=(100+fpl_disregard)) // below_fpl includes an income disregard
tab2 below_fpl full_dual, missing col row
tab2 below_fpl partial_dual, missing col row
tab2 below_fpl lis_full, missing col row
tab2 lis_full dual, missing col row

summ fpl_ratio if full_dual==1 & below_fpl==0, d
summ fpl_ratio if full_dual==1 & below_fpl==1, d

save mcbs_merge_$year.dta, replace


*********************************************************************************************
*********** STOP HERE UNTIL CONSTRUCTING EACH SET OF ANNUAL PERSON-LEVEL FILES **************
*********************************************************************************************

*>>> START <<< *
set more off
log using duals_chars_analyses_12232018.log, replace


***********************************************************************************
* (5) Create a consolidated dataset
***********************************************************************************

* Append MCBS files from 2010-13
use mcbs_merge_2010.dta, clear
append using mcbs_merge_2011.dta mcbs_merge_2012.dta mcbs_merge_2013.dta
tab2 year in_ric2f, missing row
table year if below_fpl==1, c(min fpl_ratio mean fpl_ratio max fpl_ratio)

* Only keep FFS Medicare enrollees
tab2 year any_medicare_advantage, missing row
tab2 full_dual any_medicare_advantage, missing row
keep if any_medicare_advantage==0 // EXCLUSION #1

* Randomly sample one annual observation per person
sort baseid
set seed 1234
gen double randn1=runiform(0,100)
gen double randn2=runiform(0,100)
sort baseid randn1 randn2
bysort baseid (randn1 randn2): gen person_ctr=_n
tab2 year person_ctr, missing col
keep if person_ctr==1 // EXCLUSION #2
sort ssa_state_cd year

* Count number of observations per state
tab ssa_state_cd, missing
bysort ssa_state_cd: egen obs_per_state=count(year)

keep if ssa_state_cd != "" // EXCLUSION #3
keep if ssa_state_cd != "40" // EXCLUSION #3 (PUERTO RICO)
keep if obs_per_state>=50 // EXCLUSION #3
tab2 ssa_state_cd year, missing
save mcbs_merge_2010_2013.dta, replace

* Append state policy variables
use state_policy_variables_10_13.dta, clear
sort ssa_state_cd year
save state_policy_variables_10_13.dta, replace

use mcbs_merge_2010_2013.dta, clear
merge m:1 ssa_state_cd year using state_policy_variables_10_13.dta
tab2 ssa_state_cd _merge, missing
keep if _merge==3
drop _merge
bysort ssa_state_cd: gen firstState=(_n==1) 
tab2 ssa_state_cd firstState, missing
bysort ssa_state_cd year: gen firstStateYear=(_n==1) 
tab2 firstStateYear year, missing

* Create an in-sample indicator
gen in_li_sample=(below_fpl==1 /*& discrepant!=1*/)
tab2 in_li_sample full_dual, col missing // BREAKDOWN OF FINAL ANALYTIC SAMPLE
tab2 in_li_sample full_dual_maj, col missing

save mcbs_merge_2010_2013.dta, replace // FINAL CONCATENATED DATASET


***********************************************************************************
* (6) Create an analtic file
***********************************************************************************

use mcbs_merge_2010_2013.dta, clear // start running main analyses from here

* Check sample sizes
tab firstState, missing
tab2 in_li_sample full_dual, missing row

* Create a numeric baseid (essentially, a BENE-ID)
encode baseid, gen(peridnum)

* Create a numeric stateid
encode ssa_state_cd, gen(statenum)

* xtset the data
xtset statenum

* Generate unscaled weight variables to conform with gllamm syntax
gen wt1=cs1yrwgt // level 1 = person
gen wt2=1 // level 2 = state

* Rescale weights
bys sudstrat sudunit: gen s_strat=1 if _n==1
replace s_strat=sum(s_strat)
bys s_strat: egen s_strat_obs=count(_n)
bys s_strat: egen sum_weight_strat=sum(cs1yrwgt)
gen scaled_wt1=wt1*(s_strat_obs/sum_weight_strat)
bys s_strat: egen chk_scaled_wt1=sum(scaled_wt1)
gen scaled_wt2=1

* Specify log of income variable
gen log_inc=log(income_c+1)

* Specify variable for the negative of log income
gen neg_log_inc=-1*log_inc

* Specify a variable for the negative of income
gen neg_income_c = -1*income_c

* Generate a log HCC score and HCC score categories
gen log_hcc_score = log(hcc_score)
summ hcc_score log_hcc_score, d
gen hcc_cat_1=(hcc_score< 1.0)
gen hcc_cat_2=(hcc_score>=1.0 & hcc_score<1.7)
gen hcc_cat_3=(hcc_score>=1.7)
table hcc_cat_1 hcc_cat_2 hcc_cat_3 if in_li_sample==1

* Generate an overweight indicator
gen obese=(bmi>=30 & bmi!=.)
tab obese, summ(bmi) missing

* Declare characteristics variables of interest
gen yr_2010=(year==2010)
gen yr_2011=(year==2011)
gen yr_2012=(year==2012)

gen rural_state=(state_long=="Alabama" | state_long=="Arkansas" | state_long=="Iowa" | state_long=="Kentucky" | state_long=="Nebraska" | state_long=="North Carolina" | state_long=="Oklahoma" | state_long=="South Carolina" | state_long=="Tennessee" | state_long=="West Virginia" | state_long=="Wisconsin" | state_long=="Wyoming")
tab2 state_long rural_state

********* FORMATTING OF POLICY VARIABLES *********
* Create an indicator for states that I think should have Medically Needy (MN) programs based on their 209(b) status but dont
gen discrepant_mn_209b=(medicallyneedy_none==1 & elig_209b==1) /* should turn on for Indiana, Missouri, Ohio, and Oklahoma */
tab2 state year if discrepant_mn_209b==1, missing

* Recode these states as having Medically Needy (MN) programs with spend-down thresholds equal to their categorical eligibility thresholds
replace medicallyneedy_none    =0 if   discrepant_mn_209b==1
replace medicallyneedy_50_under=1 if ( discrepant_mn_209b==1 & fullmedicaid_incomelimit<=50 ) 
replace medicallyneedy_51plus  =1 if ( discrepant_mn_209b==1 & fullmedicaid_incomelimit> 50 )
gen any_medicallyneedy=(medicallyneedy_50_under==1 | medicallyneedy_51plus)
tab2 any_medicallyneedy elig_209b if firstState==1, missing

* Categorize categorical Medicaid income limit as <=75% FPL vs >75% FPL
gen cat_medicaid_above75=(fullmedicaid_incomelimit>75)
table cat_medicaid_above75, c(min fullmedicaid_incomelimit mean fullmedicaid_incomelimit max fullmedicaid_incomelimit)

* Tabulate policy variables
tab2 cat_medicaid_above75 elig_1634 if firstStateYear==1 & year==2010, missing
tab any_medicallyneedy elig_209b if firstStateYear==1 & year==2010, missing

* 1634/income limits for categorical eligibility
gen elig_1634_inc_above75 = (elig_1634==1 & cat_medicaid_above75==1)
gen elig_1634_inc_below75 = (elig_1634==1 & cat_medicaid_above75==0)
gen elig_separate_inc_above75 = (elig_1634==0 & cat_medicaid_above75==1)
gen elig_separate_inc_below75 = (elig_1634==0 & cat_medicaid_above75==0)
tab elig_1634_inc_above75 if firstStateYear==1 & year==2010
tab elig_1634_inc_below75 if firstStateYear==1 & year==2010
tab elig_separate_inc_above75 if firstStateYear==1 & year==2010
tab elig_separate_inc_below75 if firstStateYear==1 & year==2010

tab fullmedicaid_incomelimit_75under if firstStateYear==1 & year==2010
tab fullmedicaid_incomelimit_76_99 if firstStateYear==1 & year==2010
tab fullmedicaid_incomelimit_100 if firstStateYear==1 & year==2010


***********************************************************************************
* (7) Analyses
***********************************************************************************
* Declare global variables
global xvars            income_c not_married educ_hs_or_less ///
                        count_told_diag gen_hlth_fair_poor hlth_worse_vs_lastyr hlth_lim_social trouble_see_or_blind trouble_hear_or_deaf diff_agility_mobility iadl_lims adl_lims obese
global basevars age sex_female disabled esrd reside_facility hcc_score yr_2010 yr_2011 yr_2012 
global socialvars_ind          neg_income_c not_married educ_hs_or_less
global clinicalvars_ind count_told_diag gen_hlth_fair_poor hlth_worse_vs_lastyr hlth_lim_social trouble_see_or_blind trouble_hear_or_deaf diff_agility_mobility iadl_lims adl_lims obese


* ANALYSIS 1: Descriptive statistics of low-income and low-income dually enrolled samples
	mean $basevars income_c fpl_ratio not_married educ_hs_or_less ///
                        count_told_diag gen_hlth_fair_poor hlth_worse_vs_lastyr hlth_lim_social trouble_see_or_blind trouble_hear_or_deaf diff_agility_mobility iadl_lims adl_lims obese [pweight=scaled_wt1] if in_li_sample==1
	mean $basevars income_c fpl_ratio not_married educ_hs_or_less ///
                        count_told_diag gen_hlth_fair_poor hlth_worse_vs_lastyr hlth_lim_social trouble_see_or_blind trouble_hear_or_deaf diff_agility_mobility iadl_lims adl_lims obese [pweight=scaled_wt1] if in_li_sample==1 & full_dual==1
	mean $basevars income_c fpl_ratio not_married educ_hs_or_less ///
                        count_told_diag gen_hlth_fair_poor hlth_worse_vs_lastyr hlth_lim_social trouble_see_or_blind trouble_hear_or_deaf diff_agility_mobility iadl_lims adl_lims obese [pweight=scaled_wt1] if in_li_sample==1 & full_dual!=1
	matrix t=J(33,2,.)
	local i=1
	foreach xvar in $basevars income_c fpl_ratio not_married educ_hs_or_less count_told_diag gen_hlth_fair_poor hlth_worse_vs_lastyr hlth_lim_social trouble_see_or_blind trouble_hear_or_deaf diff_agility_mobility iadl_lims adl_lims obese  {
		qui reg `xvar' full_dual if in_li_sample [pweight=scaled_wt1], vce(cluster state)
		matrix t[`i',1]=(abs(_b[full_dual]/_se[full_dual])>2)
		matrix t[`i',2]=2*(1-normal(abs(_b[full_dual]/_se[full_dual])))
		local i=`i'+1
	}
	matrix list t
	reg fpl_ratio full_dual if in_li_sample [pweight=scaled_wt1], vce(cluster state)


* ANALYSIS 2: Factor analysis
	* Identify factors
	factor $socialvars_ind $clinicalvars_ind if in_li_sample==1, pcf factor(4)
		rotate, varimax horst
		
	factor $socialvars_ind $clinicalvars_ind if in_li_sample==1, pf factor(4)
		matrix loadings=e(L)
		greigen
		rotate, varimax horst
		predict factor1 factor2 factor3 factor4

	reg factor1 $clinicalvars_ind if in_li_sample==1
	reg factor2 $socialvars_ind if in_li_sample==1

	* Assess Cronbach's a
	alpha $clinicalvars_ind if in_li_sample==1, item // IRR=0.68
	alpha $socialvars_ind if in_li_sample==1, item // IRR=0.01

	* Regression-based predictions
	reg full_dual $basevars $socialvars_ind $clinicalvars_ind if in_li_sample==1
	matrix betas=e(b)
	predict xb_full_dual, xb

		gen pred_base=_b[_cons]
		gen pred_social=0
		gen pred_clinical=0
		local i=1
		foreach xvar in $basevars {
			*summ `xvar'
			*di betas[1,`i']
			replace pred_base=pred_base + (betas[1,`i']*`xvar')
			local i=`i'+1
		}
		foreach xvar in $socialvars_ind {
			*summ `xvar'
			*di betas[1,`i']
			replace pred_social=pred_social + (betas[1,`i']*`xvar')
			local i=`i'+1
		}
		foreach xvar in $clinicalvars_ind {
			*summ `xvar'
			*di betas[1,`i']
			replace pred_clinical=pred_clinical + (betas[1,`i']*`xvar')
			local i=`i'+1
		}
	gen pred_social_clinical = pred_social + pred_clinical
	gen pred_total=pred_base + pred_social + pred_clinical
	summ pred_total xb_full_dual
	corr pred_total xb_full_dual

	* Normalize clinical and social scores, and the composite of clinical & social scores
	egen summ_wt=sum(scaled_wt1) if in_li_sample==1

	mean full_dual if in_li_sample==1 [pweight=scaled_wt1]
	matrix center=e(b)
	
	qui summ pred_clinical if in_li_sample==1
	scalar s1=r(mean)
	scalar s2=r(sd)
	gen pred_clinical_z=(pred_clinical-s1)/s2+center[1,1]
	label variable pred_clinical_z "Normalized and centered clinical risk score of patients"

	qui summ pred_social if in_li_sample==1
	scalar s3=r(mean)
	scalar s4=r(sd)
	gen pred_social_z=(pred_social-s3)/s4+center[1,1]
	label variable pred_social_z "Normalized and centered social risk score of patients"

	qui summ pred_social_clinical if in_li_sample==1
	scalar s5=r(mean)
	scalar s6=r(sd)
	gen pred_social_clinical_z=(pred_social_clinical-s5)/s6+center[1,1]
	label variable pred_social_clinical_z "Normalized and centered composite (social and clinical) risk score of patients"	

	* Correlation of regression-based predictions with factor scores
	corr factor1 pred_clinical_z factor2 pred_social_z pred_social_clinical_z if in_li_sample==1
		/*
		(obs=6,899)
			     |  factor1 pred_c~z  factor2 pr~ial_z pred_s..
		-------------+---------------------------------------------
		     factor1 |   1.0000
		pred_clini~z |   0.9010   1.0000
		     factor2 |   0.2219   0.3378   1.0000
		pred_s~ial_z |   0.0640   0.1047  -0.0126   1.0000
		pred_s~cal_z |   0.5543   0.6412   0.1796   0.8303   1.0000
		*/
	mean pred_social_clinical_z pred_clinical_z pred_social_z if in_li_sample==1 [pweight=scaled_wt1]

save mcbs_merge_2010_2013_work.dta, replace 

* ANALYSIS 3: Assess state variation in the characteristics of low-income Medicare beneficiaries and low-income duals

** Part 1: Base variables **
matrix base_estimates_lowincome=J(8,3,.)
matrix base_estimates_dual=J(8,3,.)
local i=1
foreach xvar in age sex_female disabled esrd reside_facility hcc_cat_1 hcc_cat_2 hcc_cat_3 {

*** LOW-INCOME SAMPLE ***
	* Calculate the grand mean
	qui mean `xvar' if in_li_sample==1 [pweight=scaled_wt1], vce(cluster statenum)
		matrix base_estimates_lowincome[`i',1]=e(b)
		local grmn=base_estimates_lowincome[`i',1]

	* Estimate the unadjusted and adjusted (for base characteristics state-level variation in each characteristic)
	 gllamm `xvar' if in_li_sample==1, i(statenum) pweight(scaled_wt) family(gaussian) link(identity) nocorrel // right model
		matrix x1=e(chol)
		matrix x2=x1*x1'
		matrix base_estimates_lowincome[`i',2]=x2 // variances of state effects
		
*** DUALLY ENROLLED (FULL-BENEFIT DUALS) AND LOW-INCOME SAMPLE ***
	* Calculate the grand mean
	qui mean `xvar' if full_dual==1 & in_li_sample==1 [pweight=scaled_wt1], vce(cluster statenum)
		matrix base_estimates_dual[`i',1]=e(b)
		local grmn=base_estimates_dual[`i',1]

	* Estimate the unadjusted and adjusted (for base characteristics state-level variation in each characteristic)
	 gllamm `xvar' if full_dual==1 & in_li_sample==1, i(statenum) pweight(scaled_wt) family(gaussian) link(identity) nocorrel // right model
	gllapred re_gllaam, u // save adjusted random effects estimates
		matrix x5=e(chol)
		matrix x6=x5*x5'
		matrix base_estimates_dual[`i',2]=x6 // variances of state effects
	
	* Comparing fixed vs. random effects predictions
	qui areg `xvar' if full_dual==1 & in_li_sample==1 [pweight=scaled_wt1], absorb(statenum)
	predict fe_areg, d
	twoway (scatter re_gllaamm1 fe_areg if full_dual==1 & in_li_sample==1, ///
	title("Weighted random vs. fixed effect predictions" "`xvar'") ytitle("Weighted RE predictions") xtitle("Weighted FE predictions") legend(lab(1 "Predictions") lab(2 "Identity line"))) || function y=x, ra(fe_areg) clpat(dash)
	graph export comp_base_`xvar'.png, replace
	drop re_gllaamm1 re_gllaams1 fe_areg

local i=`i'+1
}
matrix list base_estimates_lowincome
matrix list base_estimates_dual


** Part 2: Added variables **
matrix estimates_lowincome=J(25,3,.)
matrix estimates_dual=J(25,3,.)
local i=1
foreach xvar in fpl_ratio /*$xvars*/ pred_social_z pred_clinical_z pred_social_clinical_z {
	*di "**************** `xvar' ****************"
	
	*** LOW-INCOME SAMPLE ***
		* Calculate the grand mean
		qui mean `xvar' if in_li_sample==1 [pweight=scaled_wt1], vce(cluster statenum)
			matrix estimates_lowincome[`i',1]=e(b)
			local grmn=estimates_lowincome[`i',1]

		* Calculate state-level means and graph their distribution, overlaying 
		qui mean `xvar' if in_li_sample==1 [pweight=scaled_wt1], over(statenum)
			matrix b=e(b)
			matrix bp=b'
			svmat bp
			drop bp1
			matrix drop b bp

		* Estimate the unadjusted and adjusted (for base characteristics state-level variation in each characteristic)
		qui gllamm `xvar' if in_li_sample==1, i(statenum) pweight(scaled_wt) family(gaussian) link(identity) nocorrel // right model
			matrix x1=e(chol)
			matrix x2=x1*x1'
			matrix estimates_lowincome[`i',2]=x2 // variances of state effects
		qui gllamm `xvar' $basevars if in_li_sample==1, i(statenum) pweight(scaled_wt) family(gaussian) link(identity) nocorrel // right model
			matrix x3=e(chol)
			matrix x4=x3*x3'
			matrix estimates_lowincome[`i',3]=x4 // variances of state effects
			
	*** DUALLY ENROLLED (FULL-BENEFIT DUALS) AND LOW-INCOME SAMPLE ***
		* Calculate the grand mean
		qui mean `xvar' if full_dual==1 & in_li_sample==1 [pweight=scaled_wt1], vce(cluster statenum)
			matrix estimates_dual[`i',1]=e(b)
			local grmn=estimates_dual[`i',1]
			
		* Calculate state-level means and graph their distribution, overlaying 
		qui mean `xvar' if full_dual==1 & in_li_sample==1 [pweight=scaled_wt1], over(statenum)
			matrix b=e(b)
			matrix bp=b'
			svmat bp
			drop bp1
			matrix drop b bp

		* Estimate the unadjusted and adjusted (for base characteristics state-level variation in each characteristic)
		qui gllamm `xvar' if full_dual==1 & in_li_sample==1, i(statenum) pweight(scaled_wt) family(gaussian) link(identity) nocorrel // right model
			matrix x5=e(chol)
			matrix x6=x5*x5'
			matrix estimates_dual[`i',2]=x6 // variances of state effects
		
		qui gllamm `xvar' $basevars if full_dual==1 & in_li_sample==1, i(statenum) pweight(scaled_wt) family(gaussian) link(identity) nocorrel // right model
		gllapred re_gllaam, u // save adjusted random effects estimates
			matrix x7=e(chol)
			matrix x8=x7*x7'
			matrix estimates_dual[`i',3]=x8 // variances of state effects	
			
		* Comparing fixed vs. random effects predictions
		qui areg `xvar' $basevars if full_dual==1 & in_li_sample==1 [pweight=scaled_wt1], absorb(statenum)
		predict fe_areg, d
		twoway (scatter re_gllaamm1 fe_areg if full_dual==1 & in_li_sample==1, ///
		title("Adjusted weighted random vs. fixed effect predictions" "`xvar'") ytitle("Weighted RE predictions") xtitle("Weighted FE predictions") legend(lab(1 "Predictions") lab(2 "Identity line"))) || function y=x, ra(fe_areg) clpat(dash)
		graph export comp_`xvar'.png, replace
		reg re_gllaamm1 fe_areg if full_dual==1 & in_li_sample==1
			
		drop re_gllaamm1 re_gllaams1 fe_areg
	local i=`i'+1
}
matrix list estimates_lowincome
matrix list estimates_dual


* ANALYSIS 4: Compare differences between low-income Medicare beneficiaries and duals between states grouped on selected characteristics
	foreach xvar in fpl_ratio pred_social_z pred_clinical_z pred_social_clinical_z {
	
	qui areg `xvar' if in_li_sample==1 /*[pweight=scaled_wt1]*/, absorb(statenum)
	predict mn_u, d
	gen rat_x_mn_u=`xvar'/mn_u
	gen ln_x=log(`xvar')
	gen ln_mn_u=log(mn_u)
	gen ln_diff=log(`xvar')-log(mn_u)
		di "****************************** `xvar' ******************************"

		*reg `xvar' elig_1634 $basevars mn_u if full_dual==1 & in_li_sample==1 [pweight=scaled_wt1], vce(cluster statenum)

		*reg `xvar' cat_medicaid_above75 $basevars mn_u if full_dual==1 & in_li_sample==1 [pweight=scaled_wt1], vce(cluster statenum)

		*reg `xvar' any_medicallyneedy $basevars mn_u if full_dual==1 & in_li_sample==1 [pweight=scaled_wt1], vce(cluster statenum)

		* reg `xvar'  cat_medicaid_above75 any_medicallyneedy elig_1634 $basevars mn_u if full_dual==1 & in_li_sample==1 [pweight=scaled_wt1], vce(cluster statenum)

		reg `xvar'  elig_1634 cat_medicaid_above75 $basevars mn_u if full_dual==1 & in_li_sample==1 [pweight=scaled_wt1], vce(cluster statenum)

		reg `xvar'  cat_medicaid_above75 $basevars mn_u if full_dual==1 & in_li_sample==1 [pweight=scaled_wt1], vce(cluster statenum)

		reg `xvar'  i.cat_medicaid_above75##i.elig_1634 $basevars mn_u if full_dual==1 & in_li_sample==1 [pweight=scaled_wt1], vce(cluster statenum)
		
		* reg `xvar'  fullmedicaid_incomelimit_76_99 fullmedicaid_incomelimit_100  any_medicallyneedy elig_1634 $basevars mn_u if full_dual==1 & in_li_sample==1 [pweight=scaled_wt1], vce(cluster statenum)
		
		di "*********************************************************************"
	drop rat_x_mn_u mn_u ln_mn_u ln_x ln_diff

	}



*>>> STOP <<< *
log close
