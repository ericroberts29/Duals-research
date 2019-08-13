
*************************************************************************************************************************;
* Format HRS variables for Medicaid, MSP, and LIS eligibility and enrollment analyses									 ;
* Process sociodemographic and health status variables for analyses														 ;
* Uses RAND HRS file (2014), RAND HRS Imputations file (2014) focused on waves 9-12, and RAND FAT Files (waves 9-12)	 ;
* Version dated 8-7-2019																								 ;
* Eric T. Roberts, University of Pittsburgh, eric.roberts@pitt.edu														 ;
*************************************************************************************************************************;
/* Global note about weights applied in Wave 13 (2016):
The person-level weights are taken directly from the Tracker ?le and assigned to RwWTRESP and RwWTRESPE. 
Before Wave 13, the person-level weights apply to those residing in the community, so are zero for those living in a nursing home.
From Wave 13, HRS post-strati?es all respondents using the ACS 1-year Public Use Micro Sample (PUMS) data from the year corresponding
to the survey year. Therefore, nursing home residents who participated in a given wave no longer have a zero respondent level weight 
and the person-level weight is called RwWTRESPE. The full report can be found on the HRS website in the data description for the 2016 tracker ?le.
*/

/*************************************************************************************************************************
* Processing steps:
* (1) Link on RAND HRS longitudinal file (2014) to state geo IDs
*	Input datasets: rand.Randhrs1992_2014v2 (formatted 2014 RAND HRS public file), stgeo.Hrsxstate14 (state ID xwalk), trk.Trk2016tr_r (HRS tracker file)
*	Output datasets: d.randhrs_merge_1
* (2) Format insurance (including Medicare, Medicaid, CHAMPUS/VA, SSI, and SSDI) variables
*	Input datasets: d.randhrs_merge_1
*	Output datasets: d.randhrs_merge_2
* (3) Format sociodemographic variables (e.g., marital status, education, language, veteran's status)
*	Input datasets: randhrs_merge_2, f.language;
*	Output datasets: d.randhrs_merge_3
* (4) Calculate earned and unearned income
*	Input datasets: d.randhrs_merge_3, d.vet_income, d.self_employ_income (Veterans income and self-employment income comes from the RAND HRS detailed imputation file)
*	Output datasets: d.randhrs_merge_4
* (5) Calculate family size and FPL% using annual ASPE Federal Poverty Guidelines
*	Input datasets: d.randhrs_merge_4, f.fam_size, stgeo.Hrsxstate14
*	Intermediate datasets: d.randpov (dataset of poverty guidelines specific to year, family size, and continental US vs HI/AK)
*	Output datasets: d.randhrs_merge_5
* (6) Calculate assets (includes burial allowances for single and couple households, but life insurancep policies not yet modeled)
*	Input datasets: d.randhrs_merge_5
*	Output datasets: d.randhrs_merge_6
* (7) Link state-year-family size eligibility thresholds for Medicaid, MSP, and the LIS to the dataset, 
      and assess income and assets relative to these thresholds;
*	Input datasets: d.randhrs_merge_6, pove.consol_elig_rules_wx [x=9,...,12]
*	Intermediate datasets: d.elig_thresholds (dataset of state-specific program income/asset eligibility thesholds and disregards by year... merge to HHID-PN's state in wave x)
*	Output datasets: d.randhrs_merge_7
* (8) Assess household income and assets relative to program eligibility thresholds;
*	Input datasets: d.randhrs_merge_7
*	Output datasets: d.randhrs_merge_8
*       Several validation checks follow this section
* (9) Health care use, expenditures, and access to care variables;
*	Input datasets: randhrs_merge_8, f.Hc_cost_access (dataset containing some OOP cost and access variables from HRS FAT files)
*	Output datasets: d.randhrs_merge_9
* (10) Istitutionalization (nursing home residence for respondent or spouse) and self-reported health status variables;
*	Input datasets: randhrs_merge_9, f.blind (blindness indicators from HRS fat file)
*	Output datasets: d.randhrs_merge_10
	    Includes imputation steps to code missing health status information from prior survey wave if this information is missing in the subsequent wave.
		Waves 10-12 are imputed, wave 9 (first wave I process is not), so 'complete imputed' waves will be 10-12
* (11) Finalize an analytic file that excludes a small number of individuals living outside the US
       or with discrepant state records;
*	Input datasets: d.randhrs_merge_10
*	Output datasets: d.randhrs_merge_10_analyze
*************************************************************************************************************************/


*************************************************************************************************************************;
* Preamble;
*************************************************************************************************************************;
* Declare libraries;
libname rand 'C:\Users\HRSdata\Desktop\HRS\RAND HRS\1992_2016_files'; run; /* relevant file is randhrs1992_2016v1*/
libname stgeo 'C:\Users\HRSdata\Desktop\HRS\GEO\sas'; run; /* relevant file is Hrsxstate14 */
libname f 'C:\Users\HRSdata\Desktop\HRS\HRS Fat Files\analytic_subfiles'; run; /* stitch together annual fat files into an analytic subfile */
libname mcaid 'C:\Users\HRSdata\Desktop\HRS\Medicaid\sas'; run; /* xwalk file is Medicaidxref2016 */
libname mcare 'C:\Users\HRSdata\Desktop\HRS\Medicare\sas'; run; /* xwalk file is Xref2015medicare */
libname trk 'C:\Users\HRSdata\Desktop\HRS\Tracker\Tracker 2016 v2'; /* relevant file is Trk2016tr_r */
libname library 'C:\Users\HRSdata\Desktop\HRS\RAND HRS\1992_2016_files'; run; /* format library */
libname pove 'C:\Users\HRSdata\Desktop\HRS\Poverty and Eligibility'; run; /* ASPE poverty guidelines and program eligibility rules */
libname d 'C:\Users\HRSdata\Desktop\HRS\HRS Analyses\Analytic files'; run; /* working directory for exploratory analyses */

* Read in format library;
proc format library=library cntlin = library.sasfmts; run;


*************************************************************************************************************************;
* Declare variable lists;
*************************************************************************************************************************;
%let surveystat_vars = 	INW9 INW10 INW11 INW12 INW13 /*INWx are indicators you were in the survey wave*/ 
						R9IWSTAT R10IWSTAT R11IWSTAT R12IWSTAT R13IWSTAT 
						S9IWSTAT S10IWSTAT S11IWSTAT S12IWSTAT S13IWSTAT 
						R9WTRESP R10WTRESP R11WTRESP R12WTRESP /*new weighting:*/ R13WTRESPE;
%let statecodes 	 = 	STATEUSPS08 STATEUSPS10 STATEUSPS12 STATEUSPS14 /*need to add STATEUSPS16 when available*/
						STFIPS08 STFIPS10 STFIPS12 STFIPS14 /*need to add STFIPS16 when available*/ ;
%let proxy_stat_vars = 	R9PROXY R10PROXY R11PROXY R12PROXY R13PROXY;
%let socio_demo_vars = 	/*age at end of interview*/ R9AGEY_E R10AGEY_E R11AGEY_E R12AGEY_E R13AGEY_E 
						/*educational attainment (essentially static upon HRS entry) */ RAEDUC 
						/*marital status*/ R9MSTAT R10MSTAT R11MSTAT R12MSTAT R13MSTAT;
%let elig_prog_vars  = 	/* Receiving SSDI & SSI composite */ R9DSTAT R10DSTAT R11DSTAT R12DSTAT R13DSTAT /* Receiving SSDI 0/1 */ R9SSDI R10SSDI R11SSDI R12SSDI R13SSDI
						/* Medicare & Medicaid */ R9GOVMR R10GOVMR R11GOVMR R12GOVMR R13GOVMR R9GOVMD R10GOVMD R11GOVMD R12GOVMD R13GOVMD
						/* CHAMPUS/VA */ R9GOVVA R10GOVVA R11GOVVA R12GOVVA R13GOVVA;
%let veteran_status  = RAVETRN S9VETRN S10VETRN S11VETRN S12VETRN S13VETRN;
%let hh_size_vars    = H9CPL H10CPL H11CPL H12CPL H13CPL H9HHRES H10HHRES H11HHRES H12HHRES H13HHRES;
%let hhinc_vars = /*Total HHold / R+Sp only*/ H9ITOT H10ITOT H11ITOT H12ITOT H13ITOT;
%let hh_fin_resp = /*any financial respondent in HH*/ H9ANYFIN H10ANYFIN H11ANYFIN H12ANYFIN H13ANYFIN;
%let earned_income_vars   = R9IEARN R10IEARN R11IEARN R12IEARN R13IEARN S9IEARN S10IEARN S11IEARN S12IEARN S13IEARN;
%let unearned_income_vars = R9IPENA	R10IPENA	R11IPENA	R12IPENA	R13IPENA 	S9IPENA	S10IPENA	S11IPENA	S12IPENA	S13IPENA 	R9ISSDI	R10ISSDI	R11ISSDI	R12ISSDI 	R13ISSDI 	S9ISSDI	S10ISSDI	S11ISSDI	S12ISSDI	S13ISSDI
							R9ISDI	R10ISDI		R11ISDI		R12ISDI		R13ISDI 	S9ISDI	S10ISDI		S11ISDI		S12ISDI 	S13ISDI		R9ISRET	R10ISRET	R11ISRET	R12ISRET	R13ISRET	S9ISRET	S10ISRET	S11ISRET	S12ISRET	S13ISRET
							R9IUNWC	R10IUNWC	R11IUNWC	R12IUNWC	R13IUNWC 	S9IUNWC	S10IUNWC	S11IUNWC	S12IUNWC 	S13IUNWC	R9IGXFR	R10IGXFR	R11IGXFR	R12IGXFR	R13IGXFR	S9IGXFR	S10IGXFR	S11IGXFR	S12IGXFR	S13IGXFR
							H9ICAP 	H10ICAP 	H11ICAP 	H12ICAP		H13ICAP 	H9IOTHR H10IOTHR 	H11IOTHR 	H12IOTHR	H13IOTHR
							R9ISSI R10ISSI R11ISSI R12ISSI R13ISSI S9ISSI S10ISSI S11ISSI S12ISSI S13ISSI;
%let census_pov_vars  = H9POVTHR H10POVTHR H11POVTHR H12POVTHR H13POVTHR H9INPOVR H10INPOVR H11INPOVR H12INPOVR H13INPOVR H9POVFAM H10POVFAM H11POVFAM H12POVFAM H13POVFAM;
%let assset_vars = 		H9ARLES H10ARLES H11ARLES H12ARLES H13ARLES
						H9ABSNS H10ABSNS H11ABSNS H12ABSNS H13ABSNS
						H9AIRA 	H10AIRA  H11AIRA  H12AIRA  H13AIRA 
						H9ASTCK H10ASTCK H11ASTCK H12ASTCK H13ASTCK
						H9ACHCK H10ACHCK H11ACHCK H12ACHCK H13ACHCK
						H9ACD 	H10ACD 	 H11ACD   H12ACD   H13ACD
						H9ABOND H10ABOND H11ABOND H12ABOND H13ABOND
						H9AOTHR H10AOTHR H11AOTHR H12AOTHR H13AOTHR
						H9ATOTH H10ATOTH H11ATOTH H12ATOTH H13ATOTH
						H9ANETHB H10ANETHB H11ANETHB H12ANETHB H13ANETHB
						H9ATRAN	H10ATRAN H11ATRAN H12ATRAN H13ATRAN
						H9ADEBT H10ADEBT H11ADEBT H12ADEBT H13ADEBT;
%let hc_use_vars = 	/* hospital stays - any and # */ R9HOSP R10HOSP R11HOSP R12HOSP R13HOSP R9HSPTIM R10HSPTIM R11HSPTIM R12HSPTIM R13HSPTIM 
					/* nursing home stays - any and # */ R9NRSHOM R10NRSHOM R11NRSHOM R12NRSHOM R13NRSHOM R9NRSTIM R10NRSTIM R11NRSTIM R12NRSTIM R13NRSTIM
					/* Dr. visits - any and # */ R9DOCTOR R10DOCTOR R11DOCTOR R12DOCTOR R13DOCTOR R9DOCTIM R10DOCTIM R11DOCTIM R12DOCTIM R13DOCTIM
				/* RwOOPMD = estimated out-of-pocket medical costs since last interview or (for new interviewees) over last 2 years (see pp. 269-270 of 2016 RAND HRS documentation) */
				/* Beginning in Wave 6, the components of RwOOPMD are (1) hospital costs; (2) nursing home costs; (3) doctor visits costs; (4) dentist costs; 
					(5) outpatient surgery costs; (6) average monthly prescription drug costs; (7) home health care costs; and (8) special facilities costs */
					R9OOPMD R10OOPMD R11OOPMD R12OOPMD R13OOPMD;
%let hlthst_vars = /*sr health*/ R9SHLT R10SHLT R11SHLT R12SHLT R13SHLT /*adls*/ R9ADLA R10ADLA R11ADLA R12ADLA R13ADLA /*iadls*/ R9IADLZA R10IADLZA R11IADLZA R12IADLZA R13IADLZA
					/*strength and mobility*/ 	R9WALKSA 	R9CLIMSA 	R9STOOPA 	R9PUSHA 
												R10WALKSA 	R10CLIMSA 	R10STOOPA 	R10PUSHA 
												R11WALKSA 	R11CLIMSA 	R11STOOPA 	R11PUSHA 
												R12WALKSA 	R12CLIMSA 	R12STOOPA 	R12PUSHA 
												R13WALKSA 	R13CLIMSA 	R13STOOPA 	R13PUSHA
												R9CHAIRA R10CHAIRA R11CHAIRA R12CHAIRA R13CHAIRA 
												R9LIFTA R10LIFTA R11LIFTA R12LIFTA R13LIFTA 
												R9ARMSA R10ARMSA R11ARMSA R12ARMSA R13ARMSA
					/* BMI */ R9BMI R10BMI R11BMI R12BMI R13BMI
					/* 'ever' flags for health conditions */ R9CONDE R10CONDE R11CONDE R12CONDE R13CONDE R9HIBPE R10HIBPE R11HIBPE R12HIBPE R13HIBPE R9DIABE R10DIABE R11DIABE R12DIABE R13DIABE R9CANCRE R10CANCRE R11CANCRE R12CANCRE R13CANCRE
					/* 'ever' flags cond'd */ R9LUNGE R10LUNGE R11LUNGE R12LUNGE R13LUNGE R9HEARTE R10HEARTE R11HEARTE R12HEARTE R13HEARTE R9STROKE R10STROKE R11STROKE R12STROKE R13STROKE R9PSYCHE R10PSYCHE R11PSYCHE R12PSYCHE R13PSYCHE R9ARTHRE R10ARTHRE R11ARTHRE R12ARTHRE R13ARTHRE
					/* depression index*/ R9CESD R10CESD R11CESD R12CESD R13CESD
					/* cognition summary score -- RwCOGTOT summarize word recall and mental status together.  Special missing values have been assigned to cognition measures when the Respondent has no non-proxy interviews (.X), the speci?c interview was by proxy (.S), 
					cognition measure not asked (reinterview/lt 65) (.N) */ R9COGTOT R10COGTOT R11COGTOT R12COGTOT /*not available as of 8-7-19 RAND HRS download R13COGTOT */
					/*# days drank alcohol per wk*/ R9DRINKD R10DRINKD R11DRINKD R12DRINKD R13DRINKD /*ever smoked*/ R9SMOKEV R10SMOKEV R11SMOKEV R12SMOKEV R13SMOKEV /*currently smokes*/ R9SMOKEV R10SMOKEV R11SMOKEV R12SMOKEV R13SMOKEV;
%let hh_nh_vars =  R9NHMLIV R10NHMLIV R11NHMLIV R12NHMLIV R13NHMLIV S9NHMLIV S10NHMLIV S11NHMLIV S12NHMLIV S13NHMLIV H9NHMLIV H10NHMLIV H11NHMLIV H12NHMLIV H13NHMLIV;


*************************************************************************************************************************;
* (1) Link on RAND HRS longitudinal file (2014) to state geo IDs														 ;
*************************************************************************************************************************;
proc sort data=rand.Randhrs1992_2016v1; by HHID PN; run;
proc sort data=stgeo.Hrsxstate14; by HHID PN; run;
proc sort data=trk.Trk2016tr_r; by HHID PN; run;

* Link datasets;
data d.randhrs_merge_1;
merge 	rand.Randhrs1992_2016v1 (in=in1 keep=HHID PN &surveystat_vars. &proxy_stat_vars. &socio_demo_vars. &elig_prog_vars. &hhinc_vars. &hh_fin_resp. &earned_income_vars. &unearned_income_vars. 
			&hc_use_vars. &hlthst_vars. &assset_vars. &veteran_status. &census_pov_vars. &hh_size_vars. &hh_nh_vars.)
		stgeo.Hrsxstate14 (in=in2 keep=HHID PN &statecodes.)
		trk.Trk2016tr_r   (in=in3 keep=HHID PN LIWYEAR MIWYEAR NIWYEAR OIWYEAR PIWYEAR BIRTHMO BIRTHYR LAGE MAGE NAGE OAGE PAGE LALIVE MALIVE NALIVE OALIVE PALIVE LINSAMP MINSAMP NINSAMP OINSAMP PINSAMP /*subHH vars:*/ LSUBHH MSUBHH NSUBHH OSUBHH PSUBHH
				/*weighting vars:*/ LWGTR MWGTR NWGTR OWGTR /*new weighting:*/ PWGTRE /*why 0 weight vars:*/ LWHY0RWT MWHY0RWT NWHY0RWT OWHY0RWT /*new weighting:*/ PWHY0RWTE /* survey year vars */ LIWYEAR MIWYEAR NIWYEAR OIWYEAR PIWYEAR);
by HHID PN;
if in1; run;

* Order variables and format basic demographic characteristics;
data d.randhrs_merge_1;
retain HHID PN LAGE MAGE NAGE OAGE PAGE LALIVE MALIVE NALIVE OALIVE PALIVE LINSAMP MINSAMP NINSAMP OINSAMP PINSAMP LWGTR MWGTR NWGTR OWGTR /*new weighting:*/ PWGTRE LIWYEAR MIWYEAR NIWYEAR OIWYEAR PIWYEAR &surveystat_vars. &statecodes. &proxy_stat_vars. &socio_demo_vars. &elig_prog_vars. &hhinc_vars. &hh_fin_resp. &earned_income_vars. &unearned_income_vars. &assset_vars. 
		&veteran_status. &census_pov_vars. &hh_size_vars. &hlthst_vars. &hc_use_vars. &hh_nh_vars.;
set d.randhrs_merge_1 (keep=HHID PN LAGE MAGE NAGE OAGE PAGE LALIVE MALIVE NALIVE OALIVE PALIVE LINSAMP MINSAMP NINSAMP OINSAMP PINSAMP LWGTR MWGTR NWGTR OWGTR /*new weighting:*/ PWGTRE LIWYEAR MIWYEAR NIWYEAR OIWYEAR PIWYEAR &surveystat_vars. &statecodes. &proxy_stat_vars. &socio_demo_vars. &elig_prog_vars. &hhinc_vars. &hh_fin_resp. &earned_income_vars. &unearned_income_vars. &assset_vars. 
		&veteran_status. &census_pov_vars. &hh_size_vars. &hlthst_vars. &hc_use_vars. &hh_nh_vars.); run;

* Tabulate wave by interview years;
proc freq data=d.randhrs_merge_1;
tables inw9 * LIWYEAR / missing;
tables inw10 * MIWYEAR / missing;
tables inw11 * NIWYEAR / missing;
tables inw12 * OIWYEAR / missing;
tables inw13 * PIWYEAR / missing; run;

*************************************************************************************************************************;
* (2) Format insurance (including Medicare, Medicaid, CHAMPUS/VA, SSI, and SSDI) variables								 ;
*************************************************************************************************************************;
data d.randhrs_merge_2;
set d.randhrs_merge_1;

svy_medicaid_w9=.; svy_medicaid_w10=.; svy_medicaid_w11=.; svy_medicaid_w12=.; svy_medicaid_w13=.;
svy_medicare_w9=.; svy_medicare_w10=.; svy_medicare_w11=.; svy_medicare_w12=.; svy_medicare_w13=.;
svy_ssdi_w9=.; svy_ssdi_w10=.; svy_ssdi_w11=.; svy_ssdi_w12=.; svy_ssdi_w13=.;
svy_ssi_w9=.; svy_ssi_w10=.; svy_ssi_w11=.; svy_ssi_w12=.; svy_ssi_w13=.;
va_champus_w9=.; va_champus_w10=.; va_champus_w11=.; va_champus_w12=.; va_champus_w13=.;

array svy_medicare {5} R9GOVMR R10GOVMR R11GOVMR R12GOVMR R13GOVMR;
array svy_medicaid {5} R9GOVMD R10GOVMD R11GOVMD R12GOVMD R13GOVMD;
array svy_ssdi_ssi {5} R9DSTAT R10DSTAT R11DSTAT R12DSTAT R13DSTAT;
array va {5} R9GOVVA R10GOVVA R11GOVVA R12GOVVA R13GOVVA;
array svy_medicare_cd {5} svy_medicare_w9 svy_medicare_w10 svy_medicare_w11 svy_medicare_w12 svy_medicare_w13;
array svy_medicaid_cd {5} svy_medicaid_w9 svy_medicaid_w10 svy_medicaid_w11 svy_medicaid_w12 svy_medicaid_w13;
array svy_ssdi_cd {5} svy_ssdi_w9 svy_ssdi_w10 svy_ssdi_w11 svy_ssdi_w12 svy_ssdi_w13;
array svy_ssi_cd {5} svy_ssi_w9 svy_ssi_w10 svy_ssi_w11 svy_ssi_w12 svy_ssi_w13;
array va_cd {5} va_champus_w9 va_champus_w10 va_champus_w11 va_champus_w12 va_champus_w13;

do i=1 to 5;
	if svy_medicare[i] in (0, 1) then svy_medicare_cd[i]=(svy_medicare[i]=1);
	if svy_medicaid[i] in (0, 1) then svy_medicaid_cd[i]=(svy_medicaid[i]=1);
	if svy_ssdi_ssi[i] ne . then svy_ssdi_cd[i]=(svy_ssdi_ssi[i] in (20:22));
	if svy_ssdi_ssi[i] ne . then svy_ssi_cd[i]=(svy_ssdi_ssi[i] in (2, 12, 22));
	if va[i] in (0, 1) then va_cd[i]=(va[i]=1);
end;
run;


