version 15
set more off

global file_path "/Users/deanli/Dropbox (Personal)/Nursing Homes/Data/Staffing Data/PBJ Nurse Staffing Quarterly/"
cd "${file_path}"


program main
    add_extra_staff
end

program add_extra_staff
    use "./quarterly_agg", clear

    replace hrs_rn = hrs_rn + hrs_rnadmin + hrs_rndon
    replace hrs_rn_emp = hrs_rn_emp + hrs_rnadmin_emp + hrs_rndon_emp
    replace hrs_rn_ctr = hrs_rn_ctr + hrs_rnadmin_ctr + hrs_rndon_ctr

    drop hrs_rnadmin* hrs_rndon*

    replace hrs_lpn = hrs_lpn + hrs_lpnadmin 
    replace hrs_lpn_emp = hrs_lpn_emp + hrs_lpnadmin_emp 
    replace hrs_lpn_ctr = hrs_lpn_ctr + hrs_lpnadmin_ctr 

    drop hrs_lpnadmin* 

    replace hrs_cna = hrs_cna + hrs_natrn + hrs_medaide
    replace hrs_cna_emp = hrs_cna_emp + hrs_natrn_emp + hrs_medaide_emp
    replace hrs_cna_ctr = hrs_cna_ctr + hrs_natrn_ctr + hrs_medaide_ctr

    drop hrs_natrn* hrs_medaide* 
    save "./quaterly_agg_clean", replace
end 

* EXECUTE
main
