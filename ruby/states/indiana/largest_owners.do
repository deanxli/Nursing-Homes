* Goal: Investigate who the largest chains are in Indiana

* ==============================================================================
* Globals
* ==============================================================================

global file_path_pos "${dropbox}/Nursing Homes/Data/Staffing Data/POS Yearly/"
global file_path_pbj "${dropbox}/Nursing Homes/Data/Staffing Data/PBJ Nurse Staffing Quarterly/"
global crosswalk "${dropbox}/Nursing Homes/Data/Crosswalks"

global map "${dropbox}/Nursing Homes/Data/GIS"

* ==============================================================================
* Create panel data of year x large group x county (that they own SNFs in)
* ==============================================================================
use "${file_path_pos}/master_pos_pbj_hcris_2011_2022_ownership.dta", clear 