*************************************************************************************************************************;
* (3) Format sociodemographic variables (e.g., marital status, education, language, veteran's status)					 ;
*************************************************************************************************************************;
* Format sociodemographic variables;
data d.randhrs_merge_3;
set d.randhrs_merge_2;
if RAEDUC ne .M then do; educ_lt_hs=(RAEDUC=1); educ_hs=(RAEDUC in (2:3)); educ_collplus=(RAEDUC in (4:5)); end;

* Marital status indicators;
married_partnered_w9=.;
married_partnered_w10=.;
married_partnered_w11=.;
married_partnered_w12=.;
married_partnered_w13=.;

sep_divorced_w9=.;
sep_divorced_w10=.;
sep_divorced_w11=.;
sep_divorced_w12=.;
sep_divorced_w13=.;

widowed_w9=.;
widowed_w10=.;
widowed_w11=.;
widowed_w12=.;
widowed_w13=.;

nev_married_w9=.;
nev_married_w10=.;
nev_married_w11=.;
nev_married_w12=.;
nev_married_w13=.;

ever_married_w9=.;
ever_married_w10=.;
ever_married_w11=.;
ever_married_w12=.;
ever_married_w13=.;

array mp {5} married_partnered_w9 married_partnered_w10 married_partnered_w11 married_partnered_w12 married_partnered_w13;
array sd {5} sep_divorced_w9 sep_divorced_w10 sep_divorced_w11 sep_divorced_w12 sep_divorced_w13;
array widow {5} widowed_w9 widowed_w10 widowed_w11 widowed_w12 widowed_w13;
array nm {5} nev_married_w9 nev_married_w10 nev_married_w11 nev_married_w12 nev_married_w13;
array em {5} ever_married_w9 ever_married_w10 ever_married_w11 ever_married_w12 ever_married_w13;
array married {5} R9MSTAT R10MSTAT R11MSTAT R12MSTAT R13MSTAT;
array resp {5} INW9 INW10 INW11 INW12 INW13;

do i=1 to 5;
	if married[i] in (1:8) then do;
		mp[i]   =(married[i] in (1:3));
		sd[i]   =(married[i] in (4:6));
		widow[i]=(married[i] = 7);
		nm[i]	=(married[i] = 8);
		em[i]   =(married[i] in (1:7));
	end;
end;

* Veterans flag indicators;
* -- either respondent or spouse in wave is a veteran -- will take out veterans because they receive VA benefits and hard to parse Veterans benefits from unearned income exceptions;
veteran_hh_w9=.;
veteran_hh_w10=.;
veteran_hh_w11=.;
veteran_hh_w12=.;
veteran_hh_w13=.;
array spou_veteran {5} S9VETRN S10VETRN S11VETRN S12VETRN S13VETRN; /* primary Respondents get a single 0/1 veteran flag, spouses get a per-wave flag */
array veteran_hh{5} veteran_hh_w9 veteran_hh_w10 veteran_hh_w11 veteran_hh_w12 veteran_hh_w13;

do i=1 to 5;
	if married[i] in (1:8) then do;
		mp[i]   =(married[i] in (1:3));
		sd[i]   =(married[i] in (4:6));
		widow[i]=(married[i] = 7);
		nm[i]	=(married[i] = 8);
	end;
end;

* Finalize flag denoting presence of a veteran in the household;
do i=1 to 5;
	if resp[i]=1 then do;
		veteran_hh[i]=max((spou_veteran[i]=1),(RAVETRN=1));
	end;
end; run;

data d.randhrs_merge_3;
merge d.randhrs_merge_3 (in=in1) f.language (in=in2 keep=HHID PN language_sub english_w9 english_w10 english_w11 english_w12 english_w13);
by HHID PN;
if in1; run;


*************************************************************************************************************************;
* (4) Calculate earned and unearned income;
*************************************************************************************************************************;
* Merge on Veterans benefits and self-employment income from th RAND HRS Detailed Imputation file;
proc sort data=d.randhrs_merge_3; by HHID PN; run;
proc sort data=d.vet_income; by HHID PN; run;
proc sort data=d.self_employ_income; by HHID PN; run;
data d.randhrs_merge_4;
merge d.randhrs_merge_3 (in=in1) d.vet_income (in=in2) d.self_employ_income (in=in3);
by HHID PN;
if in1; run;

proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check self-employment income w9'; class inw9; var hh_selfemploy_inc_w9; run;
proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check self-employment income w10'; class inw10; var hh_selfemploy_inc_w10; run;
proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check self-employment income w11'; class inw11; var hh_selfemploy_inc_w11; run;
proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check self-employment income w12'; class inw12; var hh_selfemploy_inc_w12; run;
proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check self-employment income w13'; class inw13; var hh_selfemploy_inc_w13; run;


* Calculate Medicaid countable income: earned income and unearned income except for need-based assistance payments (exclusion applies to SSI) and govt transfers;
data d.randhrs_merge_4;
set d.randhrs_merge_4;

* Financial respondent in HH flag;
finr_hh_w9=.;
finr_hh_w10=.;
finr_hh_w11=.;
finr_hh_w12=.;
finr_hh_w13=.;

* Countable income totals for Medicaid income calcs;
tot_earned_inc_w9=.;
tot_earned_inc_w10=.;
tot_earned_inc_w11=.;
tot_earned_inc_w12=.;
tot_earned_inc_w13=.;

tot_inc_w_ssi_w9=.;  /*total income WITH SSI */
tot_inc_w_ssi_w10=.;
tot_inc_w_ssi_w11=.;
tot_inc_w_ssi_w12=.;
tot_inc_w_ssi_w13=.;

tot_inc_x_ssi_w9=.; /*total income EX SSI */
tot_inc_x_ssi_w10=.;
tot_inc_x_ssi_w11=.;
tot_inc_x_ssi_w12=.;
tot_inc_x_ssi_w13=.;

tot_unearned_inc_w_ssi_w9=.; /*unearned income WITH SSI */
tot_unearned_inc_w_ssi_w10=.;
tot_unearned_inc_w_ssi_w11=.;
tot_unearned_inc_w_ssi_w12=.;
tot_unearned_inc_w_ssi_w13=.;

tot_unearned_inc_x_ssi_w9=.; /*unearned income EX SSI */
tot_unearned_inc_x_ssi_w10=.;
tot_unearned_inc_x_ssi_w11=.;
tot_unearned_inc_x_ssi_w12=.;
tot_unearned_inc_x_ssi_w13=.;

* Variables for fixed household income ($) and the fraction of household income that is fixed;
inc_fixed_w_ssi_w9=.;
inc_fixed_w_ssi_w10=.;
inc_fixed_w_ssi_w11=.;
inc_fixed_w_ssi_w12=.;
inc_fixed_w_ssi_w13=.;

inc_fixed_x_ssi_w9=.;
inc_fixed_x_ssi_w10=.;
inc_fixed_x_ssi_w11=.;
inc_fixed_x_ssi_w12=.;
inc_fixed_x_ssi_w13=.;

frac_inc_fixed_w_ssi_w9=.;
frac_inc_fixed_w_ssi_w10=.;
frac_inc_fixed_w_ssi_w11=.;
frac_inc_fixed_w_ssi_w12=.;
frac_inc_fixed_w_ssi_w13=.;

frac_inc_fixed_x_ssi_w9=.;
frac_inc_fixed_x_ssi_w10=.;
frac_inc_fixed_x_ssi_w11=.;
frac_inc_fixed_x_ssi_w12=.;
frac_inc_fixed_x_ssi_w13=.;

fixed_income_ind_w_ssi_w9=.; /* define individuals on fixed income have either 0 income or derive >=80% of income from fixed sources */
fixed_income_ind_w_ssi_w10=.; 
fixed_income_ind_w_ssi_w11=.; 
fixed_income_ind_w_ssi_w12=.; 
fixed_income_ind_w_ssi_w13=.; 

fixed_income_ind_x_ssi_w9=.; 
fixed_income_ind_x_ssi_w10=.; 
fixed_income_ind_x_ssi_w11=.; 
fixed_income_ind_x_ssi_w12=.; 
fixed_income_ind_x_ssi_w13=.; 

* Make an HRS income reconciliation variable for checking;
tot_hrs_inc_w9=.;
tot_hrs_inc_w10=.;
tot_hrs_inc_w11=.;
tot_hrs_inc_w12=.;
tot_hrs_inc_w13=.;

* SSI Income;
ssi_w9=.;
ssi_w10=.;
ssi_w11=.;
ssi_w12=.;
ssi_w13=.;

ssi_check_w9=.;
ssi_check_w10=.;
ssi_check_w11=.;
ssi_check_w12=.;
ssi_check_w13=.;

* Declare arrays for response, financial respondent indicators;
array resp_flag {5} R9IWSTAT R10IWSTAT R11IWSTAT R12IWSTAT R13IWSTAT;
array spou_flag {5} S9IWSTAT S10IWSTAT S11IWSTAT S12IWSTAT S13IWSTAT;
array finr_hh_flag {5} H9ANYFIN H10ANYFIN H11ANYFIN H12ANYFIN H13ANYFIN;
array any_finr_hh {5} finr_hh_w9 finr_hh_w10 finr_hh_w11 finr_hh_w12 finr_hh_w13;

* Declare arrays for income components;
array resp_earned_income {5} R9IEARN R10IEARN R11IEARN R12IEARN R13IEARN;
array spou_earned_income {5} S9IEARN S10IEARN S11IEARN S12IEARN S13IEARN;
array hh_selfemploy_income {5} hh_selfemploy_inc_w9 hh_selfemploy_inc_w10 hh_selfemploy_inc_w11 hh_selfemploy_inc_w12 hh_selfemploy_inc_w13;
array tot_hh_income {5} H9ITOT H10ITOT H11ITOT H12ITOT H13ITOT; /*RAND-HRS calculation of total household income */
array tot_earned_income {5} tot_earned_inc_w9 tot_earned_inc_w10 tot_earned_inc_w11 tot_earned_inc_w12 tot_earned_inc_w13;
array ssi_income {5} ssi_w9 ssi_w10 ssi_w11 ssi_w12 ssi_w13;
array tot_income_w_ssi {5} tot_inc_w_ssi_w9 tot_inc_w_ssi_w10 tot_inc_w_ssi_w11 tot_inc_w_ssi_w12 tot_inc_w_ssi_w13;
array tot_income_x_ssi {5} tot_inc_x_ssi_w9 tot_inc_x_ssi_w10 tot_inc_x_ssi_w11 tot_inc_x_ssi_w12 tot_inc_x_ssi_w13;
array tot_unearn_income_w_ssi {5} tot_unearned_inc_w_ssi_w9 tot_unearned_inc_w_ssi_w10 tot_unearned_inc_w_ssi_w11 tot_unearned_inc_w_ssi_w12 tot_unearned_inc_w_ssi_w13;
array tot_unearn_income_x_ssi {5} tot_unearned_inc_x_ssi_w9 tot_unearned_inc_x_ssi_w10 tot_unearned_inc_x_ssi_w11 tot_unearned_inc_x_ssi_w12 tot_unearned_inc_x_ssi_w13;
array income_fixed_w_ssi {5} inc_fixed_w_ssi_w9 inc_fixed_w_ssi_w10 inc_fixed_w_ssi_w11 inc_fixed_w_ssi_w12 inc_fixed_w_ssi_w13;
array income_fixed_x_ssi {5} inc_fixed_x_ssi_w9 inc_fixed_x_ssi_w10 inc_fixed_x_ssi_w11 inc_fixed_x_ssi_w12 inc_fixed_x_ssi_w13;
array frac_income_fixed_w_ssi {5} frac_inc_fixed_w_ssi_w9 frac_inc_fixed_w_ssi_w10 frac_inc_fixed_w_ssi_w11 frac_inc_fixed_w_ssi_w12 frac_inc_fixed_w_ssi_w13;
array frac_income_fixed_x_ssi {5} frac_inc_fixed_x_ssi_w9 frac_inc_fixed_x_ssi_w10 frac_inc_fixed_x_ssi_w11 frac_inc_fixed_x_ssi_w12 frac_inc_fixed_x_ssi_w13;
array fixed_ind_w_ssi {5} fixed_income_ind_w_ssi_w9 fixed_income_ind_w_ssi_w10 fixed_income_ind_w_ssi_w11 fixed_income_ind_w_ssi_w12 fixed_income_ind_w_ssi_w13;
array fixed_ind_x_ssi {5} fixed_income_ind_x_ssi_w9 fixed_income_ind_x_ssi_w10 fixed_income_ind_x_ssi_w11 fixed_income_ind_x_ssi_w12 fixed_income_ind_x_ssi_w13;
array tot_hrs_income {5} tot_hrs_inc_w9 tot_hrs_inc_w10 tot_hrs_inc_w11 tot_hrs_inc_w12 tot_hrs_inc_w13;
array ssi_check {5} ssi_check_w9 ssi_check_w10 ssi_check_w11 ssi_check_w12 ssi_check_w13;

** Income arrays: >> Denotes << countable income per SSI definitions **;
* *>>Pension and annuities /*counts towards unearned income*/;
	array resp_unearn_income_1 {5} R9IPENA	R10IPENA	R11IPENA	R12IPENA R13IPENA;
	array spou_unearn_income_1 {5} S9IPENA	S10IPENA	S11IPENA	S12IPENA S13IPENA;
* *SSI & SSDI /*most SSI -- except state supplements -- counts towards unearned income */;
	array resp_unearn_income_2 {5} R9ISSDI	R10ISSDI	R11ISSDI	R12ISSDI R13ISSDI;
	array spou_unearn_income_2 {5} S9ISSDI	S10ISSDI	S11ISSDI	S12ISSDI S13ISSDI;
* *>>SSDI /*counts towards unearned income*/;
	array resp_unearn_income_2a {5} R9ISDI	R10ISDI		R11ISDI		R12ISDI R13ISDI;
	array spou_unearn_income_2a {5} S9ISDI	S10ISDI		S11ISDI		S12ISDI S13ISDI;
* *SSI income /*technically counts towards unearned income */;
	array resp_unearn_income_2b {5} R9ISSI R10ISSI R11ISSI R12ISSI R13ISSI;
	array spou_unearn_income_2b {5} S9ISSI S10ISSI S11ISSI S12ISSI S13ISSI;
* *>>Social Security retirement /*counts towards unearned income*/;
	array resp_unearn_income_3 {5} R9ISRET	R10ISRET	R11ISRET	R12ISRET R13ISRET;
	array spou_unearn_income_3 {5} S9ISRET	S10ISRET	S11ISRET	S12ISRET S13ISRET;
* *>>Workers comp /*counts towards unearned income*/;
	array resp_unearn_income_4 {5} R9IUNWC	R10IUNWC	R11IUNWC	R12IUNWC R13IUNWC;
	array spou_unearn_income_4 {5} S9IUNWC	S10IUNWC	S11IUNWC	S12IUNWC S13IUNWC;
* *>>Veterans benefits /*counts towards unearned income*/;
	array resp_unearn_income_5 {5} R9IVET R10IVET R11IVET R12IVET R13IVET;
	array spou_unearn_income_5 {5} S9IVET S10IVET S11IVET S12IVET S13IVET;
* Other gov't transfer /*see pp 982 of RAND-HRS documentation: RwIGXFR sums the Respondent’s income from veterans’ benefits, welfare, and food stamps:  RwIVET, R2IVETn, HwIFOOD, R2IWELF, and HwIWELF .  Welfare and food stamps aren't in other govt transfers but veterans' benefits are*/;
	* Only use for detailed income reconciliations;
	array resp_unearn_income_6 {5} R9IGXFR	R10IGXFR	R11IGXFR	R12IGXFR R13IGXFR;
	array spou_unearn_income_6 {5} S9IGXFR	S10IGXFR	S11IGXFR	S12IGXFR S13IGXFR;
* *>>Household capital income;
	array hh_cap_income {5} H9ICAP H10ICAP H11ICAP H12ICAP H13ICAP;
* *>>Household other income /*HwIOTHR sums alimony, other income, and lump sums from insurance, pension, and inheritance*/;
	array hh_oth_income {5} H9IOTHR H10IOTHR H11IOTHR H12IOTHR H13IOTHR;
do i=1 to 5;
	if resp_flag[i] in (1, 4, 5, 7, .V) then do;
		if finr_hh_flag[i] ne . then do;
			any_finr_hh[i]=(finr_hh_flag[i]=1); end;
		tot_earned_income[i]		=resp_earned_income[i];
		tot_unearn_income_w_ssi[i]	=resp_unearn_income_1[i]+resp_unearn_income_2[i] +resp_unearn_income_3[i]+resp_unearn_income_4[i]+resp_unearn_income_5[i];
		tot_unearn_income_x_ssi[i]	=resp_unearn_income_1[i]+resp_unearn_income_2a[i]+resp_unearn_income_3[i]+resp_unearn_income_4[i]+resp_unearn_income_5[i];
		ssi_income[i]       		=resp_unearn_income_2[i]-resp_unearn_income_2a[i]; /* this is SSI income -- good to crosstab with Medicaid receipt */
		ssi_check[i]				=resp_unearn_income_2b[i];
		income_fixed_w_ssi[i]     	=resp_unearn_income_1[i]+resp_unearn_income_2[i] +resp_unearn_income_3[i]+resp_unearn_income_5[i];
		income_fixed_x_ssi[i]     	=resp_unearn_income_1[i]+resp_unearn_income_2a[i]+resp_unearn_income_3[i]+resp_unearn_income_5[i];
	end;
	if spou_flag[i] in (1, 4, 5, 7, .V) then do;
		tot_earned_income[i]		=tot_earned_income[i]+spou_earned_income[i];
		tot_unearn_income_w_ssi[i]	=tot_unearn_income_w_ssi[i]+spou_unearn_income_1[i]+spou_unearn_income_2[i] +spou_unearn_income_3[i]+spou_unearn_income_4[i]+spou_unearn_income_5[i];
		tot_unearn_income_x_ssi[i]	=tot_unearn_income_x_ssi[i]+spou_unearn_income_1[i]+spou_unearn_income_2a[i]+spou_unearn_income_3[i]+spou_unearn_income_4[i]+spou_unearn_income_5[i];
		ssi_income[i] 				=ssi_income[i]+spou_unearn_income_2[i]-spou_unearn_income_2a[i]; /* this is SSI income -- good to crosstab with Medicaid receipt */
		ssi_check[i]				=ssi_check[i]+spou_unearn_income_2b[i];
		income_fixed_w_ssi[i]		=income_fixed_w_ssi[i]+spou_unearn_income_1[i]+spou_unearn_income_2[i] +spou_unearn_income_3[i]+spou_unearn_income_5[i];
		income_fixed_x_ssi[i]		=income_fixed_x_ssi[i]+spou_unearn_income_1[i]+spou_unearn_income_2a[i]+spou_unearn_income_3[i]+spou_unearn_income_5[i];
	end;
	* Finalize total earned income (move self-employment income into earned income);
		tot_earned_income[i]=tot_earned_income[i]+hh_selfemploy_income[i];
	* Finalize total unearned income (move self-employment income out of unearned income);
		tot_unearn_income_w_ssi[i]=tot_unearn_income_w_ssi[i]+hh_oth_income[i]+(hh_cap_income[i]-hh_selfemploy_income[i]);
		tot_unearn_income_x_ssi[i]=tot_unearn_income_x_ssi[i]+hh_oth_income[i]+(hh_cap_income[i]-hh_selfemploy_income[i]);
	* Finalize total (earned & unearned) income;
		tot_income_w_ssi[i]=tot_earned_income[i]+tot_unearn_income_w_ssi[i];
		tot_income_x_ssi[i]=tot_earned_income[i]+tot_unearn_income_x_ssi[i];
	* Compute the fraction of income that is from fixed sources (Pensions, annuities, SS retirement, SSDI, SSI, and Veterans benefits);
		frac_income_fixed_w_ssi[i]=income_fixed_w_ssi[i]/tot_income_w_ssi[i];
		frac_income_fixed_x_ssi[i]=income_fixed_x_ssi[i]/tot_income_x_ssi[i];
	* Create an indicator that someone was primarily on a fixed income (80% or more of income comes from fixed sources);
		fixed_ind_w_ssi[i]=(tot_income_w_ssi[i]=0 or frac_income_fixed_w_ssi[i]>=0.8);
		fixed_ind_x_ssi[i]=(tot_income_x_ssi[i]=0 or frac_income_fixed_x_ssi[i]>=0.8);
	* Finalize total HRS income (for reconciling against HRS totals);
		tot_hrs_income[i]=tot_earned_income[i]+tot_unearn_income_x_ssi[i]+ssi_income[i]+(resp_unearn_income_6[i]-resp_unearn_income_5[i]); /* last part adds back in other govt transfers net of VA benefits (VA benefits were part of unearned income) */
	end;
	inc_diff_w9 =H9ITOT -tot_hrs_inc_w9;
	inc_diff_w10=H10ITOT-tot_hrs_inc_w10;
	inc_diff_w11=H11ITOT-tot_hrs_inc_w11;
	inc_diff_w12=H12ITOT-tot_hrs_inc_w12;
	inc_diff_w13=H13ITOT-tot_hrs_inc_w13;
run;

	
	* Look at respondent-level distribution of total income variables by wave;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check total income measures w9'; class inw9; var H9ITOT tot_inc_w_ssi_w9 tot_inc_x_ssi_w9 tot_earned_inc_w9 tot_unearned_inc_w_ssi_w9 tot_unearned_inc_x_ssi_w9; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check total income measures w10'; class inw10; var H10ITOT tot_inc_w_ssi_w10 tot_inc_x_ssi_w10 tot_earned_inc_w10 tot_unearned_inc_w_ssi_w10 tot_unearned_inc_x_ssi_w10; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check total income measures w11'; class inw11; var H11ITOT tot_inc_w_ssi_w11 tot_inc_x_ssi_w11 tot_earned_inc_w11 tot_unearned_inc_w_ssi_w11 tot_unearned_inc_x_ssi_w11; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check total income measures w12'; class inw12; var H12ITOT tot_inc_w_ssi_w12 tot_inc_x_ssi_w12 tot_earned_inc_w12 tot_unearned_inc_w_ssi_w12 tot_unearned_inc_x_ssi_w12; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check total income measures w13'; class inw13; var H13ITOT tot_inc_w_ssi_w13 tot_inc_x_ssi_w13 tot_earned_inc_w13 tot_unearned_inc_w_ssi_w13 tot_unearned_inc_x_ssi_w13; run;
	
	* HRS income reconciliation check;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check total income variable w9'; class inw9; var H9ITOT tot_hrs_inc_w9 inc_diff_w9; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check total income variable w10'; class inw10; var H10ITOT tot_hrs_inc_w10 inc_diff_w10; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check total income variable w11'; class inw11; var H11ITOT tot_hrs_inc_w11 inc_diff_w11; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check total income variable w12'; class inw12; var H12ITOT tot_hrs_inc_w12 inc_diff_w12; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check total income variable w13'; class inw13; var H13ITOT tot_hrs_inc_w13 inc_diff_w13; run;

	* Checking total income;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check total income variable w9'; class inw9; var hh_selfemploy_inc_w9 tot_inc_w_ssi_w9; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check total income variable w10'; class inw10; var hh_selfemploy_inc_w10 tot_inc_w_ssi_w10; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check total income variable w11'; class inw11; var hh_selfemploy_inc_w11 tot_inc_w_ssi_w11; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check total income variable w12'; class inw12; var hh_selfemploy_inc_w12 tot_inc_w_ssi_w12; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check total income variable w13'; class inw13; var hh_selfemploy_inc_w13 tot_inc_w_ssi_w13; run;

	* Checking fixed income indicators;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check fixed income indicators w9'; class inw9; var frac_inc_fixed_w_ssi_w9 fixed_income_ind_w_ssi_w9; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check fixed income indicators w10'; class inw10; var frac_inc_fixed_w_ssi_w10 fixed_income_ind_w_ssi_w10; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check fixed income indicators w11'; class inw11; var frac_inc_fixed_w_ssi_w11 fixed_income_ind_w_ssi_w11; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check fixed income indicators w12'; class inw12; var frac_inc_fixed_w_ssi_w12 fixed_income_ind_w_ssi_w12; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check fixed income indicators w13'; class inw13; var frac_inc_fixed_w_ssi_w13 fixed_income_ind_w_ssi_w13; run;

	* Checking survey-reported SSI receipt and SSI income;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check SSI vars w9'; class inw9; var ssi_w9 ssi_check_w9; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check SSI vars w10'; class inw10; var ssi_w10 ssi_check_w10; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check SSI vars w11'; class inw11; var ssi_w11 ssi_check_w11; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check SSI vars w12'; class inw12; var ssi_w12 ssi_check_w12; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check SSI vars w13'; class inw13; var ssi_w13 ssi_check_w13; run;

	* Checking survey-reported SSDI receipt and SSDI income;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check SSDI vars w9'; class inw9 svy_ssdi_w9; var R9ISDI; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check SSDI vars w10'; class inw10 svy_ssdi_w10; var R10ISDI; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check SSDI vars w11'; class inw11 svy_ssdi_w11; var R11ISDI; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check SSDI vars w12'; class inw12 svy_ssdi_w12; var R12ISDI; run;
	proc means data=d.randhrs_merge_4 N NMISS MIN MEAN P10 P25 P50 P75 P90 P95 P99 MAX; title 'check SSDI vars w13'; class inw13 svy_ssdi_w13; var R13ISDI; run;


*************************************************************************************************************************;
* (5) Calculate family size and FPL% using annual ASPE Federal Poverty Guidelines;
*************************************************************************************************************************;
data d.randhrs_merge_5;
merge d.randhrs_merge_4 (in=in1) f.fam_size (in=in2);
by HHID PN;
if in1; run;

data d.randhrs_merge_5;
set d.randhrs_merge_5;

* When couple = 1, single household. When couple = 2, couple household;
couple_w9=.;
couple_w10=.;
couple_w11=.;
couple_w12=.;
couple_w13=.;

* Number of household dependents (calc'd per RAND LIS report);
hh_dep_w9=.;
hh_dep_w10=.;
hh_dep_w11=.;
hh_dep_w12=.;
hh_dep_w13=.;

* Any household dependents (calc'd per RAND LIS report);
any_hh_dep_w9=.;
any_hh_dep_w10=.;
any_hh_dep_w11=.;
any_hh_dep_w12=.;
any_hh_dep_w13=.;

* Household size: # dependents + (1 (single hh) or 2 (couple hh));
hh_size_w9=.;
hh_size_w10=.;
hh_size_w11=.;
hh_size_w12=.;
hh_size_w13=.;

array hhres  {5} H9HHRES H10HHRES H11HHRES H12HHRES H13HHRES;
array couple {5} H9CPL H10CPL H11CPL H12CPL H13CPL;
array c {5} couple_w9 couple_w10 couple_w11 couple_w12 couple_w13; /* household size based on whether one is in a couple vs. a single household -- relevant for Medicaid guidelines */
array dependents {5} LE119 ME119 NE119 OE119 PE119;
array d {5} hh_dep_w9 hh_dep_w10 hh_dep_w11 hh_dep_w12 hh_dep_w13;
array any_d {5} any_hh_dep_w9 any_hh_dep_w10 any_hh_dep_w11 any_hh_dep_w12 any_hh_dep_w13;
array hhsize {5} hh_size_w9 hh_size_w10 hh_size_w11 hh_size_w12 hh_size_w13; /* total household size including dependents -- relevant for LIS guidelines */

do i=1 to 5;
	if couple[i] ne . then do; if couple[i]=1 then c[i]=2; if couple[i]=0 then c[i]=1; end;
	d[i]=min(max(0,hhres[i]-c[i]),dependents[i]); /* min(max(0,hhres[i]-c[i]),dependents[i]) edit on 3-22-2019: changed from min((hhres[i]-c[i]),dependents[i]) */
	any_d[i]=(min(max(0,hhres[i]-c[i]),dependents[i])>=1);
	hhsize[i]=c[i]+d[i];
end; run;

proc freq data=d.randhrs_merge_5;
tables H9CPL H10CPL H11CPL H12CPL H13CPL / missing; run;

proc freq data=d.randhrs_merge_5;
tables inw9  * H9CPL * couple_w9 / missing;
tables inw12 * H12CPL * couple_w12 / missing;
tables inw13 * H13CPL * couple_w13 / missing;
tables inw9  * hh_dep_w9 * any_hh_dep_w9 / missing; 
tables inw12 * hh_dep_w12 * any_hh_dep_w12 / missing; 
tables inw13 * hh_dep_w13 * any_hh_dep_w13 / missing; run;

* Calculate poverty thresholds based on state and household size (household dependents count towards size in LIS calculation but not in the SSI/Medicaid calculation);
data d.randpov;
merge 	d.randhrs_merge_5 (in=in1 keep=HHID PN inw9 inw10 inw11 inw12 inw13 couple_w9 couple_w10 couple_w11 couple_w12 couple_w13 hh_dep_w9 hh_dep_w10 hh_dep_w11 hh_dep_w12 hh_dep_w13 hh_size_w9 hh_size_w10 hh_size_w11 hh_size_w12 hh_size_w13 LIWYEAR MIWYEAR NIWYEAR OIWYEAR PIWYEAR)
		stgeo.Hrsxstate14 (in=in2 keep=HHID PN STFIPS08 STFIPS10 STFIPS12 STFIPS14 STATEUSPS08 STATEUSPS10 STATEUSPS12 STATEUSPS14);
by HHID PN;
if in1; run;

data d.randpov;
set d.randpov;

/* ASPE Poverty guideline applicable to Medicaid and MSPs (does not include dependents) */
pov_guideline_mcd_w9=.;
pov_guideline_mcd_w10=.;
pov_guideline_mcd_w11=.;
pov_guideline_mcd_w12=.;
pov_guideline_mcd_w13=.;

/* ASPE Poverty guideline applicable to the Low-Income Subsidy (includes dependents) */
pov_guideline_lis_w9=.;
pov_guideline_lis_w10=.;
pov_guideline_lis_w11=.;
pov_guideline_lis_w12=.;
pov_guideline_lis_w13=.;

array year {5} LIWYEAR MIWYEAR NIWYEAR OIWYEAR PIWYEAR; /* REVISIT WHETHER INCOME IS ASSESSED IN YEAR PRIOR TO INTERVIEW YEAR */
array state {5} STFIPS08 STFIPS10 STFIPS12 STFIPS14 /*need to replace with STFIPS16 when available*/ STFIPS14;
array hh_size_lis {5} hh_size_w9 hh_size_w10 hh_size_w11 hh_size_w12 hh_size_w13; /* LIS counts couples and their dependents when determining income relative to poverty guidelines, although LIS asset tests are based only on householder and spouse */
array hh_size_mcd {5} couple_w9 couple_w10 couple_w11 couple_w12 couple_w13; /* Medicaid and MSPs follow the SSI counting methodology, which counts only the householder and spouse */
array pov_guideline_lis {5} pov_guideline_lis_w9 pov_guideline_lis_w10 pov_guideline_lis_w11 pov_guideline_lis_w12 pov_guideline_lis_w13;
array pov_guideline_mcd {5} pov_guideline_mcd_w9 pov_guideline_mcd_w10 pov_guideline_mcd_w11 pov_guideline_mcd_w12 pov_guideline_mcd_w13;

do i=1 to 5;
	/*interview year yyyy asks about yyyy-1 income.  For example, interview year 2008 asks about 2007 income*/
	** Populate 2007 FPL guidelines for 2007 income reported in the 2008 survey year (wave 9) **;
	if year[i]-1=2007 then do;
		* States other than AK and HI;
		if state[i] not in (02, 15, 66, 72) then do;
			pov_guideline_lis[i]=10210+3480*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=10210+3480*(hh_size_mcd[i]-1); end;
		* AK;
		if (state[i] in (02) and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=12770+4350*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=12770+4350*(hh_size_mcd[i]-1);	end;
		* HI ;
		if (state[i] in (15) and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=11750+4000*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=11750+4000*(hh_size_mcd[i]-1);	end;
	end;

	** Populate 2008 FPL guidelines for 2008 income reported in the 2009 survey year (wave 9) **;
	if year[i]-1=2008 then do;
		* States other than AK and HI;
		if state[i] not in (02, 15, 66, 72) then do;
			pov_guideline_lis[i]=10400+3600*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=10400+3600*(hh_size_mcd[i]-1);	end;
		* AK;
		if (state[i] in (02) and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=13000+4500*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=13000+4500*(hh_size_mcd[i]-1);	end;
		* HI ;
		if (state[i] in (15) and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=11960+4140*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=11960+4140*(hh_size_mcd[i]-1);	end;
	end;

	** Populate 2009/2010 FPL guidelines for 2009/10 income reported in the 2010/11 survey year (wave 10) **;
	if (year[i]-1) in (2009, 2010) then do;
		* States other than AK and HI;
		if state[i] not in (02, 15, 66, 72) then do;
			pov_guideline_lis[i]=10830+3740*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=10830+3740*(hh_size_mcd[i]-1);	end;
		* AK;
		if (state[i] in (02) and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=13530+4680*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=13530+4680*(hh_size_mcd[i]-1);	end;
		* HI ;
		if (state[i] in (15) and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=12460+4300*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=12460+4300*(hh_size_mcd[i]-1);	end;
	end;

	** Populate 2011 FPL guidelines for 2011 income reported in the 2012 survey year (wave 11) **;
	if year[i]-1=2011 then do;
		* States other than AK and HI;
		if state[i] not in (02, 15, 66, 72) then do;
			pov_guideline_lis[i]=10890+3820*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=10890+3820*(hh_size_mcd[i]-1);	end;
		* AK;
		if (state[i] in (02) and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=13600+4780*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=13600+4780*(hh_size_mcd[i]-1);	end;
		* HI ;
		if (state[i] in (15) and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=12540+4390*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=12540+4390*(hh_size_mcd[i]-1);	end;
	end;

	** Populate 2012 FPL guidelines for 2012 income reported in the 2013 survey year (wave 11) **;
	if year[i]-1=2012 then do;
		* States other than AK and HI;
		if state[i] not in (02, 15, 66, 72) then do;
			pov_guideline_lis[i]=11170+3960*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=11170+3960*(hh_size_mcd[i]-1);	end;
		* AK;
		if (state[i] in ('02') and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=13970+4950*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=13970+4950*(hh_size_mcd[i]-1);	end;
		* HI;
		if (state[i] in ('15') and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=12860+4550*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=12860+4550*(hh_size_mcd[i]-1);	end;
	end;

	** Populate 2013 FPL guidelines for 2013 income reported in the 2014 survey year (wave 12) **;
	if year[i]-1=2013 then do;
		* States other than AK and HI;
		if state[i] not in (02, 15, 66, 72) then do;
			pov_guideline_lis[i]=11490+4020*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=11490+4020*(hh_size_mcd[i]-1);	end;
		* AK;
		if (state[i] in (02) and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=14350+5030*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=14350+5030*(hh_size_mcd[i]-1);	end;
		* HI ;
		if (state[i] in (15) and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=13230+4620*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=13230+4620*(hh_size_mcd[i]-1);	end;
	end;

	** Populate 2014 FPL guidelines for 2014 income reported in the 2015 survey year (wave 12) **;
	if year[i]-1=2014 then do;
		* States other than AK and HI;
		if state[i] not in (02, 15, 66, 72) then do;
			pov_guideline_lis[i]=11670+4060*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=11670+4060*(hh_size_mcd[i]-1);	end;
		* AK;
		if (state[i] in (02) and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=14580+5080*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=14580+5080*(hh_size_mcd[i]-1);	end;
		* HI ;
		if (state[i] in (15) and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=13420+4670*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=13420+4670*(hh_size_mcd[i]-1);	end;
	end;

	** Populate 2015 FPL guidelines for 2015 income reported in the 2016 survey year (forthcoming HRS wave) **;
	if year[i]-1=2015 then do;
		* States other than AK and HI;
		if state[i] not in (02, 15, 66, 72) then do;
			pov_guideline_lis[i]=11770+4160*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=11770+4160*(hh_size_mcd[i]-1);	end;
		* AK;
		if (state[i] in (02) and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=14720+5200*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=14720+5200*(hh_size_mcd[i]-1);	end;
		* HI ;
		if (state[i] in (15) and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=13550+4780*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=13550+4780*(hh_size_mcd[i]-1);	end;
	end;

	** Populate 2016 FPL guidelines for 2016 income reported in the 2017 survey year (forthcoming HRS wave) **;
	if year[i]-1=2016 then do;
		* States other than AK and HI;
		if state[i] not in (02, 15, 66, 72) then do;
			* Variable thresholds, HH size including dependents (applies to LIS);
				if hh_size_lis[i]=1 then pov_guideline_lis[i]=11880;
				if hh_size_lis[i]=2 then pov_guideline_lis[i]=16020;
				if hh_size_lis[i]=3 then pov_guideline_lis[i]=20160;
				if hh_size_lis[i]=4 then pov_guideline_lis[i]=24300;
				if hh_size_lis[i]=5 then pov_guideline_lis[i]=28440;
				if hh_size_lis[i]=6 then pov_guideline_lis[i]=32580;
				if hh_size_lis[i]=7 then pov_guideline_lis[i]=36730;
				if hh_size_lis[i]=8 then pov_guideline_lis[i]=40890;
				if hh_size_lis[i]>=9 then pov_guideline_lis[i]=11880+4160*(hh_size_lis[i]-1);
			* Variable thresholds, HH size based only on single or couple households (applies to Medicaid);
				if hh_size_mcd[i]=1 then pov_guideline_mcd[i]=11880;
				if hh_size_mcd[i]=2 then pov_guideline_mcd[i]=16020;
		end;
		* AK;
		if (state[i] in (02) and state[i] not in (66, 72)) then do;
			* Variable thresholds, HH size including dependents (applies to LIS);
				if hh_size_lis[i]=1 then pov_guideline_lis[i]=14850;
				if hh_size_lis[i]=2 then pov_guideline_lis[i]=20030;
				if hh_size_lis[i]=3 then pov_guideline_lis[i]=25200;
				if hh_size_lis[i]=4 then pov_guideline_lis[i]=30380;
				if hh_size_lis[i]=5 then pov_guideline_lis[i]=35550;
				if hh_size_lis[i]=6 then pov_guideline_lis[i]=40730;
				if hh_size_lis[i]=7 then pov_guideline_lis[i]=45910;
				if hh_size_lis[i]=8 then pov_guideline_lis[i]=51110;
				if hh_size_lis[i]>=9 then pov_guideline_lis[i]=14850+5200*(hh_size_lis[i]-1);
			* Variable thresholds, HH size based only on single or couple households (applies to Medicaid);
				if hh_size_mcd[i]=1 then pov_guideline_mcd[i]=14850;
				if hh_size_mcd[i]=2 then pov_guideline_mcd[i]=20030;
		end;
		* HI ;
		if (state[i] in (15) and state[i] not in (66, 72)) then do;
			* Variable thresholds, HH size including dependents (applies to LIS);
				if hh_size_lis[i]=1 then pov_guideline_lis[i]=13660;
				if hh_size_lis[i]=2 then pov_guideline_lis[i]=18420;
				if hh_size_lis[i]=3 then pov_guideline_lis[i]=23180;
				if hh_size_lis[i]=4 then pov_guideline_lis[i]=27950;
				if hh_size_lis[i]=5 then pov_guideline_lis[i]=32710;
				if hh_size_lis[i]=6 then pov_guideline_lis[i]=37470;
				if hh_size_lis[i]=7 then pov_guideline_lis[i]=42240;
				if hh_size_lis[i]=8 then pov_guideline_lis[i]=47020;
				if hh_size_lis[i]>=9 then pov_guideline_lis[i]=13660+4780*(hh_size_lis[i]-1);
			* Variable thresholds, HH size based only on single or couple households (applies to Medicaid);
				if hh_size_mcd[i]=1 then pov_guideline_mcd[i]=13660;
				if hh_size_mcd[i]=2 then pov_guideline_mcd[i]=18420;
		end;
	end;

	** Populate 2017 FPL guidelines for 2017 income reported in the 2018 survey year (forthcoming HRS wave) **;
	if year[i]-1=2017 then do;
		* States other than AK and HI;
		if state[i] not in (02, 15, 66, 72) then do;
			pov_guideline_lis[i]=12060+4180*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=12060+4180*(hh_size_mcd[i]-1);	end;
		* AK;
		if (state[i] in (02) and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=15060+5230*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=15060+5230*(hh_size_mcd[i]-1);	end;
		* HI ;
		if (state[i] in (15) and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=13860+4810*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=13860+4810*(hh_size_mcd[i]-1);	end;
	end;

	** Populate 2018 FPL guidelines for 2018 income reported in the 2019 survey year (forthcoming HRS wave) **;
	if year[i]-1=2018 then do;
		* States other than AK and HI;
		if state[i] not in (02, 15, 66, 72) then do;
			pov_guideline_lis[i]=12140+4320*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=12140+4320*(hh_size_mcd[i]-1);	end;
		* AK;
		if (state[i] in (02) and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=15180+5400*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=15180+5400*(hh_size_mcd[i]-1);	end;
		* HI ;
		if (state[i] in (15) and state[i] not in (66, 72)) then do;
			pov_guideline_lis[i]=13960+4970*(hh_size_lis[i]-1);
			pov_guideline_mcd[i]=13960+4970*(hh_size_mcd[i]-1);	end;
	end;
end; run;

* Checking poverty guidelines;
proc means data=d.randpov N NMISS MEAN STD;
title 'Logic checking of poverty guidelines by survey year (wave 9)';
where STFIPS08 not in ('02', '15', '66', '72');
class LIWYEAR hh_size_w9;
var pov_guideline_lis_w9; run;
proc means data=d.randpov N NMISS MEAN STD;
title 'Logic checking of poverty guidelines by survey year (wave 10)';
where STFIPS10 not in ('02', '15', '66', '72');
class MIWYEAR hh_size_w10;
var pov_guideline_lis_w10; run;
proc means data=d.randpov N NMISS MEAN STD;
title 'Logic checking of poverty thresholds by survey year (wave 11)';
where STFIPS12 not in ('02', '15', '66', '72');
class NIWYEAR hh_size_w11;
var pov_guideline_lis_w11; run;
proc means data=d.randpov N NMISS MEAN STD;
title 'Logic checking of poverty thresholds by survey year (wave 12)';
where STFIPS14 not in ('02', '15', '66', '72');
class OIWYEAR hh_size_w12;
var pov_guideline_lis_w12; run;
proc means data=d.randpov N NMISS MEAN STD;
title 'Logic checking of poverty thresholds by survey year (wave 13)';
where STFIPS14 not in ('02', '15', '66', '72'); /*need to replace with STFIPS16 when available*/
class PIWYEAR hh_size_w13;
var pov_guideline_lis_w13; run;
proc means data=d.randpov;
title 'Logic checking of poverty thresholds - Medicaid/MSP & LIS thresholds should be same in 1-2 person hholds with no dependents';
where (couple_w9=1 & hh_size_w9=1) or (couple_w9=2 & hh_size_w9=2);
var pov_guideline_lis_w9 pov_guideline_mcd_w9; run;
proc means data=d.randpov;
title 'Logic checking of poverty thresholds - Medicaid/MSP & LIS thresholds should be same in 1-2 person hholds with no dependents';
where (couple_w12=1 & hh_size_w12=1) or (couple_w12=2 & hh_size_w12=2);
var pov_guideline_lis_w12 pov_guideline_mcd_w12; run;
proc means data=d.randpov;
title 'Logic checking of poverty thresholds - Medicaid/MSP & LIS thresholds should be same in 1-2 person hholds with no dependents';
where (couple_w13=1 & hh_size_w13=1) or (couple_w13=2 & hh_size_w13=2);
var pov_guideline_lis_w13 pov_guideline_mcd_w13; run;

* Finalize dataset for merging;
data d.randhrs_merge_5;
merge d.randhrs_merge_5 (in=in1) d.randpov (in=in2 keep=HHID PN pov_guideline_lis_w9 pov_guideline_lis_w10 pov_guideline_lis_w11 pov_guideline_lis_w12 pov_guideline_lis_w13 pov_guideline_mcd_w9 pov_guideline_mcd_w10 pov_guideline_mcd_w11 pov_guideline_mcd_w12 pov_guideline_mcd_w13);
by HHID PN;
if in1; run;

* Checking calculated poverty guidelines;
proc means data=d.randhrs_merge_5 N NMISS MEAN MIN MAX;
title 'Checking household size and applicable poverty thresholds for LIS and Medicaid (wave 9)';
class inw9;
var hh_size_w9 pov_guideline_lis_w9 couple_w9 pov_guideline_mcd_w9; run;
proc means data=d.randhrs_merge_5 N NMISS MEAN MIN MAX;
title 'Checking household size and applicable poverty thresholds for LIS and Medicaid (wave 10)';
class inw10;
var hh_size_w10 pov_guideline_lis_w10 couple_w10 pov_guideline_mcd_w10; run;
proc means data=d.randhrs_merge_5 N NMISS MEAN MIN MAX;
title 'Checking household size and applicable poverty thresholds for LIS and Medicaid (wave 11)';
class inw11;
var hh_size_w11 pov_guideline_lis_w11 couple_w11 pov_guideline_mcd_w11; run;
proc means data=d.randhrs_merge_5 N NMISS MEAN MIN MAX;
title 'Checking household size and applicable poverty thresholds for LIS and Medicaid (wave 12)';
class inw12;
var hh_size_w12 pov_guideline_lis_w12 couple_w12 pov_guideline_mcd_w12; run;
proc means data=d.randhrs_merge_5 N NMISS MEAN MIN MAX;
title 'Checking household size and applicable poverty thresholds for LIS and Medicaid (wave 13)';
class inw13;
var hh_size_w13 pov_guideline_lis_w13 couple_w13 pov_guideline_mcd_w13; run;


*************************************************************************************************************************;
* (6) Calculate assets (includes burial allowances for single and couple households, but life insurancep policies not yet modeled);
*************************************************************************************************************************;
data d.randhrs_merge_6;
set d.randhrs_merge_5;

countable_asset_w9=.;
countable_asset_w10=.;
countable_asset_w11=.;
countable_asset_w12=.;
countable_asset_w13=.;

noncountable_asset_w9=.;
noncountable_asset_w10=.;
noncountable_asset_w11=.;
noncountable_asset_w12=.;
noncountable_asset_w13=.;

burial_allowance_w9=.;
burial_allowance_w10=.;
burial_allowance_w11=.;
burial_allowance_w12=.;
burial_allowance_w13=.;

	* Assets counted towards resource limit;
	array asset_property_nonresid {5}  H9ARLES H10ARLES H11ARLES H12ARLES H13ARLES; /* xx Net value of real estate (not primary residence) */
	array asset_2ndresid_net {5}  H9ANETHB H10ANETHB H11ANETHB H12ANETHB H13ANETHB; /* xx Net value of second home (residence)*/
	array asset_business {5}  H9ABSNS H10ABSNS H11ABSNS H12ABSNS H13ABSNS; /*NOT COUNTED TOWARDS ASSETS (AND PROBABLY NEGLIGIBLE FOR LOW-INCOME MEDICARE BENES) Net value of businesses */
	array asset_retirement {5}  H9AIRA H10AIRA H11AIRA H12AIRA H13AIRA; /* xx Net value of IRA and Keogh accounts */
	array asset_stock {5}  H9ASTCK H10ASTCK H11ASTCK H12ASTCK H13ASTCK; /* xx Net value of stocks, mutual funds, and investment trusts*/
	array asset_check {5}  H9ACHCK H10ACHCK H11ACHCK H12ACHCK H13ACHCK; /* Net value of checking and liquid demand deposit accounts*/
	array asset_cd {5}  H9ACD H10ACD H11ACD H12ACD H13ACD; /* xx Net value of CD, savings bonds, and T-bills*/
	array asset_bond {5}  H9ABOND H10ABOND H11ABOND H12ABOND H13ABOND; /* xx Net value of bonds, bond funds*/
	array asset_oth_savings {5}  H9AOTHR H10AOTHR H11AOTHR H12AOTHR H13AOTHR; /* xx Net value of other savings*/
	array debt {5} H9ADEBT H10ADEBT H11ADEBT H12ADEBT H13ADEBT; /* Debts not yet asked, which count against assets for determining program eligibility */
	array hh_size_mcd {5} couple_w9 couple_w10 couple_w11 couple_w12 couple_w13; /* Medicaid and MSPs follow the SSI counting methodology, which counts only the householder and spouse */
	array countable_asset_fin {5} countable_asset_w9 countable_asset_w10 countable_asset_w11 countable_asset_w12 countable_asset_w13;
	array noncountable_asset {5} noncountable_asset_w9 noncountable_asset_w10 noncountable_asset_w11 noncountable_asset_w12 noncountable_asset_w13;

	* Burial allowance;
	array burial {5} burial_allowance_w9 burial_allowance_w10 burial_allowance_w11 burial_allowance_w12 burial_allowance_w13;
	* Assets not counted towards resource limit;
	* The net value of housing is calculated as the value of the primary residence less mortgages and home loans: HwAHOUS - HwAMORT - HwAHMLN;
	array asset_1stresid_net {5} H9ATOTH H10ATOTH H11ATOTH H12ATOTH H13ATOTH; /*Net value of primary residence*/
	array asset_vehicles {5} H9ATRAN H10ATRAN H11ATRAN H12ATRAN H13ATRAN; /*Net value of vehicles*/

do i=1 to 5;
	noncountable_asset[i]=asset_1stresid_net[i]+asset_vehicles[i];
	if hh_size_mcd[i] in (1, 2) then do; if hh_size_mcd[i]=1 then burial[i]=1500; if hh_size_mcd[i]=2 then burial[i]=3000; end;
	* Countable assets are non-home, non-vehicle assets, less debts, burial allowances, [and face value of life insurance if possible to impute];
	* Did not count business assets as they likely don't meet the definition of liquid assets for LIS and they are probably negligible for low-income Medicare benes;
	countable_asset_fin[i]=asset_property_nonresid[i]+asset_2ndresid_net[i]+asset_retirement[i]+asset_stock[i]+asset_check[i]+asset_cd[i]+asset_bond[i]+asset_oth_savings[i]-debt[i]-burial[i];
end;
run;

proc means data=d.randhrs_merge_6 N NMISS MIN P5 P10 P25 P50 P75 P90 P95 MEAN MAX;
title 'Check assets w9';
class inw9;
var countable_asset_w9 burial_allowance_w9 noncountable_asset_w9; run;
proc means data=d.randhrs_merge_6 N NMISS MIN P5 P10 P25 P50 P75 P90 P95 MEAN MAX;
title 'Check assets w12';
class inw12;
var countable_asset_w12 burial_allowance_w12 noncountable_asset_w12; run;
proc means data=d.randhrs_merge_6 N NMISS MIN P5 P10 P25 P50 P75 P90 P95 MEAN MAX;
title 'Check assets w13';
class inw13;
var countable_asset_w13 burial_allowance_w13 noncountable_asset_w13; run;


*************************************************************************************************************************;
* (7) Link state-year-family size eligibility thresholds for Medicaid, MSP, and the LIS to the dataset, 
      and assess income and assets relative to these thresholds;
*************************************************************************************************************************;
* Merge wave-specific datasets of eligibility rules by wave-specific state identifier;
data d.elig_thresholds;
set d.randhrs_merge_6 (keep=HHID PN inw9 inw10 inw11 inw12 inw13
		LIWYEAR MIWYEAR NIWYEAR OIWYEAR PIWYEAR STFIPS08 STFIPS10 STFIPS12 STFIPS14 STATEUSPS08 STATEUSPS10 STATEUSPS12 STATEUSPS14 
		couple_w9 couple_w10 couple_w11 couple_w12 couple_w13 hh_size_w9 hh_size_w10 hh_size_w11 hh_size_w12 hh_size_w13); run;

proc sort data=d.elig_thresholds; by STFIPS08; run;
data d.elig_thresholds;
merge d.elig_thresholds (in=in1) pove.Consol_elig_rules_w9 (in=in2);
by STFIPS08;
if in1; 
instate_w9=(in1=1 & in2=1); run;
proc sort data=d.elig_thresholds; by STFIPS10;
data d.elig_thresholds;
merge d.elig_thresholds (in=in1) pove.Consol_elig_rules_w10 (in=in2);
by STFIPS10;
if in1;
instate_w10=(in1=1 & in2=1); run;
proc sort data=d.elig_thresholds; by STFIPS12;
data d.elig_thresholds;
merge d.elig_thresholds (in=in1) pove.Consol_elig_rules_w11 (in=in2);
by STFIPS12;
if in1; 
instate_w11=(in1=1 & in2=1); run;
proc sort data=d.elig_thresholds; by STFIPS14;
data d.elig_thresholds;
merge d.elig_thresholds (in=in1) pove.Consol_elig_rules_w12 (in=in2);
by STFIPS14;
if in1; 
instate_w12=(in1=1 & in2=1); run;
proc sort data=d.elig_thresholds; by STFIPS14; /*need to replace with STFIPS16 when available*/
data d.elig_thresholds;
merge d.elig_thresholds (in=in1) pove.Consol_elig_rules_w13 (in=in2 rename=(STFIPS16=STFIPS14) /*need to replace with STFIPS16 when available*/);
by STFIPS14; /*need to replace with STFIPS16 when available*/
if in1; 
instate_w13=(in1=1 & in2=1); run;

proc freq data=d.elig_thresholds;
tables inw9 * instate_w9 / missing;
tables inw10 * instate_w10 / missing;
tables inw11 * instate_w11 / missing;
tables inw12 * instate_w12 / missing;
tables inw13 * instate_w13 / missing; run;

* Assign income and asset eligibility limits based on state, interview year, and family size;
* Note: The HRS interview year asks about income and assets in the prior year, so I am linking on income and asset limits from the prior year;
data d.elig_thresholds;
set d.elig_thresholds;

* Declare income threshold variables -- will populate conditional on state, year, family size criteria;
	* Medicaid;
		mcd_inc_t_w9=.; 			mcd_inc_t_w10=.; 				mcd_inc_t_w11=.; 				mcd_inc_t_w12=.;			mcd_inc_t_w13=.;
	* MSPs;
		qmb_inc_t_w9=.; 			qmb_inc_t_w10=.; 				qmb_inc_t_w11=.; 				qmb_inc_t_w12=.;			qmb_inc_t_w13=.;
		slmb_inc_t_w9=.; 			slmb_inc_t_w10=.; 				slmb_inc_t_w11=.; 				slmb_inc_t_w12=.;			slmb_inc_t_w13=.;
		qi_inc_t_w9=.; 				qi_inc_t_w10=.; 				qi_inc_t_w11=.; 				qi_inc_t_w12=.;				qi_inc_t_w13=.;
	* LIS (relative to FPL thresholds are time invariant (135% FPL for full, 150% FPL for partial) -- will simply hard code below);

* Asset threshold variables;
	* Medicaid;
		mcd_asset_t_w9=.; 			mcd_asset_t_w10=.; 				mcd_asset_t_w11=.; 				mcd_asset_t_w12=.;			mcd_asset_t_w13=.;
	* MSPs;
		msp_asset_t_w9=.; 			msp_asset_t_w10=.; 				msp_asset_t_w11=.; 				msp_asset_t_w12=.;			msp_asset_t_w13=.;
	* LIS;
		lis_full_asset_t_w9=.;		lis_full_asset_t_w10=.;			lis_full_asset_t_w11=.;			lis_full_asset_t_w12=.;		lis_full_asset_t_w13=.;
		lis_part_asset_t_w9=.;		lis_part_asset_t_w10=.;			lis_part_asset_t_w11=.;			lis_part_asset_t_w12=.;		is_part_asset_t_w13=.;

* Income disregard variables (ADDITIONAL disregards on top of standard disregards of $240 general/$780 + 0.5x earned in excess of $780);
		* Note: Assuming these additional disregards apply to general income unless specifically stated;
mcd_gen_disregard_w9=.; 	mcd_gen_disregard_w10=.; 		mcd_gen_disregard_w11=.; 		mcd_gen_disregard_w12=.;			mcd_gen_disregard_w13=.;
mcd_earned_disregard_w9=.; 	mcd_earned_disregard_w10=.; 	mcd_earned_disregard_w11=.; 	mcd_earned_disregard_w12=.;			mcd_earned_disregard_w13=.;
msp_add_inc_disregard_w9=.; msp_add_inc_disregard_w10=.; 	msp_add_inc_disregard_w11=.; 	msp_add_inc_disregard_w12=.;		msp_add_inc_disregard_w13=.;

* Declare variable arrays;
array mcd_inc_threshold {5} mcd_inc_t_w9 mcd_inc_t_w10 mcd_inc_t_w11 mcd_inc_t_w12 mcd_inc_t_w13; /* per Noelle, varies for single vs couple households */
array qmb_inc_threshold {5} qmb_inc_t_w9 qmb_inc_t_w10 qmb_inc_t_w11 qmb_inc_t_w12 qmb_inc_t_w13;
array slmb_inc_threshold {5} slmb_inc_t_w9 slmb_inc_t_w10 slmb_inc_t_w11 slmb_inc_t_w12 slmb_inc_t_w13;
array qi_inc_threshold {5} qi_inc_t_w9 qi_inc_t_w10 qi_inc_t_w11 qi_inc_t_w12 qi_inc_t_w13;

array mcd_asset_threshold {5} mcd_asset_t_w9 mcd_asset_t_w10 mcd_asset_t_w11 mcd_asset_t_w12 mcd_asset_t_w13; /* varies for single vs couple households */
array msp_asset_threshold {5} msp_asset_t_w9 msp_asset_t_w10 msp_asset_t_w11 msp_asset_t_w12 msp_asset_t_w13; /* varies for single vs couple households */
array lis_full_asset_threshold {5} lis_full_asset_t_w9 lis_full_asset_t_w10 lis_full_asset_t_w11 lis_full_asset_t_w12 lis_full_asset_t_w13; /* varies for single vs couple households */
array lis_part_asset_threshold {5} lis_part_asset_t_w9 lis_part_asset_t_w10 lis_part_asset_t_w11 lis_part_asset_t_w12 lis_part_asset_t_w13; /* varies for single vs couple households */

array mcd_gen_disregard {5} mcd_gen_disregard_w9 mcd_gen_disregard_w10 mcd_gen_disregard_w11 mcd_gen_disregard_w12 mcd_gen_disregard_w13;
array mcd_earned_disregard {5} mcd_earned_disregard_w9 mcd_earned_disregard_w10 mcd_earned_disregard_w11 mcd_earned_disregard_w12 mcd_earned_disregard_w13;
array msp_add_inc_disregard {5} msp_add_inc_disregard_w9 msp_add_inc_disregard_w10 msp_add_inc_disregard_w11 msp_add_inc_disregard_w12 msp_add_inc_disregard_w13;

array year {5} LIWYEAR MIWYEAR NIWYEAR OIWYEAR PIWYEAR; /* wIWYEAR is the year in which the interview was conducted */
array hh_size_lis {5} hh_size_w9 hh_size_w10 hh_size_w11 hh_size_w12 hh_size_w13; /* LIS counts couples and their dependents */
array hh_size_mcd {5} couple_w9 couple_w10 couple_w11 couple_w12 couple_w13; /* Medicaid and MSPs follow the SSI counting methodology, which counts only the householder and spouse */

do i=1 to 5;
	/*interview year yyyy asks about yyyy-1 income.  For example, interview year 2008 asks about 2007 income.  Therefore, I'm aligning all income- and asset-based tests to the year prior to the interview*/

	if year[i]-1=2007 then do; /*wave 9*/
		if hh_size_mcd[i] in (1, 2) then do;
			mcd_earned_disregard[i]=edisregard2007_amt;
			qmb_inc_threshold[i]=QMB_INC_2007; slmb_inc_threshold[i]=SLMB_INC_2007; qi_inc_threshold[i]=QI_INC_2007;
			msp_add_inc_disregard[i]=msp_add_annual_disregard_w9; end;
			if hh_size_mcd[i]=1 then do;
				mcd_inc_threshold[i]=medicaid_inc_single_2007;
				mcd_gen_disregard[i]=gdisregard2007_s;
				mcd_asset_threshold[i]=medicaid_asset_single_2007;
				msp_asset_threshold[i]=MSP_Asset1_2007; 
				lis_full_asset_threshold[i]=6120 ; lis_part_asset_threshold[i]=10210; /* LIS asset tests are based only on householder and spouse, so I can nest these inside the logic by Medicaid family size */
			end;
			if hh_size_mcd[i]=2 then do;
				mcd_inc_threshold[i]=medicaid_inc_couple_2007;
				mcd_gen_disregard[i]=gdisregard2007_c;
				mcd_asset_threshold[i]=medicaid_asset_couple_2007;
				msp_asset_threshold[i]=MSP_Asset2_2007;
				lis_full_asset_threshold[i]=9190 ; lis_part_asset_threshold[i]=20410; /* LIS asset tests are based only on householder and spouse */
			end;
	end;

	if year[i]-1=2008 then do; /*wave 9*/
		if hh_size_mcd[i] in (1, 2) then do;
		mcd_earned_disregard[i]=edisregard2008_amt;
		qmb_inc_threshold[i]=QMB_INC_2008; slmb_inc_threshold[i]=SLMB_INC_2008; qi_inc_threshold[i]=QI_INC_2008;
		msp_add_inc_disregard[i]=msp_add_annual_disregard_w9; end;
		if hh_size_mcd[i]=1 then do;
				mcd_inc_threshold[i]=medicaid_inc_single_2008; 
				mcd_gen_disregard[i]=gdisregard2008_s;
				mcd_asset_threshold[i]=medicaid_asset_single_2008;
				msp_asset_threshold[i]=MSP_Asset1_2008;
				lis_full_asset_threshold[i]=6290 ; lis_part_asset_threshold[i]=10490; /* LIS asset tests are based only on householder and spouse */
			end;
			if hh_size_mcd[i]=2 then do;
				mcd_inc_threshold[i]=medicaid_inc_couple_2008;
				mcd_gen_disregard[i]=gdisregard2008_c;
				mcd_asset_threshold[i]=medicaid_asset_couple_2008;
				msp_asset_threshold[i]=MSP_Asset2_2008;
				lis_full_asset_threshold[i]=9440 ; lis_part_asset_threshold[i]=20970; /* LIS asset tests are based only on householder and spouse */
			end;
	end;

	if year[i]-1=2009 then do; /*wave 10*/
		if hh_size_mcd[i] in (1, 2) then do;
		mcd_earned_disregard[i]=edisregard2009_amt;
		qmb_inc_threshold[i]=QMB_INC_2009; slmb_inc_threshold[i]=SLMB_INC_2009; qi_inc_threshold[i]=QI_INC_2009;
		msp_add_inc_disregard[i]=msp_add_annual_disregard_w10; end;
			if hh_size_mcd[i]=1 then do;
				mcd_inc_threshold[i]=medicaid_inc_single_2009;
				mcd_gen_disregard[i]=gdisregard2009_s;
				mcd_asset_threshold[i]=medicaid_asset_single_2009;
				msp_asset_threshold[i]=MSP_Asset1_2009;
				lis_full_asset_threshold[i]=6600 ; lis_part_asset_threshold[i]=11010; /* LIS asset tests are based only on householder and spouse */
			end;
			if hh_size_mcd[i]=2 then do;
				mcd_inc_threshold[i]=medicaid_inc_couple_2009;
				mcd_gen_disregard[i]=gdisregard2009_c;
				mcd_asset_threshold[i]=medicaid_asset_couple_2009;
				msp_asset_threshold[i]=MSP_Asset2_2009;
				lis_full_asset_threshold[i]=9910 ; lis_part_asset_threshold[i]=22010; /* LIS asset tests are based only on householder and spouse */
			end;
	end;

	if year[i]-1=2010 then do; /*wave 10*/
		if hh_size_mcd[i] in (1, 2) then do;
		mcd_earned_disregard[i]=edisregard2010_amt;
		qmb_inc_threshold[i]=QMB_INC_2010; slmb_inc_threshold[i]=SLMB_INC_2010; qi_inc_threshold[i]=QI_INC_2010;
		msp_add_inc_disregard[i]=msp_add_annual_disregard_w10; end;
			if hh_size_mcd[i]=1 then do; 
				mcd_inc_threshold[i]=medicaid_inc_single_2010;
				mcd_gen_disregard[i]=gdisregard2010_s;
				mcd_asset_threshold[i]=medicaid_asset_single_2010; 
				msp_asset_threshold[i]=MSP_Asset1_2010;
				lis_full_asset_threshold[i]=6600 ; lis_part_asset_threshold[i]=11010; /* LIS asset tests are based only on householder and spouse */
			end;
			if hh_size_mcd[i]=2 then do;
				mcd_inc_threshold[i]=medicaid_inc_couple_2010;
				mcd_gen_disregard[i]=gdisregard2010_c;
				mcd_asset_threshold[i]=medicaid_asset_couple_2010; 
				msp_asset_threshold[i]=MSP_Asset2_2010;
				lis_full_asset_threshold[i]=9910 ; lis_part_asset_threshold[i]=22010; /* LIS asset tests are based only on householder and spouse */
			end;
	end;

	if year[i]-1=2011 then do; /*wave 11*/
		if hh_size_mcd[i] in (1, 2) then do;
		mcd_earned_disregard[i]=edisregard2011_amt;
		qmb_inc_threshold[i]=QMB_INC_2011; slmb_inc_threshold[i]=SLMB_INC_2011; qi_inc_threshold[i]=QI_INC_2011;
		msp_add_inc_disregard[i]=msp_add_annual_disregard_w11; end;
			if hh_size_mcd[i]=1 then do; 
				mcd_inc_threshold[i]=medicaid_inc_single_2011;
				mcd_gen_disregard[i]=gdisregard2011_s;
				mcd_asset_threshold[i]=medicaid_asset_single_2011; 
				msp_asset_threshold[i]=MSP_Asset1_2011;
				lis_full_asset_threshold[i]=6680 ; lis_part_asset_threshold[i]=11140; /* LIS asset tests are based only on householder and spouse */
			end;
			if hh_size_mcd[i]=2 then do; 
				mcd_inc_threshold[i]=medicaid_inc_couple_2011;
				mcd_gen_disregard[i]=gdisregard2011_c;
				mcd_asset_threshold[i]=medicaid_asset_couple_2011; 
				msp_asset_threshold[i]=MSP_Asset2_2011;
				lis_full_asset_threshold[i]=10020 ; lis_part_asset_threshold[i]=22260; /* LIS asset tests are based only on householder and spouse */
			end;
	end;

	if year[i]-1=2012 then do; /*wave 11*/
		if hh_size_mcd[i] in (1, 2) then do;
		mcd_earned_disregard[i]=edisregard2012_amt;
		qmb_inc_threshold[i]=QMB_INC_2012; slmb_inc_threshold[i]=SLMB_INC_2012; qi_inc_threshold[i]=QI_INC_2012;
		msp_add_inc_disregard[i]=msp_add_annual_disregard_w11; end;
		if hh_size_mcd[i]=1 then do;
				mcd_inc_threshold[i]=medicaid_inc_single_2012;
				mcd_gen_disregard[i]=gdisregard2012_s;
				mcd_asset_threshold[i]=medicaid_asset_single_2012;
				msp_asset_threshold[i]=MSP_Asset1_2012;
				lis_full_asset_threshold[i]=6940 ; lis_part_asset_threshold[i]=11570; /* LIS asset tests are based only on householder and spouse */
			end;
			if hh_size_mcd[i]=2 then do;
				mcd_inc_threshold[i]=medicaid_inc_couple_2012;
				mcd_gen_disregard[i]=gdisregard2012_c;
				mcd_asset_threshold[i]=medicaid_asset_couple_2012;
				msp_asset_threshold[i]=MSP_Asset2_2012;
				lis_full_asset_threshold[i]=10410 ; lis_part_asset_threshold[i]=23120; /* LIS asset tests are based only on householder and spouse */
			end;
	end;

	if year[i]-1=2013 then do; /*wave 12*/
		if hh_size_mcd[i] in (1, 2) then do;
		mcd_earned_disregard[i]=edisregard2013_amt;
		qmb_inc_threshold[i]=QMB_INC_2013; slmb_inc_threshold[i]=SLMB_INC_2013; qi_inc_threshold[i]=QI_INC_2013;
		msp_add_inc_disregard[i]=msp_add_annual_disregard_w12; end;
		if hh_size_mcd[i]=1 then do; 
				mcd_inc_threshold[i]=medicaid_inc_single_2013;
				mcd_gen_disregard[i]=gdisregard2013_s;
				mcd_asset_threshold[i]=medicaid_asset_single_2013; 
				msp_asset_threshold[i]=MSP_Asset1_2013;
				lis_full_asset_threshold[i]=7080 ; lis_part_asset_threshold[i]=11800; /* LIS asset tests are based only on householder and spouse */
			end;
			if hh_size_mcd[i]=2 then do;
				mcd_inc_threshold[i]=medicaid_inc_couple_2013;
				mcd_gen_disregard[i]=gdisregard2013_c;
				mcd_asset_threshold[i]=medicaid_asset_couple_2013; 
				msp_asset_threshold[i]=MSP_Asset2_2013;
				lis_full_asset_threshold[i]=10620 ; lis_part_asset_threshold[i]=23580; /* LIS asset tests are based only on householder and spouse */
			end;
	end;

	if year[i]-1=2014 then do; /*wave 12*/
		if hh_size_mcd[i] in (1, 2) then do;
		mcd_earned_disregard[i]=edisregard2014_amt;
		qmb_inc_threshold[i]=QMB_INC_2014; slmb_inc_threshold[i]=SLMB_INC_2014; qi_inc_threshold[i]=QI_INC_2014;
		msp_add_inc_disregard[i]=msp_add_annual_disregard_w12; end;
			if hh_size_mcd[i]=1 then do;
				mcd_inc_threshold[i]=medicaid_inc_single_2014;
				mcd_gen_disregard[i]=gdisregard2014_s;
				mcd_asset_threshold[i]=medicaid_asset_single_2014; 
				msp_asset_threshold[i]=MSP_Asset1_2014;
				lis_full_asset_threshold[i]=7160 ; lis_part_asset_threshold[i]=11940; /* LIS asset tests are based only on householder and spouse */
			end;
			if hh_size_mcd[i]=2 then do; 
				mcd_inc_threshold[i]=medicaid_inc_couple_2014;
				mcd_gen_disregard[i]=gdisregard2014_c;
				mcd_asset_threshold[i]=medicaid_asset_couple_2014; 
				msp_asset_threshold[i]=MSP_Asset2_2014;
				lis_full_asset_threshold[i]=10750 ; lis_part_asset_threshold[i]=23860; /* LIS asset tests are based only on householder and spouse */
			end;
	end;

	if year[i]-1=2015 then do; /*wave 13*/
		if hh_size_mcd[i] in (1, 2) then do;
		mcd_earned_disregard[i]=edisregard2015_amt;
		qmb_inc_threshold[i]=QMB_INC_2015; slmb_inc_threshold[i]=SLMB_INC_2015; qi_inc_threshold[i]=QI_INC_2015;
		msp_add_inc_disregard[i]=msp_add_annual_disregard_w13; end;
		if hh_size_mcd[i]=1 then do;
				mcd_inc_threshold[i]=medicaid_inc_single_2015;
				mcd_gen_disregard[i]=gdisregard2015_s;
				mcd_asset_threshold[i]=medicaid_asset_single_2015; 
				msp_asset_threshold[i]=MSP_Asset1_2015;
				lis_full_asset_threshold[i]=7280 ; lis_part_asset_threshold[i]=12140; /* LIS asset tests are based only on householder and spouse */
			end;
			if hh_size_mcd[i]=2 then do; 
				mcd_inc_threshold[i]=medicaid_inc_couple_2015;
				mcd_gen_disregard[i]=gdisregard2015_c;
				mcd_asset_threshold[i]=medicaid_asset_couple_2015; 
				msp_asset_threshold[i]=MSP_Asset2_2015;
				lis_full_asset_threshold[i]=10930 ; lis_part_asset_threshold[i]=24250; /* LIS asset tests are based only on householder and spouse */
			end;
	end;

	if year[i]-1=2016 then do; /*wave 13*/
		if hh_size_mcd[i] in (1, 2) then do;
		mcd_earned_disregard[i]=edisregard2016_amt;
		qmb_inc_threshold[i]=QMB_INC_2016; slmb_inc_threshold[i]=SLMB_INC_2016; qi_inc_threshold[i]=QI_INC_2016;
		msp_add_inc_disregard[i]=msp_add_annual_disregard_w13; end;
		if hh_size_mcd[i]=1 then do;
				mcd_inc_threshold[i]=medicaid_inc_single_2016;
				mcd_gen_disregard[i]=gdisregard2016_s;
				mcd_asset_threshold[i]=medicaid_asset_single_2016; 
				msp_asset_threshold[i]=MSP_Asset1_2016;
				lis_full_asset_threshold[i]=7280 ; lis_part_asset_threshold[i]=12140; /* LIS asset tests are based only on householder and spouse */
			end;
			if hh_size_mcd[i]=2 then do; 
				mcd_inc_threshold[i]=medicaid_inc_couple_2016;
				mcd_gen_disregard[i]=gdisregard2016_c;
				mcd_asset_threshold[i]=medicaid_asset_couple_2016; 
				msp_asset_threshold[i]=MSP_Asset2_2016;
				lis_full_asset_threshold[i]=10930 ; lis_part_asset_threshold[i]=24250; /* LIS asset tests are based only on householder and spouse */
			end;
	end;

	if year[i]-1=2017 then do; /*wave 13*/
		if hh_size_mcd[i] in (1, 2) then do;
		mcd_earned_disregard[i]=edisregard2017_amt;
		qmb_inc_threshold[i]=QMB_INC_2017; slmb_inc_threshold[i]=SLMB_INC_2017; qi_inc_threshold[i]=QI_INC_2017;
		msp_add_inc_disregard[i]=msp_add_annual_disregard_w13; end;
			if hh_size_mcd[i]=1 then do;
				mcd_inc_threshold[i]=medicaid_inc_single_2017;
				mcd_gen_disregard[i]=gdisregard2017_s;
				mcd_asset_threshold[i]=medicaid_asset_single_2017; 
				msp_asset_threshold[i]=MSP_Asset1_2017;
				lis_full_asset_threshold[i]=7390 ; lis_part_asset_threshold[i]=12320; /* LIS asset tests are based only on householder and spouse */
			end;
			if hh_size_mcd[i]=2 then do; 
				mcd_inc_threshold[i]=medicaid_inc_couple_2017;
				mcd_gen_disregard[i]=gdisregard2017_c;
				mcd_asset_threshold[i]=medicaid_asset_couple_2017; 
				msp_asset_threshold[i]=MSP_Asset2_2017;
				lis_full_asset_threshold[i]=11090 ; lis_part_asset_threshold[i]=24600; /* LIS asset tests are based only on householder and spouse */
			end;
	end;

end;
run;

title 'Summary statistics of eligibility thresholds';

proc means data=d.elig_thresholds N NMISS MEAN;
class inw9;
var mcd_inc_t_w9 qmb_inc_t_w9 slmb_inc_t_w9 qi_inc_t_w9 mcd_asset_t_w9 msp_asset_t_w9 lis_full_asset_t_w9 lis_part_asset_t_w9 mcd_gen_disregard_w9 mcd_earned_disregard_w9 msp_add_inc_disregard_w9; run;
proc freq data=d.elig_thresholds;
where inw9=1 & mcd_inc_t_w9=.;
tables STFIPS08 / missing; run;

proc means data=d.elig_thresholds N NMISS MEAN;
class inw12;
var mcd_inc_t_w12 qmb_inc_t_w12 slmb_inc_t_w12 qi_inc_t_w12 mcd_asset_t_w12 msp_asset_t_w12 lis_full_asset_t_w12 lis_part_asset_t_w12 mcd_gen_disregard_w12 mcd_earned_disregard_w12 msp_add_inc_disregard_w12; run;
proc freq data=d.elig_thresholds;
where inw12=1 & mcd_inc_t_w12=.;
tables STATEUSPS14 / missing; run;

proc means data=d.elig_thresholds N NMISS MEAN;
class inw13;
var mcd_inc_t_w13 qmb_inc_t_w13 slmb_inc_t_w13 qi_inc_t_w13 mcd_asset_t_w13 msp_asset_t_w13 lis_full_asset_t_w13 lis_part_asset_t_w13 mcd_gen_disregard_w13 mcd_earned_disregard_w13 msp_add_inc_disregard_w13; run;
proc freq data=d.elig_thresholds;
where inw13=1 & mcd_inc_t_w13=.;
tables STATEUSPS14 / missing; /*need to replace with STFIPS16 when available*/ run;

proc means data=d.elig_thresholds N NMISS MEAN STD MIN MAX;
title '*Double checking income thresholds and disregards in wave 9';
where STATEUSPS08 in ('CA' 'CT' 'IL' 'IN' 'PA' 'OH' 'NY' 'MS' 'MO' 'ME' 'TX' 'FL'); 
class couple_w9 LIWYEAR STATEUSPS08;
var mcd_inc_t_w9 qmb_inc_t_w9 slmb_inc_t_w9 qi_inc_t_w9 mcd_gen_disregard_w9 mcd_earned_disregard_w9 msp_add_inc_disregard_w9; run;
proc means data=d.elig_thresholds N NMISS MEAN STD MIN MAX;
title '*Double checking income thresholds in wave 10';
where STATEUSPS10 in ('CA' 'CT' 'IL' 'IN' 'PA' 'OH' 'NY' 'MS' 'MO' 'ME' 'TX' 'FL'); 
class couple_w10 MIWYEAR STATEUSPS10;
var mcd_inc_t_w10 qmb_inc_t_w10 slmb_inc_t_w10 qi_inc_t_w10 mcd_gen_disregard_w10 mcd_earned_disregard_w10 msp_add_inc_disregard_w10; run;
proc means data=d.elig_thresholds N NMISS MEAN STD MIN MAX;
title '*Double checking income thresholds in wave 11';
where STATEUSPS12 in ('CA' 'CT' 'IL' 'IN' 'PA' 'OH' 'NY' 'MS' 'MO' 'ME' 'TX' 'FL'); 
class couple_w11 NIWYEAR STATEUSPS12;
var mcd_inc_t_w11 qmb_inc_t_w11 slmb_inc_t_w11 qi_inc_t_w11 mcd_gen_disregard_w11 mcd_earned_disregard_w11 msp_add_inc_disregard_w11; run;
proc means data=d.elig_thresholds N NMISS MEAN STD MIN MAX;
title '*Double checking income thresholds in wave 12';
where STATEUSPS14 in ('CA' 'CT' 'IL' 'IN' 'PA' 'OH' 'NY' 'MS' 'MO' 'ME' 'TX' 'FL'); 
class couple_w12 OIWYEAR STATEUSPS14;
var mcd_inc_t_w12 qmb_inc_t_w12 slmb_inc_t_w12 qi_inc_t_w12 mcd_gen_disregard_w12 mcd_earned_disregard_w12 msp_add_inc_disregard_w12; run;
proc means data=d.elig_thresholds N NMISS MEAN STD MIN MAX;
title '*Double checking income thresholds in wave 13';
where STATEUSPS14 /*need to replace with STFIPS16 when available*/ in ('CA' 'CT' 'IL' 'IN' 'PA' 'OH' 'NY' 'MS' 'MO' 'ME' 'TX' 'FL'); 
class couple_w13 PIWYEAR STATEUSPS14 /*need to replace with STFIPS16 when available*/;
var mcd_inc_t_w13 qmb_inc_t_w13 slmb_inc_t_w13 qi_inc_t_w13 mcd_gen_disregard_w13 mcd_earned_disregard_w13 msp_add_inc_disregard_w13; run;

proc means data=d.elig_thresholds N NMISS MEAN STD MIN MAX;
title '*Double checking asset thresholds in wave 9';
where STATEUSPS08 in ('CA' 'CT' 'IL' 'IN' 'PA' 'OH' 'NY' 'MS' 'MO' 'ME' 'TX' 'FL');
class couple_w9 LIWYEAR STATEUSPS08;
var mcd_asset_t_w9 msp_asset_t_w9 lis_full_asset_t_w9 lis_part_asset_t_w9; run;
proc means data=d.elig_thresholds N NMISS MEAN STD MIN MAX;
title '*Double checking asset thresholds in wave 10';
where STATEUSPS10 in ('CA' 'CT' 'IL' 'IN' 'PA' 'OH' 'NY' 'MS' 'MO' 'ME' 'TX' 'FL');
class couple_w10 MIWYEAR STATEUSPS10;
var mcd_asset_t_w10 msp_asset_t_w10 lis_full_asset_t_w10 lis_part_asset_t_w10; run;
proc means data=d.elig_thresholds N NMISS MEAN STD MIN MAX;
title '*Double checking asset thresholds in wave 11';
where STATEUSPS12 in ('CA' 'CT' 'IL' 'IN' 'PA' 'OH' 'NY' 'MS' 'MO' 'ME' 'TX' 'FL');
class couple_w11 NIWYEAR STATEUSPS12;
var mcd_asset_t_w11 msp_asset_t_w11 lis_full_asset_t_w11 lis_part_asset_t_w11; run;
proc means data=d.elig_thresholds N NMISS MEAN STD MIN MAX;
title '*Double checking asset thresholds in wave 12';
where STATEUSPS14 in ('CA' 'CT' 'IL' 'IN' 'PA' 'OH' 'NY' 'MS' 'MO' 'ME' 'TX' 'FL'); 
class couple_w12 OIWYEAR STATEUSPS14;
var mcd_asset_t_w12 msp_asset_t_w12 lis_full_asset_t_w12 lis_part_asset_t_w12; run;
proc means data=d.elig_thresholds N NMISS MEAN STD MIN MAX;
title '*Double checking asset thresholds in wave 13';
where STATEUSPS14 /*need to replace with STFIPS16 when available*/ in ('CA' 'CT' 'IL' 'IN' 'PA' 'OH' 'NY' 'MS' 'MO' 'ME' 'TX' 'FL'); 
class couple_w13 PIWYEAR STATEUSPS14 /*need to replace with STFIPS16 when available*/;
var mcd_asset_t_w13 msp_asset_t_w13 lis_full_asset_t_w13 lis_part_asset_t_w13; run;

* Link thresholds back to primary analytic file;
data d.elig_thresholds;
set d.elig_thresholds (keep=HHID PN instate_w9 instate_w10 instate_w11 instate_w12 instate_w13
							mcd_inc_t_w9 			mcd_inc_t_w10 				mcd_inc_t_w11 				mcd_inc_t_w12				mcd_inc_t_w13
							qmb_inc_t_w9 			qmb_inc_t_w10 				qmb_inc_t_w11 				qmb_inc_t_w12				qmb_inc_t_w13
							slmb_inc_t_w9 			slmb_inc_t_w10 				slmb_inc_t_w11 				slmb_inc_t_w12				slmb_inc_t_w13
							qi_inc_t_w9 			qi_inc_t_w10 				qi_inc_t_w11 				qi_inc_t_w12				qi_inc_t_w13
							mcd_asset_t_w9 			mcd_asset_t_w10 			mcd_asset_t_w11 			mcd_asset_t_w12				mcd_asset_t_w13
							msp_asset_t_w9 			msp_asset_t_w10 			msp_asset_t_w11 			msp_asset_t_w12				msp_asset_t_w13
							lis_full_asset_t_w9		lis_full_asset_t_w10		lis_full_asset_t_w11		lis_full_asset_t_w12		lis_full_asset_t_w13
							lis_part_asset_t_w9		lis_part_asset_t_w10		lis_part_asset_t_w11		lis_part_asset_t_w12		lis_part_asset_t_w13
							mcd_gen_disregard_w9 	mcd_gen_disregard_w10		mcd_gen_disregard_w11		mcd_gen_disregard_w12		mcd_gen_disregard_w13
							mcd_earned_disregard_w9	mcd_earned_disregard_w10	mcd_earned_disregard_w11	mcd_earned_disregard_w12	mcd_earned_disregard_w13
							msp_add_inc_disregard_w9 msp_add_inc_disregard_w10 	msp_add_inc_disregard_w11 	msp_add_inc_disregard_w12	msp_add_inc_disregard_w13); run;
proc sort data=d.randhrs_merge_6; by HHID PN;
proc sort data=d.elig_thresholds; by HHID PN;
data d.randhrs_merge_7;
merge d.randhrs_merge_6 (in=in1) d.elig_thresholds (in=in2);
by HHID PN; run;


*************************************************************************************************************************;
* (8) Assess household income and assets relative to program eligibility thresholds;
*************************************************************************************************************************;
data d.randhrs_merge_8;
set d.randhrs_merge_7;

* Countable household income for Medicaid, net of exclusions (incorporates exclusions applicable to Medicaid in the household's state);
	* Income level ($);
		inc_mcd_w_ssi_w9=.; /* including SSI income */
		inc_mcd_w_ssi_w10=.;
		inc_mcd_w_ssi_w11=.;
		inc_mcd_w_ssi_w12=.;
		inc_mcd_w_ssi_w13=.;
		inc_mcd_x_ssi_w9=.; /* excluding SSI income */
		inc_mcd_x_ssi_w10=.;
		inc_mcd_x_ssi_w11=.;
		inc_mcd_x_ssi_w12=.;
		inc_mcd_x_ssi_w13=.;
	* Income relative to FPL;
		inc_fpl_mcd_w_ssi_w9=.; /* including SSI income */
		inc_fpl_mcd_w_ssi_w10=.;
		inc_fpl_mcd_w_ssi_w11=.;
		inc_fpl_mcd_w_ssi_w12=.;
		inc_fpl_mcd_w_ssi_w13=.;
		inc_fpl_mcd_x_ssi_w9=.; /* excluding SSI income */
		inc_fpl_mcd_x_ssi_w10=.;
		inc_fpl_mcd_x_ssi_w11=.;
		inc_fpl_mcd_x_ssi_w12=.;
		inc_fpl_mcd_x_ssi_w13=.;

* Countable household income for MSPs, net of exclusions (incorporates exclusions applicable to Medicaid in the household's state);
	* Income level ($);
		inc_msp_w_ssi_w9=.; /* including SSI income */
		inc_msp_w_ssi_w10=.;
		inc_msp_w_ssi_w11=.;
		inc_msp_w_ssi_w12=.;
		inc_msp_w_ssi_w13=.;
		inc_msp_x_ssi_w9=.; /* excluding SSI income */
		inc_msp_x_ssi_w10=.;
		inc_msp_x_ssi_w11=.;
		inc_msp_x_ssi_w12=.;
		inc_msp_x_ssi_w13=.;
	* Income relative to FPL;
		inc_fpl_msp_w_ssi_w9=.; /* including SSI income */
		inc_fpl_msp_w_ssi_w10=.;
		inc_fpl_msp_w_ssi_w11=.;
		inc_fpl_msp_w_ssi_w12=.;
		inc_fpl_msp_w_ssi_w13=.;
		inc_fpl_msp_x_ssi_w9=.; /* excluding SSI income */
		inc_fpl_msp_x_ssi_w10=.;
		inc_fpl_msp_x_ssi_w11=.;
		inc_fpl_msp_x_ssi_w12=.;
		inc_fpl_msp_x_ssi_w13=.;

* Countable household income for the LIS, net of exclusions (incorporates exclusions applicable to Medicaid in the household's state);
	* Income level ($);
		inc_lis_w_ssi_w9=.; /* including SSI income */
		inc_lis_w_ssi_w10=.;
		inc_lis_w_ssi_w11=.;
		inc_lis_w_ssi_w12=.;
		inc_lis_w_ssi_w13=.;
		inc_lis_x_ssi_w9=.; /* excluding SSI income */
		inc_lis_x_ssi_w10=.;
		inc_lis_x_ssi_w11=.;
		inc_lis_x_ssi_w12=.;
		inc_lis_x_ssi_w13=.;
	* Income relative to FPL;
		inc_fpl_lis_w_ssi_w9=.; /* including SSI income */
		inc_fpl_lis_w_ssi_w10=.;
		inc_fpl_lis_w_ssi_w11=.;
		inc_fpl_lis_w_ssi_w12=.;
		inc_fpl_lis_w_ssi_w13=.;
		inc_fpl_lis_x_ssi_w9=.; /* excluding SSI income */
		inc_fpl_lis_x_ssi_w10=.;
		inc_fpl_lis_x_ssi_w11=.;
		inc_fpl_lis_x_ssi_w12=.;
		inc_fpl_lis_x_ssi_w13=.;

* Difference between countable household income and program-specific income eligibility thresholds;
	* Full Medicaid;
		inc_diff_mcd_w_ssi_w9=.; /* including SSI income */
		inc_diff_mcd_w_ssi_w10=.;
		inc_diff_mcd_w_ssi_w11=.;
		inc_diff_mcd_w_ssi_w12=.;
		inc_diff_mcd_w_ssi_w13=.;
		inc_diff_mcd_x_ssi_w9=.;  /* excluding SSI income */
		inc_diff_mcd_x_ssi_w10=.;
		inc_diff_mcd_x_ssi_w11=.;
		inc_diff_mcd_x_ssi_w12=.;
		inc_diff_mcd_x_ssi_w13=.;
	* QMB;
		inc_diff_qmb_w_ssi_w9=.; /* including SSI income */
		inc_diff_qmb_w_ssi_w10=.;
		inc_diff_qmb_w_ssi_w11=.;
		inc_diff_qmb_w_ssi_w12=.;
		inc_diff_qmb_w_ssi_w13=.;
		inc_diff_qmb_x_ssi_w9=.;  /* excluding SSI income */
		inc_diff_qmb_x_ssi_w10=.;
		inc_diff_qmb_x_ssi_w11=.;
		inc_diff_qmb_x_ssi_w12=.;
		inc_diff_qmb_x_ssi_w13=.;
	* SLMB;
		inc_diff_slmb_w_ssi_w9=.; /* including SSI income */
		inc_diff_slmb_w_ssi_w10=.;
		inc_diff_slmb_w_ssi_w11=.;
		inc_diff_slmb_w_ssi_w12=.;
		inc_diff_slmb_w_ssi_w13=.;
		inc_diff_slmb_x_ssi_w9=.;  /* excluding SSI income */
		inc_diff_slmb_x_ssi_w10=.;
		inc_diff_slmb_x_ssi_w11=.;
		inc_diff_slmb_x_ssi_w12=.;
		inc_diff_slmb_x_ssi_w13=.;
	* QI;
		inc_diff_qi_w_ssi_w9=.; /* including SSI income */
		inc_diff_qi_w_ssi_w10=.;
		inc_diff_qi_w_ssi_w11=.;
		inc_diff_qi_w_ssi_w12=.;
		inc_diff_qi_w_ssi_w13=.;
		inc_diff_qi_x_ssi_w9=.;  /* excluding SSI income */
		inc_diff_qi_x_ssi_w10=.;
		inc_diff_qi_x_ssi_w11=.;
		inc_diff_qi_x_ssi_w12=.;
		inc_diff_qi_x_ssi_w13=.;
	* Full LIS;
		inc_diff_lis_full_w_ssi_w9=.; /* including SSI income */
		inc_diff_lis_full_w_ssi_w10=.;
		inc_diff_lis_full_w_ssi_w11=.;
		inc_diff_lis_full_w_ssi_w12=.;
		inc_diff_lis_full_x_ssi_w9=.;  /* excluding SSI income */
		inc_diff_lis_full_x_ssi_w10=.;
		inc_diff_lis_full_x_ssi_w11=.;
		inc_diff_lis_full_x_ssi_w12=.;
	* Partial LIS;
		inc_diff_lis_part_w_ssi_w9=.; /* including SSI income */
		inc_diff_lis_part_w_ssi_w10=.;
		inc_diff_lis_part_w_ssi_w11=.;
		inc_diff_lis_part_w_ssi_w12=.;
		inc_diff_lis_part_w_ssi_w13=.;
		inc_diff_lis_part_x_ssi_w9=.;  /* excluding SSI income */
		inc_diff_lis_part_x_ssi_w10=.;
		inc_diff_lis_part_x_ssi_w11=.;
		inc_diff_lis_part_x_ssi_w12=.;
		inc_diff_lis_part_x_ssi_w13=.;

* Difference between countable household assets and program-specific resource thresholds, and 0/1 indicator that assets were below program eligibiltiy thresholds;
	* Medicaid;
		asset_diff_mcd_w9=.;  asset_below_mcd_w9=.; 
		asset_diff_mcd_w10=.; asset_below_mcd_w10=.; 
		asset_diff_mcd_w11=.; asset_below_mcd_w11=.; 
		asset_diff_mcd_w12=.; asset_below_mcd_w12=.; 
		asset_diff_mcd_w13=.; asset_below_mcd_w13=.; 
	* MSPs (applies to QMB, SLMB, and QI);
		asset_diff_msp_w9=.;  asset_below_msp_w9=.; 
		asset_diff_msp_w10=.; asset_below_msp_w10=.; 
		asset_diff_msp_w11=.; asset_below_msp_w11=.;
		asset_diff_msp_w12=.; asset_below_msp_w12=.;
		asset_diff_msp_w13=.; asset_below_msp_w13=.;
	* Full LIS;
		asset_diff_lis_full_w9=.;  asset_below_lis_full_w9=.;
		asset_diff_lis_full_w10=.; asset_below_lis_full_w10=.;
		asset_diff_lis_full_w11=.; asset_below_lis_full_w11=.;
		asset_diff_lis_full_w12=.; asset_below_lis_full_w12=.;
		asset_diff_lis_full_w13=.; asset_below_lis_full_w13=.;
	* Partial LIS;
		asset_diff_lis_part_w9=.;  asset_below_lis_part_w9=.;
		asset_diff_lis_part_w10=.; asset_below_lis_part_w10=.;
		asset_diff_lis_part_w11=.; asset_below_lis_part_w11=.;
		asset_diff_lis_part_w12=.; asset_below_lis_part_w12=.;
		asset_diff_lis_part_w13=.; asset_below_lis_part_w13=.;

* Declare arrays for ...;
	* Previously calculated -- Income, including earned and unearned income with and without SSI income counting towards unearned income (and hence income);
	array tot_income_w_ssi {5} tot_inc_w_ssi_w9 tot_inc_w_ssi_w10 tot_inc_w_ssi_w11 tot_inc_w_ssi_w12 tot_inc_w_ssi_w13;
	array tot_income_x_ssi {5} tot_inc_x_ssi_w9 tot_inc_x_ssi_w10 tot_inc_x_ssi_w11 tot_inc_x_ssi_w12 tot_inc_x_ssi_w13;
	array tot_earned_income {5} tot_earned_inc_w9 tot_earned_inc_w10 tot_earned_inc_w11 tot_earned_inc_w12 tot_earned_inc_w13;
	array tot_unearn_income_w_ssi {5} tot_unearned_inc_w_ssi_w9 tot_unearned_inc_w_ssi_w10 tot_unearned_inc_w_ssi_w11 tot_unearned_inc_w_ssi_w12 tot_unearned_inc_w_ssi_w13;
	array tot_unearn_income_x_ssi {5} tot_unearned_inc_x_ssi_w9 tot_unearned_inc_x_ssi_w10 tot_unearned_inc_x_ssi_w11 tot_unearned_inc_x_ssi_w12 tot_unearned_inc_x_ssi_w13;

	* Countable assets;
	array countable_assets {5} countable_asset_w9 countable_asset_w10 countable_asset_w11 countable_asset_w12 countable_asset_w13;

	* Federal poverty guidelines based on two-person household (applicable to Medicaid and MSPs);
	array pov_guideline_mcd {5} pov_guideline_mcd_w9 pov_guideline_mcd_w10 pov_guideline_mcd_w11 pov_guideline_mcd_w12 pov_guideline_mcd_w13;

	* Federal poverty guidelines based on household including dependents (applicable to LIS);
	array pov_guideline_lis {5} pov_guideline_lis_w9 pov_guideline_lis_w10 pov_guideline_lis_w11 pov_guideline_lis_w12 pov_guideline_lis_w13;

	* Eligibility thresholds (in FPL for income);
	array mcd_inc_t {5} mcd_inc_t_w9 mcd_inc_t_w10 mcd_inc_t_w11 mcd_inc_t_w12 mcd_inc_t_w13;
	array qmb_inc_t {5} qmb_inc_t_w9 qmb_inc_t_w10 qmb_inc_t_w11 qmb_inc_t_w12 qmb_inc_t_w13;
	array slmb_inc_t {5} slmb_inc_t_w9 slmb_inc_t_w10 slmb_inc_t_w11 slmb_inc_t_w12 slmb_inc_t_w13;
	array qi_inc_t {5} qi_inc_t_w9 qi_inc_t_w10 qi_inc_t_w11 qi_inc_t_w12 qi_inc_t_w13;
	array mcd_asset_t {5} mcd_asset_t_w9 mcd_asset_t_w10 mcd_asset_t_w11 mcd_asset_t_w12 mcd_asset_t_w13;
	array msp_asset_t {5} msp_asset_t_w9 msp_asset_t_w10 msp_asset_t_w11 msp_asset_t_w12 msp_asset_t_w13;
	array lis_full_asset_t {5} lis_full_asset_t_w9 lis_full_asset_t_w10 lis_full_asset_t_w11 lis_full_asset_t_w12 lis_full_asset_t_w13;
	array lis_part_asset_t {5} lis_part_asset_t_w9 lis_part_asset_t_w10 lis_part_asset_t_w11 lis_part_asset_t_w12 lis_part_asset_t_w13;

	* Income disregards ($);
	array mcd_gen_disregard {5} mcd_gen_disregard_w9 mcd_gen_disregard_w10 mcd_gen_disregard_w11 mcd_gen_disregard_w12 mcd_gen_disregard_w13;
	array mcd_earned_disregard {5} mcd_earned_disregard_w9 mcd_earned_disregard_w10 mcd_earned_disregard_w11 mcd_earned_disregard_w12 mcd_earned_disregard_w13;
	array msp_add_inc_disregard {5} msp_add_inc_disregard_w9 msp_add_inc_disregard_w10 msp_add_inc_disregard_w11 msp_add_inc_disregard_w12 msp_add_inc_disregard_w13;

	* Calculated this step -- Income net of exclusions applicable to program (Medicaid, MSPs, LIS);
	array inc_mcd_w_ssi {5} inc_mcd_w_ssi_w9 inc_mcd_w_ssi_w10 inc_mcd_w_ssi_w11 inc_mcd_w_ssi_w12 inc_mcd_w_ssi_w13;
	array inc_mcd_x_ssi {5} inc_mcd_x_ssi_w9 inc_mcd_x_ssi_w10 inc_mcd_x_ssi_w11 inc_mcd_x_ssi_w12 inc_mcd_x_ssi_w13;
	array inc_msp_w_ssi {5} inc_msp_w_ssi_w9 inc_msp_w_ssi_w10 inc_msp_w_ssi_w11 inc_msp_w_ssi_w12 inc_msp_w_ssi_w13;
	array inc_msp_x_ssi {5} inc_msp_x_ssi_w9 inc_msp_x_ssi_w10 inc_msp_x_ssi_w11 inc_msp_x_ssi_w12 inc_msp_x_ssi_w13;
	array inc_lis_w_ssi {5} inc_lis_w_ssi_w9 inc_lis_w_ssi_w10 inc_lis_w_ssi_w11 inc_lis_w_ssi_w12 inc_lis_w_ssi_w13;
	array inc_lis_x_ssi {5} inc_lis_x_ssi_w9 inc_lis_x_ssi_w10 inc_lis_x_ssi_w11 inc_lis_x_ssi_w12 inc_lis_x_ssi_w13;

	* Calculated this step -- Income relative to FPL, net of exclusions applicable to program (Medicaid, MSPs, LIS);
	array inc_fpl_mcd_w_ssi {5} inc_fpl_mcd_w_ssi_w9 inc_fpl_mcd_w_ssi_w10 inc_fpl_mcd_w_ssi_w11 inc_fpl_mcd_w_ssi_w12 inc_fpl_mcd_w_ssi_w13;
	array inc_fpl_mcd_x_ssi {5} inc_fpl_mcd_x_ssi_w9 inc_fpl_mcd_x_ssi_w10 inc_fpl_mcd_x_ssi_w11 inc_fpl_mcd_x_ssi_w12 inc_fpl_mcd_x_ssi_w13;
	array inc_fpl_msp_w_ssi {5} inc_fpl_msp_w_ssi_w9 inc_fpl_msp_w_ssi_w10 inc_fpl_msp_w_ssi_w11 inc_fpl_msp_w_ssi_w12 inc_fpl_msp_w_ssi_w13;
	array inc_fpl_msp_x_ssi {5} inc_fpl_msp_x_ssi_w9 inc_fpl_msp_x_ssi_w10 inc_fpl_msp_x_ssi_w11 inc_fpl_msp_x_ssi_w12 inc_fpl_msp_x_ssi_w13;
	array inc_fpl_lis_w_ssi {5} inc_fpl_lis_w_ssi_w9 inc_fpl_lis_w_ssi_w10 inc_fpl_lis_w_ssi_w11 inc_fpl_lis_w_ssi_w12 inc_fpl_lis_w_ssi_w13;
	array inc_fpl_lis_x_ssi {5} inc_fpl_lis_x_ssi_w9 inc_fpl_lis_x_ssi_w10 inc_fpl_lis_x_ssi_w11 inc_fpl_lis_x_ssi_w12 inc_fpl_lis_x_ssi_w13;

	* Differences between household income (measured per program rules) and program-specific income thresholds;
	array inc_diff_mcd_w_ssi {5} inc_diff_mcd_w_ssi_w9 inc_diff_mcd_w_ssi_w10 inc_diff_mcd_w_ssi_w11 inc_diff_mcd_w_ssi_w12 inc_diff_mcd_w_ssi_w13;
	array inc_diff_mcd_x_ssi {5} inc_diff_mcd_x_ssi_w9 inc_diff_mcd_x_ssi_w10 inc_diff_mcd_x_ssi_w11 inc_diff_mcd_x_ssi_w12 inc_diff_mcd_x_ssi_w13;
	array inc_diff_qmb_w_ssi {5} inc_diff_qmb_w_ssi_w9 inc_diff_qmb_w_ssi_w10 inc_diff_qmb_w_ssi_w11 inc_diff_qmb_w_ssi_w12 inc_diff_qmb_w_ssi_w13;
	array inc_diff_qmb_x_ssi {5} inc_diff_qmb_x_ssi_w9 inc_diff_qmb_x_ssi_w10 inc_diff_qmb_x_ssi_w11 inc_diff_qmb_x_ssi_w12 inc_diff_qmb_x_ssi_w13;
	array inc_diff_slmb_w_ssi {5} inc_diff_slmb_w_ssi_w9 inc_diff_slmb_w_ssi_w10 inc_diff_slmb_w_ssi_w11 inc_diff_slmb_w_ssi_w12 inc_diff_slmb_w_ssi_w13;
	array inc_diff_slmb_x_ssi {5} inc_diff_slmb_x_ssi_w9 inc_diff_slmb_x_ssi_w10 inc_diff_slmb_x_ssi_w11 inc_diff_slmb_x_ssi_w12 inc_diff_slmb_x_ssi_w13;
	array inc_diff_qi_w_ssi {5} inc_diff_qi_w_ssi_w9 inc_diff_qi_w_ssi_w10 inc_diff_qi_w_ssi_w11 inc_diff_qi_w_ssi_w12 inc_diff_qi_w_ssi_w13;
	array inc_diff_qi_x_ssi {5} inc_diff_qi_x_ssi_w9 inc_diff_qi_x_ssi_w10 inc_diff_qi_x_ssi_w11 inc_diff_qi_x_ssi_w12 inc_diff_qi_x_ssi_w13;
	array inc_diff_lis_full_w_ssi {5} inc_diff_lis_full_w_ssi_w9 inc_diff_lis_full_w_ssi_w10 inc_diff_lis_full_w_ssi_w11 inc_diff_lis_full_w_ssi_w12 inc_diff_lis_full_w_ssi_w13;
	array inc_diff_lis_full_x_ssi {5} inc_diff_lis_full_x_ssi_w9 inc_diff_lis_full_x_ssi_w10 inc_diff_lis_full_x_ssi_w11 inc_diff_lis_full_x_ssi_w12 inc_diff_lis_full_x_ssi_w13;
	array inc_diff_lis_part_w_ssi {5} inc_diff_lis_part_w_ssi_w9 inc_diff_lis_part_w_ssi_w10 inc_diff_lis_part_w_ssi_w11 inc_diff_lis_part_w_ssi_w12 inc_diff_lis_part_w_ssi_w13;
	array inc_diff_lis_part_x_ssi {5} inc_diff_lis_part_x_ssi_w9 inc_diff_lis_part_x_ssi_w10 inc_diff_lis_part_x_ssi_w11 inc_diff_lis_part_x_ssi_w12 inc_diff_lis_part_x_ssi_w13;

	* Differences between household assets and program-specific asset thresholds;
	array asset_diff_mcd {5} asset_diff_mcd_w9 asset_diff_mcd_w10 asset_diff_mcd_w11 asset_diff_mcd_w12 asset_diff_mcd_w13;
	array asset_diff_msp {5} asset_diff_msp_w9 asset_diff_msp_w10 asset_diff_msp_w11 asset_diff_msp_w12 asset_diff_msp_w13;
	array asset_diff_lis_full {5} asset_diff_lis_full_w9 asset_diff_lis_full_w10 asset_diff_lis_full_w11 asset_diff_lis_full_w12 asset_diff_lis_full_w13;
	array asset_diff_lis_part {5} asset_diff_lis_part_w9 asset_diff_lis_part_w10 asset_diff_lis_part_w11 asset_diff_lis_part_w12 asset_diff_lis_part_w13;

	* Indicators that assets are below program-specific asset thresholds;
	array asset_below_mcd {5} asset_below_mcd_w9 asset_below_mcd_w10 asset_below_mcd_w11 asset_below_mcd_w12 asset_below_mcd_w13;
	array asset_below_msp {5} asset_below_msp_w9 asset_below_msp_w10 asset_below_msp_w11 asset_below_msp_w12 asset_below_msp_w13;
	array asset_below_lis_full {5} asset_below_lis_full_w9 asset_below_lis_full_w10 asset_below_lis_full_w11 asset_below_lis_full_w12 asset_below_lis_full_w13;
	array asset_below_lis_part {5} asset_below_lis_part_w9 asset_below_lis_part_w10 asset_below_lis_part_w11 asset_below_lis_part_w12 asset_below_lis_part_w13;

	* Instate is an indicator that the respondent lived in one of the 50 states or DC in the survey round (excludes residents of PR or foreign territories);
	array instate {5} instate_w9 instate_w10 instate_w11 instate_w12 instate_w13;

* Temporary variables to hold disregarded income and income carryovers;
disregard_1_temp=.;
disregard_2_temp=.;
carryover_temp=.;

* PART 1: Calculate income net of disregards specific to each program, year, and state, and convert to % of FPL;
* Note 1: When calculating disregarded income, first apply the standard disregard (+ any state supplements), then apply the additional disregard on earned income, via the following 2 steps:
* 		First, disregard the lesser of unearned income or the maximum standard disregard (plus any supplemental state disregards),
* 		Second, apply the earned income disregard, equal to: (a) $780 plus any carryover (unused) balances from the unearned income disregard, plus (b) 50% of earned income in excess of the amount in (a);
* Note 2: Income disregards are annualized (monthly disregards multipled by 12);
* Note 3: Poverty guidelines for Medicaid and MSPs are based on single or couple households (pov_guideline_mcd[i]), while poverty guidelines for the LIS (pov_guideline_lis[i]) include dependents;
do i=1 to 5;
	if instate[i]=1 then do; /* only include households in 50 US states and DC in survey wave */

		** FULL MEDICAID **;
		* Including SSI in unearned income;
			if tot_income_w_ssi[i]~=. then do;
				disregard_1_temp  		=min(tot_unearn_income_w_ssi[i],mcd_gen_disregard[i]*12); /* remember to annualize the monthly disregard (hence *12), disregard unearned income up to the ceiling */
				if tot_income_w_ssi[i]  <=0 then carryover_temp=0;
				if tot_income_w_ssi[i]  > 0 then carryover_temp=max(0,mcd_gen_disregard[i]*12-tot_unearn_income_w_ssi[i]);
				disregard_2_temp		=min(tot_earned_income[i],mcd_earned_disregard[i]*12+carryover_temp) + max(0,(tot_earned_income[i]-mcd_earned_disregard[i]*12-carryover_temp)*0.50);
				inc_mcd_w_ssi[i]     	=max(0,tot_income_w_ssi[i]-disregard_1_temp-disregard_2_temp);
				inc_fpl_mcd_w_ssi[i]	=100*(inc_mcd_w_ssi[i]/pov_guideline_mcd[i]);
				disregard_1_temp=.; disregard_2_temp=.; carryover_temp=.;
			end;
		* Excluding SSI from unearned income;
			if tot_income_x_ssi[i]~=. then do;
				disregard_1_temp  		=min(tot_unearn_income_x_ssi[i],mcd_gen_disregard[i]*12);
				if tot_income_x_ssi[i]  <=0 then carryover_temp=0;
				if tot_income_x_ssi[i]  > 0 then carryover_temp=max(0,mcd_gen_disregard[i]*12-tot_unearn_income_x_ssi[i]);
				disregard_2_temp		=min(tot_earned_income[i],mcd_earned_disregard[i]*12+carryover_temp) + max(0,(tot_earned_income[i]-mcd_earned_disregard[i]*12-carryover_temp)*0.50);
				inc_mcd_x_ssi[i]     	=max(0,tot_income_x_ssi[i]-disregard_1_temp-disregard_2_temp);
				inc_fpl_mcd_x_ssi[i]	=100*(inc_mcd_x_ssi[i]/pov_guideline_mcd[i]);
				disregard_1_temp=.; disregard_2_temp=.; carryover_temp=.;
			end;

		** MSPs **;
		* Including SSI in unearned income;
			if tot_income_w_ssi[i]~=. then do;
				disregard_1_temp  		=min(tot_unearn_income_w_ssi[i],20*12+msp_add_inc_disregard[i]);
				if tot_income_w_ssi[i]  <=0 then carryover_temp=0;
				if tot_income_w_ssi[i]  > 0 then carryover_temp=max(0,20*12+msp_add_inc_disregard[i]-tot_unearn_income_w_ssi[i]);
				disregard_2_temp		=min(tot_earned_income[i],65*12+carryover_temp) + max(0,(tot_earned_income[i]-65*12-carryover_temp)*0.50);
				inc_msp_w_ssi[i]     	=max(0,tot_income_w_ssi[i]-disregard_1_temp-disregard_2_temp);
				inc_fpl_msp_w_ssi[i]	=100*(inc_msp_w_ssi[i]/pov_guideline_mcd[i]);
				disregard_1_temp=.; disregard_2_temp=.; carryover_temp=.;
			end;
		* Excluding SSI from unearned income;
			if tot_income_x_ssi[i]~=. then do;
				disregard_1_temp  		=min(tot_unearn_income_x_ssi[i],20*12+msp_add_inc_disregard[i]);
				if tot_income_x_ssi[i]  <=0 then carryover_temp=0;
				if tot_income_x_ssi[i]  > 0 then carryover_temp=max(0,20*12+msp_add_inc_disregard[i]-tot_unearn_income_x_ssi[i]);
				disregard_2_temp		=min(tot_earned_income[i],65*12+carryover_temp) + max(0,(tot_earned_income[i]-65*12-carryover_temp)*0.50);
				inc_msp_x_ssi[i]     	=max(0,tot_income_x_ssi[i]-disregard_1_temp-disregard_2_temp);
				inc_fpl_msp_x_ssi[i]	=100*(inc_msp_x_ssi[i]/pov_guideline_mcd[i]);
				disregard_1_temp=.; disregard_2_temp=.; carryover_temp=.;
			end;

		** LIS **;
		* Including SSI in unearned income;
			if tot_income_w_ssi[i]~=. then do;
				disregard_1_temp  		=min(tot_unearn_income_w_ssi[i],20*12);
				if tot_income_w_ssi[i]  <=0 then carryover_temp=0;
				if tot_income_w_ssi[i]  > 0 then carryover_temp=max(0,20*12-tot_unearn_income_w_ssi[i]);
				disregard_2_temp		=min(tot_earned_income[i],65*12+carryover_temp) + max(0,(tot_earned_income[i]-65*12-carryover_temp)*0.50);
				inc_lis_w_ssi[i]     	=max(0,tot_income_w_ssi[i]-disregard_1_temp-disregard_2_temp);
				inc_fpl_lis_w_ssi[i]	=100*(inc_lis_w_ssi[i]/pov_guideline_lis[i]); /* apply LIS poverty guidelines */
				disregard_1_temp=.; disregard_2_temp=.; carryover_temp=.;
			end;
		* Excluding SSI from unearned income;
			if tot_income_x_ssi[i]~=. then do;
				disregard_1_temp  		=min(tot_unearn_income_x_ssi[i],20*12);
				if tot_income_x_ssi[i]  <=0 then carryover_temp=0;
				if tot_income_x_ssi[i]  > 0 then carryover_temp=max(0,20*12-tot_unearn_income_x_ssi[i]);
				disregard_2_temp		=min(tot_earned_income[i],65*12+carryover_temp) + max(0,(tot_earned_income[i]-65*12-carryover_temp)*0.50);
				inc_lis_x_ssi[i]     	=max(0,tot_income_x_ssi[i]-disregard_1_temp-disregard_2_temp);
				inc_fpl_lis_x_ssi[i]	=100*(inc_lis_x_ssi[i]/pov_guideline_lis[i]); /* apply LIS poverty guidelines */
				disregard_1_temp=.; disregard_2_temp=.; carryover_temp=.;
			end;
		end;
end;

* PART 2: Compare income and assets to program-specific thresholds;
do i=1 to 5;
	if instate[i]=1 then do; /* only include households in 50 US states and DC in survey wave */
	* Income thresholds *;
		* Medicaid -- difference between household income (net of exclusions) under Medicaid counting guidelines and the state-specific Mediciad eligibility threshold;
			inc_diff_mcd_w_ssi[i]=inc_fpl_mcd_w_ssi[i]-mcd_inc_t[i];
			inc_diff_mcd_x_ssi[i]=inc_fpl_mcd_x_ssi[i]-mcd_inc_t[i];
		* MSP -- QMB -- difference between household income (net of exclusions) under MSP counting guidelines and the state-specific QMB eligibility threshold;
			inc_diff_qmb_w_ssi[i]=inc_fpl_msp_w_ssi[i]-qmb_inc_t[i];
			inc_diff_qmb_x_ssi[i]=inc_fpl_msp_x_ssi[i]-qmb_inc_t[i];
		* MSP -- SLMB difference between household income (net of exclusions) under MSP counting guidelines and the state-specific SLMB eligibility threshold;
			inc_diff_slmb_w_ssi[i]=inc_fpl_msp_w_ssi[i]-slmb_inc_t[i];
			inc_diff_slmb_x_ssi[i]=inc_fpl_msp_x_ssi[i]-slmb_inc_t[i];
		* MSP -- QI difference between household income (net of exclusions) under MSP counting guidelines and the state-specific QI eligibility threshold;
			inc_diff_qi_w_ssi[i]=inc_fpl_msp_w_ssi[i]-qi_inc_t[i];
			inc_diff_qi_x_ssi[i]=inc_fpl_msp_x_ssi[i]-qi_inc_t[i];
		* Full LIS -- difference between household income (net of exclusions) under LIS counting guidelines and the full LIS eligibility threshold;
			inc_diff_lis_full_w_ssi[i]=inc_fpl_lis_w_ssi[i]-135; /*For the partial LIS, income threshold of 135% of FPL is constant across states and years */
			inc_diff_lis_full_x_ssi[i]=inc_fpl_lis_x_ssi[i]-135;
		* Partial LIS -- difference between household income (net of exclusions) under LIS counting guidelines and the partial LIS eligibility threshold;
			inc_diff_lis_part_w_ssi[i]=inc_fpl_lis_w_ssi[i]-150; /*For the full LIS, income threshold of 150% of FPL is constant across states and years */
			inc_diff_lis_part_x_ssi[i]=inc_fpl_lis_x_ssi[i]-150;
	* Asset thresholds -- calculate differences between HH assets program-specific thresholds and construct a binary indicator that assets were below thresholds;
		* Medicaid;
			asset_diff_mcd[i]=(countable_assets[i]-mcd_asset_t[i]);
			asset_below_mcd[i]=((countable_assets[i]-mcd_asset_t[i])<0);
		* MSP (all);
			asset_diff_msp[i]=(countable_assets[i]-msp_asset_t[i]);
			asset_below_msp[i]=((countable_assets[i]-msp_asset_t[i])<0);
		* Full LIS;
			asset_diff_lis_full[i]=(countable_assets[i]-lis_full_asset_t[i]);
			asset_below_lis_full[i]=((countable_assets[i]-lis_full_asset_t[i])<0);
		* Partial LIS;
			asset_diff_lis_part[i]=(countable_assets[i]-lis_part_asset_t[i]);
			asset_below_lis_part[i]=((countable_assets[i]-lis_part_asset_t[i])<0);
	end;
end;
run;
/* Export files for manual checking of income disregards */
data work.testinc_w9;
set d.randhrs_merge_8 (keep=HHID PN STATEUSPS08 LIWYEAR couple_w9 hh_size_w9 mcd_gen_disregard_w9 mcd_earned_disregard_w9 msp_add_inc_disregard_w9 tot_earned_inc_w9 tot_unearned_inc_x_ssi_w9 inc_mcd_x_ssi_w9 inc_msp_x_ssi_w9 inc_lis_x_ssi_w9 inc_fpl_lis_x_ssi_w9 inc_diff_lis_full_x_ssi_w9); run;
data work.testinc_w12;
set d.randhrs_merge_8 (keep=HHID PN STATEUSPS14 OIWYEAR couple_w12 hh_size_w12 mcd_gen_disregard_w12 mcd_earned_disregard_w12 msp_add_inc_disregard_w12 tot_earned_inc_w12 tot_unearned_inc_x_ssi_w12 inc_mcd_x_ssi_w12 inc_msp_x_ssi_w12 inc_lis_x_ssi_w12 inc_fpl_lis_x_ssi_w12 inc_diff_lis_full_x_ssi_w12); run;
data work.testinc_w13;
set d.randhrs_merge_8 (keep=HHID PN STATEUSPS14 /*need to replace with STFIPS16 when available*/ PIWYEAR couple_w13 hh_size_w13 mcd_gen_disregard_w13 mcd_earned_disregard_w13 msp_add_inc_disregard_w13 tot_earned_inc_w13 tot_unearned_inc_x_ssi_w13 inc_mcd_x_ssi_w13 inc_msp_x_ssi_w13 inc_lis_x_ssi_w13 inc_fpl_lis_x_ssi_w13 inc_diff_lis_full_x_ssi_w13); run;


*************************************************************************************************************************;
* (9) Health care use, expenditures, and access to care variables;
*************************************************************************************************************************;
* Merge on access and cost-related avoidance of care measures from HRS fat file;
data d.randhrs_merge_9;
merge d.randhrs_merge_8 (in=in1) f.Hc_cost_access (in=in2);
by HHID PN;
if in1; run;

* Format other use and out of pocket cost variables;
data d.randhrs_merge_9;
set d.randhrs_merge_9;

any_hosp_w9=.;
any_hosp_w10=.;
any_hosp_w11=.;
any_hosp_w12=.;
any_hosp_w13=.;

num_hosp_w9=.;
num_hosp_w10=.;
num_hosp_w11=.;
num_hosp_w12=.;
num_hosp_w13=.;

any_nh_w9=.;
any_nh_w10=.;
any_nh_w11=.;
any_nh_w12=.;
any_nh_w13=.;

num_nh_w9=.;
num_nh_w10=.;
num_nh_w11=.;
num_nh_w12=.;
num_nh_w13=.;

oop2yr_medexp_w9=.;
oop2yr_medexp_w10=.;
oop2yr_medexp_w11=.;
oop2yr_medexp_w12=.;
oop2yr_medexp_w13=.;

array any_hosp {5} R9HOSP R10HOSP R11HOSP R12HOSP R13HOSP;
array num_hosp {5} R9HSPTIM R10HSPTIM R11HSPTIM R12HSPTIM R13HSPTIM;
array any_nh {5} R9NRSHOM R10NRSHOM R11NRSHOM R12NRSHOM R13NRSHOM;
array num_nh {5} R9NRSTIM R10NRSTIM R11NRSTIM R12NRSTIM R13NRSTIM;
array oop {5} R9OOPMD R10OOPMD R11OOPMD R12OOPMD R13OOPMD;
array any_hosp_coded {5} any_hosp_w9 any_hosp_w10 any_hosp_w11 any_hosp_w12 any_hosp_w13;
array num_hosp_coded {5} num_hosp_w9 num_hosp_w10 num_hosp_w11 num_hosp_w12 num_hosp_w13;
array any_nh_coded {5} any_nh_w9 any_nh_w10 any_nh_w11 any_nh_w12 any_nh_w13;
array num_nh_coded {5} num_nh_w9 num_nh_w10 num_nh_w11 num_nh_w12 num_nh_w13;
array oop_coded {5} oop2yr_medexp_w9 oop2yr_medexp_w10 oop2yr_medexp_w11 oop2yr_medexp_w12 oop2yr_medexp_w13;

do i=1 to 5;
	if any_hosp[i] in (0 1) then any_hosp_coded[i]=(any_hosp[i]=1);
	if num_hosp[i] in (0:200) then num_hosp_coded[i]=num_hosp[i];
	if any_nh[i] in (0 1) then any_nh_coded[i]=(any_nh[i]=1);
	if num_nh[i] in (0:200) then num_nh_coded[i]=num_nh[i];
	if oop[i] ne . then oop_coded[i]=oop[i];
end; run;

proc means data=d.randhrs_merge_9 N NMISS MIN P5 P10 P25 P50 P75 P90 P95 MEAN MAX;
class inw9;
var any_hosp_w9 num_hosp_w9 oop2yr_medexp_w9 skip_rx_cst_w9; run;
proc means data=d.randhrs_merge_9 N NMISS MIN P5 P10 P25 P50 P75 P90 P95 MEAN MAX;
class inw12;
var any_hosp_w12 num_hosp_w12 oop2yr_medexp_w12 skip_rx_cst_w12 usc_w12 usc_dr_w12 troub_find_dr_w12; run;
proc means data=d.randhrs_merge_9 N NMISS MIN P5 P10 P25 P50 P75 P90 P95 MEAN MAX;
class inw13;
var any_hosp_w13 num_hosp_w13 oop2yr_medexp_w13 skip_rx_cst_w13 usc_w13 usc_dr_w13 troub_find_dr_w13; run;
proc freq data=d.randhrs_merge_9;
tables inw9 * R9HOSP * R9HSPTIM / missing;
tables inw10 * R10HOSP * R10HSPTIM / missing; 
tables inw12 * R12HOSP * R12HSPTIM / missing; 
tables inw13 * R13HOSP * R13HSPTIM / missing; run;


*************************************************************************************************************************;
* (10) Institutionalization (nursing home residence for respondent or spouse) and self-reported health status variables;
* Note: Most of these variables follow those used in Barnett, Hsu, Landon, and McWilliams (2015)
*************************************************************************************************************************;
data d.randhrs_merge_10;
set d.randhrs_merge_9;

nh_resp_w9=.;
nh_resp_w10=.;
nh_resp_w11=.;
nh_resp_w12=.;
nh_resp_w13=.;

nh_anyinhh_w9=.;
nh_anyinhh_w10=.;
nh_anyinhh_w11=.;
nh_anyinhh_w12=.;
nh_anyinhh_w13=.;

array resp_nh {5} R9NHMLIV R10NHMLIV R11NHMLIV R12NHMLIV R13NHMLIV;
array spou_nh {5} S9NHMLIV S10NHMLIV S11NHMLIV S12NHMLIV S13NHMLIV;
array hhld_nh {5} H9NHMLIV H10NHMLIV H11NHMLIV H12NHMLIV H13NHMLIV;
array resp_nh_coded {5} nh_resp_w9 nh_resp_w10 nh_resp_w11 nh_resp_w12 nh_resp_w13;
array hhld_nh_coded {5} nh_anyinhh_w9 nh_anyinhh_w10 nh_anyinhh_w11 nh_anyinhh_w12 nh_anyinhh_w13;

do i=1 to 5;
	if resp_nh[i] in (0:1) then resp_nh_coded[i]=(resp_nh[i]=1);
	if hhld_nh[i] in (0:3) then hhld_nh_coded[i]=((hhld_nh[i] in (1:3)) or resp_nh[i]=1);
end; run;


proc freq data=d.randhrs_merge_6;
tables inw13 * (R13WALKSA R13CLIMSA R13CHAIRA R13STOOPA R13LIFTA R13ARMSA R13PUSHA) / missing; run;

data d.randhrs_merge_10;
set d.randhrs_merge_10;

* Recoding health status covariates -- look back one period where missing in present period to reduce missingness;
*  As a result, waves 10-12 will be recoded while wave 9 will not;
	* Recode self-rated health into a binary indicator for fair or poor (vs. good to excellent) self-rated health;
	srh_fairpoor_w9=.;
	srh_fairpoor_w10=.;
	srh_fairpoor_w11=.;
	srh_fairpoor_w12=.;
	srh_fairpoor_w13=.;
	array srh {5} R9SHLT R10SHLT R11SHLT R12SHLT R13SHLT;
	array srh_coded {5} srh_fairpoor_w9 srh_fairpoor_w10 srh_fairpoor_w11 srh_fairpoor_w12 srh_fairpoor_w13;
	do i=1 to 5;
		if srh[i]>=0 then srh_coded[i]=(srh[i] in (4, 5));
		if i>=2 then do; if (srh[i] in (.D, .M, .R) & srh[i-1]>=0) then srh_coded[i]=(srh[i-1] in (4, 5)); end;
	end;

	* Recode ADLs: sum ADLs where Respondent reports any dif?culty;
	adl_w9=.;
	adl_w10=.;
	adl_w11=.;
	adl_w12=.;
	adl_w13=.;
	array adl {5} R9ADLA R10ADLA R11ADLA R12ADLA R13ADLA;
	array adl_coded {5} adl_w9 adl_w10 adl_w11 adl_w12 adl_w13;
	do i=1 to 5;
		if adl[i]>=0 then adl_coded[i]=adl[i];
		if i>=2 then do; if (adl[i] in (.D, .M, .R) & adl[i-1]>=0) then adl_coded[i]=adl[i-1]; end;
	end;

	* Recode IADLs sum IADLs where Respondent reports any difficulty;
	iadl_w9=.;
	iadl_w10=.;
	iadl_w11=.;
	iadl_w12=.;
	iadl_w13=.;
	array iadl {5} R9IADLZA R10IADLZA R11IADLZA R12IADLZA R13IADLZA;
	array iadl_coded {5} iadl_w9 iadl_w10 iadl_w11 iadl_w12 iadl_w13;
	do i=1 to 5;
		if iadl[i]>=0 then iadl_coded[i]=iadl[i];
		if i>=2 then do; if (iadl[i] in (.D, .M, .R) & iadl[i-1]>=0) then iadl_coded[i]=iadl[i-1]; end;
	end;

	* Recode drinking (# of days drank per week);
	drinkwk_w9=.;
	drinkwk_w10=.;
	drinkwk_w11=.;
	drinkwk_w12=.;
	drinkwk_w13=.;
	array drink {5} R9DRINKD R10DRINKD R11DRINKD R12DRINKD R13DRINKD;
	array drink_coded {5} drinkwk_w9 drinkwk_w10 drinkwk_w11 drinkwk_w12 drinkwk_w13;
	do i=1 to 5;
		if drink[i]>=0 then drink_coded[i]=drink[i];
		if i>=2 then do; if (drink[i] in (.D, .M, .R) & drink[i-1]>=0) then drink_coded[i]=drink[i-1]; end;
	end;

	* Recode smoking (ever);
	ever_smoke_w9=.;
	ever_smoke_w10=.;
	ever_smoke_w11=.;
	ever_smoke_w12=.;
	ever_smoke_w13=.;
	array ever_smoke {5} R9SMOKEV R10SMOKEV R11SMOKEV R12SMOKEV R13SMOKEV;
	array ever_smoke_coded {5} ever_smoke_w9 ever_smoke_w10 ever_smoke_w11 ever_smoke_w12 ever_smoke_w13;
	do i=1 to 5;
		if ever_smoke[i] in (0 1) then ever_smoke_coded[i]=ever_smoke[i];
		if i>=2 then do; if ((ever_smoke[i] in (.D, .M, .R)) & (ever_smoke_coded[i-1] in (0,1)) ) then ever_smoke_coded[i]=ever_smoke[i-1]; end;
	end;

	* Recode BMI and then code an obese variable;
	bmi_w9=.; bmi_w10=.; bmi_w11=.; bmi_w12=.; bmi_w13=.;
	bmi_30plus_w9=.; bmi_30plus_w10=.; bmi_30plus_w11=.; bmi_30plus_w12=.; bmi_30plus_w13=.;
	array bmi {5} R9BMI R10BMI R11BMI R12BMI R13BMI;
	array bmi_coded {5} bmi_w9 bmi_w10 bmi_w11 bmi_w12 bmi_w13;
	array obese {5} bmi_30plus_w9 bmi_30plus_w10 bmi_30plus_w11 bmi_30plus_w12 bmi_30plus_w13;
	array resp {5} INW9 INW10 INW11 INW12 INW13;
	do i=1 to 5;
		if bmi[i]>=10 then bmi_coded[i]=bmi[i]; /* BMIs <10 are implausible */
	end;
	do i=2 to 5; /* fill in from prior BMI if available */
		if resp[i]=1 then do;
			if bmi[i-1]>=10 then bmi_coded[i]=bmi[i-1];
		end;
	end;
	do i=1 to 5;
		if bmi_coded[i]>=10 then obese[i]=(bmi_coded[i]>=30); /* obesity indicator */
	end;

	* Construct strength and mobility (SM) index;
	sm_walk_w9=.; sm_walk_w10=.; sm_walk_w11=.; sm_walk_w12=.; sm_walk_w13=.;
	sm_climb_w9=.; sm_climb_w10=.; sm_climb_w11=.; sm_climb_w12=.; sm_climb_w13=.;
	sm_chair_w9=.; sm_chair_w10=.; sm_chair_w11=.; sm_chair_w12=.; sm_chair_w13=.;
	sm_stoop_w9=.; sm_stoop_w10=.; sm_stoop_w11=.; sm_stoop_w12=.; sm_stoop_w13=.;
	sm_lift_w9=.; sm_lift_w10=.; sm_lift_w11=.; sm_lift_w12=.; sm_lift_w13=.;
	sm_reach_w9=.; sm_reach_w10=.; sm_reach_w11=.; sm_reach_w12=.; sm_reach_w13=.;
	sm_push_w9=.; sm_push_w10=.; sm_push_w11=.; sm_push_w12=.; sm_push_w13=.;
	sm_index_w9=.; sm_index_w10=.; sm_index_w11=.; sm_index_w12=.; sm_index_w13=.;
	array sm_walk  {5}	R9WALKSA	R10WALKSA	R11WALKSA	R12WALKSA	R13WALKSA;  /* difficulty walking several blocks */
	array sm_climb {5} 	R9CLIMSA	R10CLIMSA	R11CLIMSA	R12CLIMSA	R13CLIMSA; /* difficulty climbing 1 flight of stairs */
	array sm_chair {5} 	R9CHAIRA 	R10CHAIRA 	R11CHAIRA 	R12CHAIRA	R13CHAIRA; /* difficulty getting up from a chair */
	array sm_stoop {5} 	R9STOOPA	R10STOOPA	R11STOOPA	R12STOOPA	R13STOOPA; /* difficulty stooping, kneeling, or crouching */
	array sm_lift {5}	R9LIFTA		R10LIFTA	R11LIFTA	R12LIFTA	R13LIFTA; /* difficulty lifting or carrying 10 lbs */
	array sm_reach {5} 	R9ARMSA		R10ARMSA	R11ARMSA	R12ARMSA	R13ARMSA; /* difficulty reaching or extending arms upward */
	array sm_push  {5} 	R9PUSHA		R10PUSHA	R11PUSHA	R12PUSHA	R13PUSHA; /* difficulty pushing or pulling a large object */
	array sm_walk_coded {5} sm_walk_w9 sm_walk_w10 sm_walk_w11 sm_walk_w12 sm_walk_w13;
	array sm_climb_coded {5} sm_climb_w9 sm_climb_w10 sm_climb_w11 sm_climb_w12 sm_climb_w13;
	array sm_chair_coded {5} sm_chair_w9 sm_chair_w10 sm_chair_w11 sm_chair_w12 sm_chair_w13;
	array sm_stoop_coded {5} sm_stoop_w9 sm_stoop_w10 sm_stoop_w11 sm_stoop_w12 sm_stoop_w13;
	array sm_lift_coded {5} sm_lift_w9 sm_lift_w10 sm_lift_w11 sm_lift_w12 sm_lift_w13;
	array sm_reach_coded {5} sm_reach_w9 sm_reach_w10 sm_reach_w11 sm_reach_w12 sm_reach_w13;
	array sm_push_coded {5} sm_push_w9 sm_push_w10 sm_push_w11 sm_push_w12 sm_push_w13;
	array sm_index {5} sm_index_w9 sm_index_w10 sm_index_w11 sm_index_w12 sm_index_w13;
	do i=1 to 5;
		if sm_walk[i] in (.X, 0, 1) then sm_walk_coded[i]=(sm_walk[i] in (.X, 1)); /*=1 if respondent doesn't do or has difficulty doing */
		if i>=2 then do; if (sm_walk[i] in (.D, .R, .S) & sm_walk[i-1] in (.X, 0, 1)) then sm_walk_coded[i]=(sm_walk[i-1] in (.X, 1)); end;

		if sm_climb[i] in (.X, 0, 1) then sm_climb_coded[i]=(sm_climb[i] in (.X, 1));
		if i>=2 then do; if (sm_climb[i] in (.D, .R, .S) & sm_climb[i-1] in (.X, 0, 1)) then sm_climb_coded[i]=(sm_climb[i-1] in (.X, 1)); end;

		if sm_chair[i] in (.X, 0, 1) then sm_chair_coded[i]=(sm_chair[i] in (.X, 1));
		if i>=2 then do; if (sm_chair[i] in (.D, .R, .S) & sm_chair[i-1] in (.X, 0, 1)) then sm_chair_coded[i]=(sm_chair[i-1] in (.X, 1)); end;

		if sm_stoop[i] in (.X, 0, 1) then sm_stoop_coded[i]=(sm_stoop[i] in (.X, 1));
		if i>=2 then do; if (sm_stoop[i] in (.D, .R, .S) & sm_stoop[i-1] in (.X, 0, 1)) then sm_stoop_coded[i]=(sm_stoop[i-1] in (.X, 1)); end;

		if sm_lift[i] in (.X, 0, 1) then sm_lift_coded[i]=(sm_lift[i] in (.X, 1));
		if i>=2 then do; if (sm_lift[i] in (.D, .R, .S) & sm_lift[i-1] in (.X, 0, 1)) then sm_lift_coded[i]=(sm_lift[i-1] in (.X, 1)); end;

		if sm_reach[i] in (.X, 0, 1) then sm_reach_coded[i]=(sm_reach[i] in (.X, 1));
		if i>=2 then do; if (sm_reach[i] in (.D, .R, .S) & sm_reach[i-1] in (.X, 0, 1)) then sm_reach_coded[i]=(sm_reach[i-1] in (.X, 1)); end;

		if sm_push[i] in (.X, 0, 1) then sm_push_coded[i]=(sm_push[i] in (.X, 1));
		if i>=2 then do; if (sm_push[i] in (.D, .R, .S) & sm_push[i-1] in (.X, 0, 1)) then sm_push_coded[i]=(sm_push[i-1] in (.X, 1)); end;

	sm_index[i]=sm_walk_coded[i]+sm_climb_coded[i]+sm_chair_coded[i]+sm_stoop_coded[i]+sm_lift_coded[i]+sm_reach_coded[i]+sm_push_coded[i];

	end;

	* Flags for EVER being diagnosed with a disease (8 disease indicators);
	dx_hbp_w9=.; dx_hbp_w10=.; dx_hbp_w11=.; dx_hbp_w12=.; dx_hbp_w13=.;
	dx_diab_w9=.; dx_diab_w10=.; dx_diab_w11=.; dx_diab_w12=.; dx_diab_w13=.;
 	dx_canc_w9=.; dx_canc_w10=.; dx_canc_w11=.; dx_canc_w12=.; dx_canc_w13=.;
	dx_lngd_w9=.; dx_lngd_w10=.; dx_lngd_w11=.; dx_lngd_w12=.; dx_lngd_w13=.;
	dx_heartd_w9=.; dx_heartd_w10=.; dx_heartd_w11=.; dx_heartd_w12=.; dx_heartd_w13=.;
	dx_stroke_w9=.; dx_stroke_w10=.; dx_stroke_w11=.; dx_stroke_w12=.; dx_stroke_w13=.;
	dx_psych_w9=.; dx_psych_w10=.; dx_psych_w11=.; dx_psych_w12=.; dx_psych_w13=.;
	dx_arth_w9=.; dx_arth_w10=.; dx_arth_w11=.; dx_arth_w12=.; dx_arth_w13=.;
	toteverdx_w9=.; toteverdx_w10=.; toteverdx_w11=.; toteverdx_w12=.; toteverdx_w13=.;
	array dx_hbp_coded {5} 	dx_hbp_w9 dx_hbp_w10 dx_hbp_w11 dx_hbp_w12 dx_hbp_w13;
	array dx_diab_coded {5} dx_diab_w9 dx_diab_w10 dx_diab_w11 dx_diab_w12 dx_diab_w13;
	array dx_canc_coded {5} dx_canc_w9 dx_canc_w10 dx_canc_w11 dx_canc_w12 dx_canc_w13;
	array dx_lungd_coded {5} dx_lngd_w9 dx_lngd_w10 dx_lngd_w11 dx_lngd_w12 dx_lngd_w13;
	array dx_heartd_coded {5} dx_heartd_w9 dx_heartd_w10 dx_heartd_w11 dx_heartd_w12 dx_heartd_w13;
	array dx_stroke_coded {5} dx_stroke_w9 dx_stroke_w10 dx_stroke_w11 dx_stroke_w12 dx_stroke_w13;
	array dx_psych_coded {5} dx_psych_w9 dx_psych_w10 dx_psych_w11 dx_psych_w12 dx_psych_w13;
	array dx_arth_coded {5} dx_arth_w9 dx_arth_w10 dx_arth_w11 dx_arth_w12 dx_arth_w13;
	array dx_tot {5} toteverdx_w9 toteverdx_w10 toteverdx_w11 toteverdx_w12 toteverdx_w13;
	array dx_hbp {5} R9HIBPE R10HIBPE R11HIBPE R12HIBPE R13HIBPE;
	array dx_diab {5} R9DIABE R10DIABE R11DIABE R12DIABE R13DIABE;
	array dx_canc {5} R9CANCRE R10CANCRE R11CANCRE R12CANCRE R13CANCRE;
	array dx_lungd {5} R9LUNGE R10LUNGE R11LUNGE R12LUNGE R13LUNGE;
	array dx_heartd {5} R9HEARTE R10HEARTE R11HEARTE R12HEARTE R13HEARTE;
	array dx_stroke {5} R9STROKE R10STROKE R11STROKE R12STROKE R13STROKE;
	array dx_psych {5} R9PSYCHE R10PSYCHE R11PSYCHE R12PSYCHE R13PSYCHE;
	array dx_arth {5} R9ARTHRE R10ARTHRE R11ARTHRE R12ARTHRE R13ARTHRE;

	do i=1 to 5;
		if dx_hbp[i] in (0, 1) then dx_hbp_coded[i]=(dx_hbp[i]=1);
		if i>=2 then do; if (dx_hbp[i] in (.D, .M, .R) & dx_hbp[i-1] in (0, 1)) then dx_hbp_coded[i]=(dx_hbp[i-1]=1); end;

		if dx_diab[i] in (0, 1) then dx_diab_coded[i]=(dx_diab[i]=1);
		if i>=2 then do; if (dx_diab[i] in (.D, .M, .R) & dx_diab[i-1] in (0, 1)) then dx_diab_coded[i]=(dx_diab[i-1]=1); end;

		if dx_canc[i] in (0, 1) then dx_canc_coded[i]=(dx_canc[i]=1);
		if i>=2 then do; if (dx_canc[i] in (.D, .M, .R) & dx_canc[i-1] in (0, 1)) then dx_canc_coded[i]=(dx_canc[i-1]=1); end;

		if dx_lungd[i] in (0, 1) then dx_lungd_coded[i]=(dx_lungd[i]=1);
		if i>=2 then do; if (dx_lungd[i] in (.D, .M, .R) & dx_lungd[i-1] in (0, 1)) then dx_lungd_coded[i]=(dx_lungd[i-1]=1); end;

		if dx_heartd[i] in (0, 1) then dx_heartd_coded[i]=(dx_heartd[i]=1);
		if i>=2 then do; if (dx_heartd[i] in (.D, .M, .R) & dx_heartd[i-1] in (0, 1)) then dx_heartd_coded[i]=(dx_heartd[i-1]=1); end;

		if dx_stroke[i] in (0, 1) then dx_stroke_coded[i]=(dx_stroke[i]=1);
		if i>=2 then do; if (dx_stroke[i] in (.D, .M, .R) & dx_stroke[i-1] in (0, 1)) then dx_stroke_coded[i]=(dx_stroke[i-1]=1); end;

		if dx_psych[i] in (0, 1) then dx_psych_coded[i]=(dx_psych[i]=1);
		if i>=2 then do; if (dx_psych[i] in (.D, .M, .R) & dx_psych[i-1] in (0, 1)) then dx_psych_coded[i]=(dx_psych[i-1]=1); end;

		if dx_arth[i] in (0, 1) then dx_arth_coded[i]=(dx_arth[i]=1);
		if i>=2 then do; if (dx_arth[i] in (.D, .M, .R) & dx_arth[i-1] in (0, 1)) then dx_arth_coded[i]=(dx_arth[i-1]=1); end;

		dx_tot[i]=dx_hbp_coded[i]+dx_diab_coded[i]+dx_canc_coded[i]+dx_lungd_coded[i]+dx_heartd_coded[i]+dx_stroke_coded[i]+dx_psych_coded[i]+dx_arth_coded[i];
	end;

	* CESD depression score -- only coded where there was NOT a proxy survey respondent;
	* Because this variable is not reported for individuals who responded via a proxy, only include them in robustness tests but not in full analysis;
		cesd_w9=.; cesd_w10=.; cesd_w11=.; cesd_w12=.; cesd_w13=.;
		cognition_age65pls_w9=.; cognition_age65pls_w10=.; cognition_age65pls_w11=.; cognition_age65pls_w12=.; cognition_age65pls_w13=.; 
		array proxy {5} R9PROXY R10PROXY R11PROXY R12PROXY R13PROXY;
		array cesd {5} R9CESD R10CESD R11CESD R12CESD R13CESD;
		array cognition {5} R9COGTOT R10COGTOT R11COGTOT R12COGTOT R13COGTOT;
		array age {5} R9AGEY_E R10AGEY_E R11AGEY_E R12AGEY_E R13AGEY_E;
		array cesd_coded {5} cesd_w9 cesd_w10 cesd_w11 cesd_w12 cesd_w13;
		array cognition_coded {5} cognition_age65pls_w9 cognition_age65pls_w10 cognition_age65pls_w11 cognition_age65pls_w12 cognition_age65pls_w13; 
		do i=1 to 5;
			if proxy[i]=0 then do;
				if cesd[i] in (0:100) then cesd_coded[i]=cesd[i];
				if age[i]>=65 then do;
					if cognition[i] in (0:100) then cognition_coded[i]=cognition[i];
				end;
			end;
		end;
run;
proc freq data=d.randhrs_merge_10;
title 'Checking of ever smoke variable';
tables inw9 * ever_smoke_w9 / missing;
tables inw10 * ever_smoke_w10 / missing;
tables inw11 * ever_smoke_w11 / missing;
tables inw12 * ever_smoke_w12 / missing; 
tables inw13 * ever_smoke_w13 / missing; run;

proc means data=d.randhrs_merge_10 N NMISS MIN MEAN MAX; class inw9; var R9BMI bmi_w9 bmi_30plus_w9 cesd_w9 cognition_age65pls_w9; run;
proc means data=d.randhrs_merge_10 N NMISS MIN MEAN MAX; class inw10; var R10BMI bmi_w10 bmi_30plus_w10 cesd_w10 cognition_age65pls_w10; run;
proc means data=d.randhrs_merge_10 N NMISS MIN MEAN MAX; class inw11; var R11BMI bmi_w11 bmi_30plus_w11 cesd_w11 cognition_age65pls_w11; run;
proc means data=d.randhrs_merge_10 N NMISS MIN MEAN MAX; class inw12; var R12BMI bmi_w12 bmi_30plus_w12 cesd_w12 cognition_age65pls_w12; run;
proc means data=d.randhrs_merge_10 N NMISS MIN MEAN MAX; class inw13; var R13BMI bmi_w13 bmi_30plus_w13 cesd_w13 cognition_age65pls_w13; run;

proc sort data=d.randhrs_merge_10; by HHID PN; run;
proc sort data=f.blind; by HHID PN; run;

* Merge on blindness indicator from HRS fat files;
data d.randhrs_merge_10;
merge 	d.randhrs_merge_10 (in=in1)
		f.blind (in=in2 keep=HHID PN poor_vision_w9 poor_vision_w10 poor_vision_w11 poor_vision_w12 poor_vision_w13 
									 legally_blind_w9 legally_blind_w10 legally_blind_w11 legally_blind_w12 legally_blind_w13);
by HHID PN;
if in1; run;


*************************************************************************************************************************;
* (11) Finalize an analytic file that excludes a small number of individuals living outside the US
       or with discrepant state records;
*************************************************************************************************************************;

data d.randhrs_merge_10_analyze;
set d.randhrs_merge_10;

* Final inwx indicators -- will override 1s with zeros in cases where the state fips code and postal code don't match up;
inw9f=.;
inw10f=.;
inw11f=.;
inw12f=.;
inw13f=.;

override9=.;
override10=.;
override11=.;
override12=.;
override13=.;

array inw  {5} inw9 inw10 inw11 inw12 inw13;
array inwf {5} inw9f inw10f inw11f inw12f inw13f;
array override {5} override9 override10 override11 override12 override13;
array state_postal {5} STATEUSPS08 STATEUSPS10 STATEUSPS12 STATEUSPS14 STATEUSPS14 /*need to add STATEUSPS16 when available*/;
array state_fips {5} STFIPS08 STFIPS10 STFIPS12 STFIPS14 STFIPS14 /*need to replace with STFIPS16 when available*/;

do i=1 to 5;
	if inw[i]=1 then do;
		* Note: PR and foreign territories are excluded from this list *;
		if (( state_postal[i] = 'AK' & state_fips[i] = '02' ) or
			( state_postal[i] = 'AL' & state_fips[i] = '01' ) or
			( state_postal[i] = 'AR' & state_fips[i] = '05' ) or
			( state_postal[i] = 'AZ' & state_fips[i] = '04' ) or
			( state_postal[i] = 'CA' & state_fips[i] = '06' ) or
			( state_postal[i] = 'CO' & state_fips[i] = '08' ) or
			( state_postal[i] = 'CT' & state_fips[i] = '09' ) or
			( state_postal[i] = 'DC' & state_fips[i] = '11' ) or
			( state_postal[i] = 'DE' & state_fips[i] = '10' ) or
			( state_postal[i] = 'FL' & state_fips[i] = '12' ) or
			( state_postal[i] = 'GA' & state_fips[i] = '13' ) or
			( state_postal[i] = 'HI' & state_fips[i] = '15' ) or
			( state_postal[i] = 'IA' & state_fips[i] = '19' ) or
			( state_postal[i] = 'ID' & state_fips[i] = '16' ) or
			( state_postal[i] = 'IL' & state_fips[i] = '17' ) or
			( state_postal[i] = 'IN' & state_fips[i] = '18' ) or
			( state_postal[i] = 'KS' & state_fips[i] = '20' ) or
			( state_postal[i] = 'KY' & state_fips[i] = '21' ) or
			( state_postal[i] = 'LA' & state_fips[i] = '22' ) or
			( state_postal[i] = 'MA' & state_fips[i] = '25' ) or
			( state_postal[i] = 'MD' & state_fips[i] = '24' ) or
			( state_postal[i] = 'ME' & state_fips[i] = '23' ) or
			( state_postal[i] = 'MI' & state_fips[i] = '26' ) or
			( state_postal[i] = 'MN' & state_fips[i] = '27' ) or
			( state_postal[i] = 'MO' & state_fips[i] = '29' ) or
			( state_postal[i] = 'MS' & state_fips[i] = '28' ) or
			( state_postal[i] = 'MT' & state_fips[i] = '30' ) or
			( state_postal[i] = 'NC' & state_fips[i] = '37' ) or
			( state_postal[i] = 'ND' & state_fips[i] = '38' ) or
			( state_postal[i] = 'NE' & state_fips[i] = '31' ) or
			( state_postal[i] = 'NH' & state_fips[i] = '33' ) or
			( state_postal[i] = 'NJ' & state_fips[i] = '34' ) or
			( state_postal[i] = 'NM' & state_fips[i] = '35' ) or
			( state_postal[i] = 'NV' & state_fips[i] = '32' ) or
			( state_postal[i] = 'NY' & state_fips[i] = '36' ) or
			( state_postal[i] = 'OH' & state_fips[i] = '39' ) or
			( state_postal[i] = 'OK' & state_fips[i] = '40' ) or
			( state_postal[i] = 'OR' & state_fips[i] = '41' ) or
			( state_postal[i] = 'PA' & state_fips[i] = '42' ) or
			( state_postal[i] = 'RI' & state_fips[i] = '44' ) or
			( state_postal[i] = 'SC' & state_fips[i] = '45' ) or
			( state_postal[i] = 'SD' & state_fips[i] = '46' ) or
			( state_postal[i] = 'TN' & state_fips[i] = '47' ) or
			( state_postal[i] = 'TX' & state_fips[i] = '48' ) or
			( state_postal[i] = 'UT' & state_fips[i] = '49' ) or
			( state_postal[i] = 'VA' & state_fips[i] = '51' ) or
			( state_postal[i] = 'VT' & state_fips[i] = '50' ) or
			( state_postal[i] = 'WA' & state_fips[i] = '53' ) or
			( state_postal[i] = 'WI' & state_fips[i] = '55' ) or
			( state_postal[i] = 'WV' & state_fips[i] = '54' ) or
			( state_postal[i] = 'WY' & state_fips[i] = '56' )    ) 
				then do;
					inwf[i]=1; override[i]=0;
				end;
				else do;
					inwf[i]=0; override[i]=1;
				end;
	end;
end; run;

data d.randhrs_merge_10_analyze;
set d.randhrs_merge_10_analyze (drop=override:); run;


*************************************************************************************************************************;
* (12) Construct wave-specific files of countable income, countable assets, and income relative to eligibility t'holds   ;
*************************************************************************************************************************;
* Wave 9;
%let demos_w9  = inw9f instate_w9 couple_w9 hh_dep_w9 hh_size_w9 any_hh_dep_w9 svy_medicare_w9;
%let staterules_w9 = STATEUSPS08 STFIPS08 pov_guideline_mcd_w9 pov_guideline_lis_w9 mcd_inc_t_w9 qmb_inc_t_w9 slmb_inc_t_w9 qi_inc_t_w9;
%let assets_w9 = countable_asset_w9;
%let income_w9 = ssi_w9 inc_fpl_mcd_x_ssi_w9 inc_fpl_mcd_w_ssi_w9 inc_fpl_msp_x_ssi_w9 inc_fpl_msp_w_ssi_w9 inc_fpl_lis_x_ssi_w9 inc_fpl_lis_w_ssi_w9 fixed_income_ind_x_ssi_w9 fixed_income_ind_w_ssi_w9 hhbiz_inc_w9 any_hhbiz_inc_w9;
%let income_elig_w9 = inc_diff_mcd_x_ssi_w9 inc_diff_mcd_w_ssi_w9 inc_diff_qmb_x_ssi_w9 inc_diff_qmb_w_ssi_w9 inc_diff_slmb_x_ssi_w9 inc_diff_slmb_w_ssi_w9 inc_diff_qi_x_ssi_w9 inc_diff_qi_w_ssi_w9 inc_diff_lis_full_x_ssi_w9 inc_diff_lis_full_w_ssi_w9 inc_diff_lis_part_x_ssi_w9 inc_diff_lis_part_w_ssi_w9;
%let asset_elig_w9 = asset_below_mcd_w9 asset_below_msp_w9 asset_below_lis_full_w9 asset_below_lis_part_w9;
%let covars_w9 = 	english_w9 married_partnered_w9 toteverdx_w9 ever_smoke_w9 drinkwk_w9 sm_index_w9 bmi_30plus_w9 adl_w9 iadl_w9 srh_fairpoor_w9;
%let depvars_w9 = skip_rx_cst_w9 oop2yr_medexp_w9;
data d.hrs_file_w9;
set d.randhrs_merge_10_analyze (keep=HHID PN LIWYEAR LWGTR &demos_w9. &staterules_w9. &assets_w9. &income_w9. &income_elig_w9. &asset_elig_w9. &covars_w9. &depvars_w9.);
retain HHID PN LIWYEAR LWGTR &demos_w9. &staterules_w9. &assets_w9. &income_w9. &income_elig_w9. &asset_elig_w9. &covars_w9. &depvars_w9.;
survey_yr=LIWYEAR;
income_yr=LIWYEAR-1; /* income is measured for the year prior to the survey year */
where inw9f=1 & instate_w9=1;
hrs_wave=9;
rename STATEUSPS08 = STATEUSPS;
rename STFIPS08 = STFIPS;
hrs_weight_cmty = LWGTR; /* weight assigned to community dwelling respondents */
run;

* Wave 10;
%let demos_w10  = inw10f instate_w10 couple_w10 hh_dep_w10 hh_size_w10 any_hh_dep_w10 svy_medicare_w10;
%let staterules_w10 = STATEUSPS10 STFIPS10 pov_guideline_mcd_w10 pov_guideline_lis_w10 mcd_inc_t_w10 qmb_inc_t_w10 slmb_inc_t_w10 qi_inc_t_w10;
%let assets_w10 = countable_asset_w10;
%let income_w10 = ssi_w10 inc_fpl_mcd_x_ssi_w10 inc_fpl_mcd_w_ssi_w10 inc_fpl_msp_x_ssi_w10 inc_fpl_msp_w_ssi_w10 inc_fpl_lis_x_ssi_w10 inc_fpl_lis_w_ssi_w10 fixed_income_ind_x_ssi_w10 fixed_income_ind_w_ssi_w10 hhbiz_inc_w10 any_hhbiz_inc_w10;
%let income_elig_w10 = inc_diff_mcd_x_ssi_w10 inc_diff_mcd_w_ssi_w10 inc_diff_qmb_x_ssi_w10 inc_diff_qmb_w_ssi_w10 inc_diff_slmb_x_ssi_w10 inc_diff_slmb_w_ssi_w10 inc_diff_qi_x_ssi_w10 inc_diff_qi_w_ssi_w10 inc_diff_lis_full_x_ssi_w10 inc_diff_lis_full_w_ssi_w10 inc_diff_lis_part_x_ssi_w10 inc_diff_lis_part_w_ssi_w10;
%let asset_elig_w10 = asset_below_mcd_w10 asset_below_msp_w10 asset_below_lis_full_w10 asset_below_lis_part_w10;
%let covars_w10 = 	english_w10 married_partnered_w10 toteverdx_w10 ever_smoke_w10 drinkwk_w10 sm_index_w10 bmi_30plus_w10 adl_w10 iadl_w10 srh_fairpoor_w10;
%let depvars_w10 = skip_rx_cst_w10 oop2yr_medexp_w10;
data d.hrs_file_w10;
set d.randhrs_merge_10_analyze (keep=HHID PN MIWYEAR MWGTR &demos_w10. &staterules_w10. &assets_w10. &income_w10. &income_elig_w10. &asset_elig_w10. &covars_w10. &depvars_w10.);
retain HHID PN MIWYEAR MWGTR &demos_w10. &staterules_w10. &assets_w10. &income_w10. &income_elig_w10. &asset_elig_w10. &covars_w10. &depvars_w10.;
survey_yr=MIWYEAR;
income_yr=MIWYEAR-1; /* income is measured for the year prior to the survey year */
where inw10f=1 & instate_w10=1;
hrs_wave=10;
rename STATEUSPS10 = STATEUSPS;
rename STFIPS10 = STFIPS;
hrs_weight_cmty = MWGTR; /* weight assigned to community dwelling respondents */
run;

* Wave 11;
%let demos_w11  = inw11f instate_w11 couple_w11 hh_dep_w11 hh_size_w11 any_hh_dep_w11 svy_medicare_w11;
%let staterules_w11 = STATEUSPS12 STFIPS12 pov_guideline_mcd_w11 pov_guideline_lis_w11 mcd_inc_t_w11 qmb_inc_t_w11 slmb_inc_t_w11 qi_inc_t_w11;
%let assets_w11 = countable_asset_w11;
%let income_w11 = ssi_w11 inc_fpl_mcd_x_ssi_w11 inc_fpl_mcd_w_ssi_w11 inc_fpl_msp_x_ssi_w11 inc_fpl_msp_w_ssi_w11 inc_fpl_lis_x_ssi_w11 inc_fpl_lis_w_ssi_w11 fixed_income_ind_x_ssi_w11 fixed_income_ind_w_ssi_w11 hhbiz_inc_w11 any_hhbiz_inc_w11;
%let income_elig_w11 = inc_diff_mcd_x_ssi_w11 inc_diff_mcd_w_ssi_w11 inc_diff_qmb_x_ssi_w11 inc_diff_qmb_w_ssi_w11 inc_diff_slmb_x_ssi_w11 inc_diff_slmb_w_ssi_w11 inc_diff_qi_x_ssi_w11 inc_diff_qi_w_ssi_w11 inc_diff_lis_full_x_ssi_w11 inc_diff_lis_full_w_ssi_w11 inc_diff_lis_part_x_ssi_w11 inc_diff_lis_part_w_ssi_w11;
%let asset_elig_w11 = asset_below_mcd_w11 asset_below_msp_w11 asset_below_lis_full_w11 asset_below_lis_part_w11;
%let covars_w11 = 	english_w11 married_partnered_w11 toteverdx_w11 ever_smoke_w11 drinkwk_w11 sm_index_w11 bmi_30plus_w11 adl_w11 iadl_w11 srh_fairpoor_w11;
%let depvars_w11 = skip_rx_cst_w11 oop2yr_medexp_w11;
data d.hrs_file_w11;
set d.randhrs_merge_10_analyze (keep=HHID PN NIWYEAR NWGTR &demos_w11. &staterules_w11. &assets_w11. &income_w11. &income_elig_w11. &asset_elig_w11. &covars_w11. &depvars_w11.);
retain HHID PN NIWYEAR NWGTR &demos_w11. &staterules_w11. &assets_w11. &income_w11. &income_elig_w11. &asset_elig_w11. &covars_w11. &depvars_w11.;
survey_yr=NIWYEAR;
income_yr=NIWYEAR-1; /* income is measured for the year prior to the survey year */
where inw11f=1 & instate_w11=1;
hrs_wave=11;
rename STATEUSPS12 = STATEUSPS;
rename STFIPS12 = STFIPS;
hrs_weight_cmty = NWGTR; /* weight assigned to community dwelling respondents */
run;

* Wave 12;
%let demos_w12  = inw12f instate_w12 couple_w12 hh_dep_w12 hh_size_w12 any_hh_dep_w12 svy_medicare_w12;
%let staterules_w12 = STATEUSPS14 STFIPS14 pov_guideline_mcd_w12 pov_guideline_lis_w12 mcd_inc_t_w12 qmb_inc_t_w12 slmb_inc_t_w12 qi_inc_t_w12;
%let assets_w12 = countable_asset_w12;
%let income_w12 = ssi_w12 inc_fpl_mcd_x_ssi_w12 inc_fpl_mcd_w_ssi_w12 inc_fpl_msp_x_ssi_w12 inc_fpl_msp_w_ssi_w12 inc_fpl_lis_x_ssi_w12 inc_fpl_lis_w_ssi_w12 fixed_income_ind_x_ssi_w12 fixed_income_ind_w_ssi_w12 hhbiz_inc_w12 any_hhbiz_inc_w12;
%let income_elig_w12 = inc_diff_mcd_x_ssi_w12 inc_diff_mcd_w_ssi_w12 inc_diff_qmb_x_ssi_w12 inc_diff_qmb_w_ssi_w12 inc_diff_slmb_x_ssi_w12 inc_diff_slmb_w_ssi_w12 inc_diff_qi_x_ssi_w12 inc_diff_qi_w_ssi_w12 inc_diff_lis_full_x_ssi_w12 inc_diff_lis_full_w_ssi_w12 inc_diff_lis_part_x_ssi_w12 inc_diff_lis_part_w_ssi_w12;
%let asset_elig_w12 = asset_below_mcd_w12 asset_below_msp_w12 asset_below_lis_full_w12 asset_below_lis_part_w12;
%let covars_w12 = 	english_w12 married_partnered_w12 toteverdx_w12 ever_smoke_w12 drinkwk_w12 sm_index_w12 bmi_30plus_w12 adl_w12 iadl_w12 srh_fairpoor_w12;
%let depvars_w12 = skip_rx_cst_w12 oop2yr_medexp_w12;
data d.hrs_file_w12;
set d.randhrs_merge_10_analyze (keep=HHID PN OIWYEAR OWGTR &demos_w12. &staterules_w12. &assets_w12. &income_w12. &income_elig_w12. &asset_elig_w12. &covars_w12. &depvars_w12.);
retain HHID PN OIWYEAR OWGTR &demos_w12. &staterules_w12. &assets_w12. &income_w12. &income_elig_w12. &asset_elig_w12. &covars_w12. &depvars_w12.;
survey_yr=OIWYEAR;
income_yr=OIWYEAR-1; /* income is measured for the year prior to the survey year */
where inw12f=1 & instate_w12=1;
hrs_wave=12;
rename STATEUSPS14 = STATEUSPS;
rename STFIPS14 = STFIPS; 
hrs_weight_cmty = OWGTR; /* weight assigned to community dwelling respondents */
run;

* Wave 13;
%let demos_w13  = inw13f instate_w13 couple_w13 hh_dep_w13 hh_size_w13 any_hh_dep_w13 svy_medicare_w13;
%let staterules_w13 = STATEUSPS14 /*need to add STATEUSPS16 when available*/ STFIPS14 /*need to replace with STFIPS16 when available*/ pov_guideline_mcd_w13 pov_guideline_lis_w13 mcd_inc_t_w13 qmb_inc_t_w13 slmb_inc_t_w13 qi_inc_t_w13;
%let assets_w13 = countable_asset_w13;
%let income_w13 = ssi_w13 inc_fpl_mcd_x_ssi_w13 inc_fpl_mcd_w_ssi_w13 inc_fpl_msp_x_ssi_w13 inc_fpl_msp_w_ssi_w13 inc_fpl_lis_x_ssi_w13 inc_fpl_lis_w_ssi_w13 fixed_income_ind_x_ssi_w13 fixed_income_ind_w_ssi_w13 hhbiz_inc_w13 any_hhbiz_inc_w13;
%let income_elig_w13 = inc_diff_mcd_x_ssi_w13 inc_diff_mcd_w_ssi_w13 inc_diff_qmb_x_ssi_w13 inc_diff_qmb_w_ssi_w13 inc_diff_slmb_x_ssi_w13 inc_diff_slmb_w_ssi_w13 inc_diff_qi_x_ssi_w13 inc_diff_qi_w_ssi_w13 inc_diff_lis_full_x_ssi_w13 inc_diff_lis_full_w_ssi_w13 inc_diff_lis_part_x_ssi_w13 inc_diff_lis_part_w_ssi_w13;
%let asset_elig_w13 = asset_below_mcd_w13 asset_below_msp_w13 asset_below_lis_full_w13 asset_below_lis_part_w13;
%let covars_w13 = 	english_w13 married_partnered_w13 toteverdx_w13 ever_smoke_w13 drinkwk_w13 sm_index_w13 bmi_30plus_w13 adl_w13 iadl_w13 srh_fairpoor_w13;
%let depvars_w13 = skip_rx_cst_w13 oop2yr_medexp_w13;
data d.hrs_file_w13;
set d.randhrs_merge_10_analyze (keep=HHID PN PIWYEAR /*new weighting variable*/ PWGTRE &demos_w13. &staterules_w13. &assets_w13. &income_w13. &income_elig_w13. &asset_elig_w13. &covars_w13. &depvars_w13.);
retain HHID PN PIWYEAR /*new weighting variable*/ PWGTRE &demos_w13. &staterules_w13. &assets_w13. &income_w13. &income_elig_w13. &asset_elig_w13. &covars_w13. &depvars_w13.;
survey_yr=PIWYEAR;
income_yr=PIWYEAR-1; /* income is measured for the year prior to the survey year */
where inw13f=1 & instate_w13=1;
hrs_wave=13;
rename STATEUSPS14 = STATEUSPS; /*need to add STATEUSPS16 when available*/
rename STFIPS14 = STFIPS; /*need to replace with STFIPS16 when available*/
hrs_weight_cmty = PWGTRE; /* new 2016 weights */
run;

%macro formatfile(wv);
data d.hrs_file_&wv.; set d.hrs_file_&wv.;
drop in&wv.f; drop instate_&wv.;
label STATEUSPS = "USPS STATE OF RESIDENCE";
label STFIPS = "STATE FIPS"; 
rename ssi_&wv.						=   ssi_income  ;
rename svy_medicare_&wv. 			= 	svy_medicare	;
rename couple_&wv.					= 	couple	;
rename hh_dep_&wv. 					= 	hh_dep	;
rename any_hh_dep_&wv.				=   any_hh_dep   ;
rename hh_size_&wv. 				= 	hh_size	;
rename pov_guideline_mcd_&wv. 		= 	pov_guideline_mcd	;
rename pov_guideline_lis_&wv. 		= 	pov_guideline_lis	;
rename countable_asset_&wv. 		= 	countable_asset	;
rename mcd_inc_t_&wv. 				= 	mcd_inc_t	;
rename qmb_inc_t_&wv. 				= 	qmb_inc_t	;
rename slmb_inc_t_&wv. 				= 	slmb_inc_t	;
rename qi_inc_t_&wv. 				= 	qi_inc_t	;
rename inc_fpl_mcd_w_ssi_&wv. 		= 	inc_fpl_mcd_w_ssi	;
rename inc_fpl_mcd_x_ssi_&wv. 		= 	inc_fpl_mcd_x_ssi	;
rename inc_fpl_msp_w_ssi_&wv. 		= 	inc_fpl_msp_w_ssi	;
rename inc_fpl_msp_x_ssi_&wv. 		= 	inc_fpl_msp_x_ssi	;
rename inc_fpl_lis_w_ssi_&wv. 		= 	inc_fpl_lis_w_ssi	;
rename inc_fpl_lis_x_ssi_&wv. 		= 	inc_fpl_lis_x_ssi	;
rename inc_diff_mcd_w_ssi_&wv. 		= 	inc_diff_mcd_w_ssi	;
rename inc_diff_mcd_x_ssi_&wv. 		= 	inc_diff_mcd_x_ssi	;
rename inc_diff_qmb_w_ssi_&wv. 		= 	inc_diff_qmb_w_ssi	;
rename inc_diff_qmb_x_ssi_&wv. 		= 	inc_diff_qmb_x_ssi	;
rename inc_diff_slmb_w_ssi_&wv. 	= 	inc_diff_slmb_w_ssi	;
rename inc_diff_slmb_x_ssi_&wv. 	= 	inc_diff_slmb_x_ssi	;
rename inc_diff_qi_w_ssi_&wv. 		= 	inc_diff_qi_w_ssi	;
rename inc_diff_qi_x_ssi_&wv. 		= 	inc_diff_qi_x_ssi	;
rename inc_diff_lis_full_w_ssi_&wv. = 	inc_diff_lis_full_w_ssi	;
rename inc_diff_lis_full_x_ssi_&wv. = 	inc_diff_lis_full_x_ssi	;
rename inc_diff_lis_part_w_ssi_&wv. = 	inc_diff_lis_part_w_ssi	;
rename inc_diff_lis_part_x_ssi_&wv. = 	inc_diff_lis_part_x_ssi	;
rename fixed_income_ind_w_ssi_&wv.  =   fixed_income_ind_w_ssi ;
rename fixed_income_ind_x_ssi_&wv.  =   fixed_income_ind_x_ssi ;
rename asset_below_mcd_&wv. 		= 	asset_below_mcd	;
rename asset_below_msp_&wv. 		= 	asset_below_msp	;
rename asset_below_lis_full_&wv. 	= 	asset_below_lis_full	;
rename asset_below_lis_part_&wv. 	= 	asset_below_lis_part	; 
rename english_&wv. 				= 	english	;
rename married_partnered_&wv. 		= 	married_partnered ;
rename toteverdx_&wv. 				= 	toteverdx	;
rename ever_smoke_&wv. 				= 	ever_smoke	;
rename drinkwk_&wv. 				= 	drinkwk	;
rename sm_index_&wv.				=	sm_index ;
rename bmi_30plus_&wv.				=   bmi_30plus ;
rename adl_&wv.						= 	adl ;
rename iadl_&wv.					=	iadl ;
rename srh_fairpoor_&wv.			=	srh_fairpoor ;
rename hhbiz_inc_&wv. 				=   hhbiz_inc  ;
rename any_hhbiz_inc_&wv.			=   any_hhbiz_inc  ;
rename skip_rx_cst_&wv.				= 	skip_rx_cst ;
rename oop2yr_medexp_&wv.			=   oop2yr_medexp ;
run;
%mend;
%formatfile(w9);
%formatfile(w10);
%formatfile(w11);
%formatfile(w12); 
%formatfile(w13); run;

data d.hrs_file_stacked;
set d.hrs_file_w9  (drop=LIWYEAR LWGTR)
	d.hrs_file_w10 (drop=MIWYEAR MWGTR)
	d.hrs_file_w11 (drop=NIWYEAR NWGTR)
	d.hrs_file_w12 (drop=OIWYEAR OWGTR)
	d.hrs_file_w13 (drop=PIWYEAR PWGTRE);
Year = survey_yr; run; /* here's where I control what HRS year will be merged to Medicare/Medicaid data -- recall the HRS asks about income in the year prior to the survey year */

* Final sample sizes;
proc freq data=d.randhrs_merge_10_analyze;
tables inw9 * instate_w9 * inw9f / missing; 
tables inw10 * instate_w10 * inw10f / missing; 
tables inw11 * instate_w11 * inw11f / missing; 
tables inw12 * instate_w12 * inw12f / missing; 
tables inw13 * instate_w13 * inw13f / missing; run;

proc freq data=d.hrs_file_stacked;
tables hrs_wave * Year / missing; run;


*************************************************************************************************************************;
* (13) Link on MBSF/MAX PS																								 ;
*************************************************************************************************************************;
proc sort data=d.hrs_file_stacked; by HHID PN Year; run;
proc sort data=d.Mbsf_1999_2015_master_merge; by HHID PN Year; run;

* Declare variable sets to include from BASF/MBSF;
%let basf_elig_vars = birth_year same_state
	medicare_advantage bsf_any_buyin bsf_months_any_buyin
	orec_disabled orec_esrd orec_age curr_disabled curr_esrd
	death_date_clean died month_died post_mortem_months_yr ttl_months_ffs_mcare ttl_months_ffs_mcare_dead
	race_white race_black race_hispanic race_asian race_other
	male age age_64under age_65_69 age_70_74 age_75_79 age_80_84 age_85plus;
%let mbsf_medicaid_lis_vars =  
	any_buyin months_any_buyin
	any_partd months_partd months_partd_dead
	any_rds any_lis	months_any_lis 
	any_full_lis months_full_lis
	any_partial_lis	months_partial_lis 
	any_buyin_full months_buyin_full
	any_buyin_qmb_only months_buyin_qmb_only
	any_buyin_qmb_plus months_buyin_qmb_plus
	any_buyin_slmb_only months_buyin_slmb_only
	any_buyin_slmb_plus	months_buyin_slmb_plus
	any_buyin_qi months_buyin_qi 
	any_buyin_oth_full months_buyin_oth_full;
%let basf_ccw_vars = ami diabetes hyperlipidemia hypertension ccw_total ccw_eq_2 ccw_eq_3 ccw_eq_4 ccw_eq_5 ccw_eq_6_8 ccw_6up ccw_9up;
%let max_vars = max_any_buyin				max_months_any_buyin
				max_any_buyin_full			max_months_buyin_full
				max_any_buyin_qmb_only		max_months_buyin_qmb_only
				max_any_buyin_qmb_plus		max_months_buyin_qmb_plus
				max_any_buyin_slmb_only		max_months_buyin_slmb_only
				max_any_buyin_slmb_plus		max_months_buyin_slmb_plus
				max_any_buyin_qi			max_months_buyin_qi
				max_any_buyin_oth_full		max_months_buyin_oth_full
				max_elig_any_abd_ssi		max_elig_any_abd_pov
				max_elig_any_abd_ssi_pov	max_elig_any_abd_mn
				max_elig_any_abd_oth		max_elig_any_abd_1115
				max_elig_any_notabd;

data d.hrs_mcare_mcaid_merged_1;
merge 	d.hrs_file_stacked (in=in1 where=(Year in (2010:2015))) /*increase endpoint to 2018 after additional wave 13 variables populated*/
		d.Medicare_mcaid_linked_1999_2015 (in=in2 keep=HHID PN Year in_mbsf in_max &basf_elig_vars. &mbsf_medicaid_lis_vars. &basf_ccw_vars. &max_vars. where=(Year in (2008:2015)));
by HHID PN Year;
in_hrs_files   =(in1=1);
in_claims_files=(in2=1); 
death_year=year(death_date_clean); run;
proc freq data=d.hrs_mcare_mcaid_merged_1;
title 'hrs_mcare_mcaid_merged_1';
tables in_claims_files * in_hrs_files / missing;
tables in_claims_files * in_hrs_files * died / missing; run;
proc freq data=d.hrs_mcare_mcaid_merged_1;
title 'hrs_mcare_mcaid_merged_1';
where in_mbsf=1 & in_hrs_files=1 & in_claims_files=1;
tables hrs_wave * survey_yr / missing; 
tables hrs_wave * year / missing; run;

* Construct final analytic dataset;
data d.hrs_mcare_mcaid_merged_2; set d.hrs_mcare_mcaid_merged_1; if (in_hrs_files=1 & in_claims_files=1 & in_mbsf=1 /*& medicare_advantage=0*/); run;

PROC EXPORT DATA= d.hrs_mcare_mcaid_merged_2 
            OUTFILE= "C:\Users\HRSdata\Desktop\HRS\HRS Analyses\Analytic files\hrs_mcare_mcaid_merged_2.dta" 
            DBMS=stata REPLACE;
RUN;

* Report annual summary statistics;
proc means data=d.hrs_mcare_mcaid_merged_2;
title 'Medicare-linked HRS: Annual summary statistics';
class year;
var race_white race_black race_hispanic race_asian race_other age age_64under ccw_total english	married_partnered toteverdx	ever_smoke drinkwk sm_index bmi_30plus adl iadl srh_fairpoor hhbiz_inc any_hhbiz_inc skip_rx_cst oop2yr_medexp 
any_buyin months_any_buyin any_buyin_qmb_only any_buyin_qmb_plus any_buyin_slmb_only any_buyin_slmb_plus any_buyin_oth_full in_max; run;
