* This file checks the CHOW between POS, PECOs and M&As from SDC

* ==============================================================================
* Globals
* ==============================================================================

global file_path_sdc "${dropbox}/Nursing Homes/Nursing Homes Data/SDC Mergers"
global file_path_dean_acq "${dropbox}/Nursing Homes/Nursing Homes Data/Dean GitHub Output/POS Multi-Owner + Acquisitions/1. Combine/temp"

global derived "${dropbox}/Nursing Homes/Derived/"

* ==============================================================================
* Load Dean's acquisition data and merge names back in 
* ==============================================================================
use "$file_path_dean_acq/baseline_data", clear



* ==============================================================================
* Load M&A data from SDC
* ==============================================================================
use "$file_path_sdc/snf_mergers_2006_to_2023.dta", clear

* Get years of announcement and effect
gen year_ann = year(DATEANN)
gen year_eff = year(DATEEFF)

* Limit to 2011-2021 
keep if year_ann >= 2011 & year_ann <= 2021 
keep if year_eff >= 2011 & year_eff <= 2021

* Who are the most common acquirors?
tab AMANAMES, sort

* Who are the most common targets? 
tab TMANAMES, sort 

* ==============================================================================
* Keep 2015-2016 and compare with POS
* ==============================================================================
keep if inlist(year_eff, 2015, 2016)

