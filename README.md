# Duals-research
<b> Research repository for studies of dual Medicare-Medicaid eligibles </b> </br>
Date created: June 23, 2019 </br>
Version: 1 </br>
Author: Eric T. Roberts, Ph.D., University of Pittsburgh </br>
Email: eric.roberts@pitt.edu | ORCID: https://orcid.org/0000-0002-7439-0799 </br>
****************************************************************************************

This repository holds final analytic code, unformatted statistial output, and state policy databases assembled for research I have led examining state and federal policies for dual eligibles.  These files are used in conjunction with Medicare claims, the Medicare Current Beneficiary Survey, and the Health and Retirement Study, which are available to researchers with an approved Data Use Agreement.

Research projects and associated code/documentation are itemized by paper (paper citations enclosed)


****************************************************************************************
<b> Projects: </b>

* Eric T. Roberts, Jennifer M. Mellor, Melissa McInerny, Lindsay M. Sabik, "State Variation in the Characteristics of Medicare-Medicaid Dual Enrollees: Implications for Risk Adjustment."  <i> Health Services Research </i>, 2019 (in press).  DOI: to come.
  + STATA code: MCBS Setup and Analyses 12-20-2018.do.  This file formats survey data from the MCBS (years 2010-13) linked to Medicare enrollment and claims data.
  + Linked state policy variables (STATA dataset): state_policy_variables_10_13.dta.  This file is an annual state level database of state Medicaid policies pertaining to the Medicare population.
  
* Eric T. Roberts et al., "Financial Assistance for Low-Income Medicare Beneficiaries: Association of Benefit Cliffs with Healthcare use and Outcomes."
  + SAS code: RAND HRS exploratory analyses 8-12-2019.sas.  This file formats income, asset, demographic and health data from responsents to waves 9-13 of the Health and Retirement Study (HRS) and links these data to to contemporaneous Medicare enrollment and claims files.
  + STATA code: Program income eligibility analyses 8-12-2019.  This file identifies Medicare beneficiaries above and below benefit 'cliffs,' defined from income relative to eligibility thresholds for Medicaid, the Medicare Savings Programs, and the Part D Low-Income Subsidy.  The program also implements regression discontinuity analyses to examine the association between these benefit cliffs and health outcomes.

* Eric T. Roberts, Jacqueline Welsh, Julie M. Donohue, Lindsay M. Sabik, "Association of State Policies with Medicaid Disenrollment among Low-Income Medicare Beneficiaries."  <it Health Affairs </i>, 2019 (in press).  DOI: to come.
  + SAS file setup code: sets up longitudinal cohorts of Medicaid enrollees among FFS Medicare beneficiaries (to come)
  + STATA code (survival analyses implemented in STATA): to come
  
* Eric T. Roberts and Lindsay M. Sabik, "Unintended spillovers from low enrollment in linked assistance programs for Medicare beneficiaries."  Research letter in preparation.
  + STATA code: HRS Medicaid and LIS Enrollment Analyses 6-20-2019.do.  This program examines discontinuities in enrollment in the Medicare Part D Low-Income Subsidy (LIS) program as a function of Medicaid eligibility.
